module tb; 
    reg reset_n,clock;
    initial clock=0;
    initial reset_n=1;

    always #5 clock=!clock; 
    router cpu(.clk(clock), .reset_n(reset_n));
    initial begin 
        @(posedge clock) ;
        reset_n = 0;
        @(posedge clock) ;
        reset_n = 1;
    end
endmodule

module MEM(addr, data_in, write_enable, data_out);
	input [7:0] addr;  
    input [15:0] data_in;
    input write_enable;
    output reg [15:0] data_out;

    reg [15:0] instructions [0:256];
	/*
		8 bit input address limits memory space to 256 addresses as opposed to 65,536
		This will help will simluation.synthesis speed
		
	*/
	initial begin
		$readmemb("instructions.mem", instructions); 
        instructions[48] = 16'h000B; 
        instructions[49] = 16'h0001; 
        instructions[50] = 16'h0002; 
        instructions[51] = 16'h0003; 
        instructions[52] = 16'h0004; 
        instructions[53] = 16'h0005; 
        instructions[54] = 16'h0006; 
        instructions[55] = 16'h0007; 
        instructions[56] = 16'h0008; 
        instructions[57] = 16'h0009; 
        instructions[58] = 16'h000A; 
        instructions[59] = 16'h000B;
		/*
		Instruction can also be read in as hexadecimal
		$readmemh("instructions_hex.txt", instructions);
		*/
	end
	
	always@(*)
	begin
		data_out <= instructions[addr];
        if(write_enable) begin
            instructions[addr]<=data_in;
        end
	end
endmodule

module router(clk, reset_n);
    input clk, reset_n;  
    reg[3:0] source;
    reg[3:0] dest;
    reg[3:0] raddr_0;                  //Tells rf the source reg addr from instruction, (bits 0-3)
    reg[3:0] raddr_1;                  //Tells rf the RT Register addr, e.g $t2 in an instruction like add, $add $t0, $t1, $t2 (bits 12-15)
    reg[3:0] waddr;                    //Tells rf the Destination Address (bits 8-12)
    reg wrx;                           //bool value for whether or not the instruction is writing to rf

    wire[0:15] data_f_mem;             //Data at pc, flip bits, big endian easier for this   
    wire signed[15:0] data_f_rf0;      //Value of source register from register file
    wire signed[15:0] data_f_rf1;      //Value of rt from register file
    reg signed [15:0] data_to_rf;      //Data to be placed in destination register
    
    reg signed[7:0]addr_to_mem;        //Address given to memory to obtain instruction
    reg [15:0] data_to_mem;            //Data to be written to memory
    reg mem_write_enable;              //If 1, memory from data_to_mem written to Mem[addr_to_mem]
    reg signed[7:0]pc;                 //Program Counter in this module, no seperate module needed. Same as addr_to_mem most of the itme.
    reg[2:0] state;                    //Most instructions will require more than 1 cycle
    reg[2:0] contin;                   //Continue the lw or sw instruction, since the opcode may change

    wire [3:0] opcode;                 //opcode is fetched from memory instruction, 0-3 bits 
    wire [3:0] reg_addr_source;        //source reg from memory instruction 4-7 bits
    wire [3:0] reg_addr_dest;          //dest reg from memory instruction 8-11 bits
    wire signed [3:0] im;              //Immediete value from memory instruction (bits 12-15)

    assign opcode = {data_f_mem[0],data_f_mem[1],data_f_mem[2],data_f_mem[3]};
    assign reg_addr_source = { data_f_mem[4], data_f_mem[5], data_f_mem[6], data_f_mem[7]}; //rs
    assign reg_addr_dest = {data_f_mem[8], data_f_mem[9], data_f_mem[10], data_f_mem[11]};  //rd
    assign im = {data_f_mem[12], data_f_mem[13], data_f_mem[14], data_f_mem[15]};           //im
    
    //initial $monitor("Data in target register: Binary: %b Decimal: %d Hex:%h  Program Counter:%d", data_f_rf0, data_f_rf0, data_f_rf0, pc);

    MEM memory(.addr(addr_to_mem), .write_enable(mem_write_enable), .data_in(data_to_mem), .data_out(data_f_mem));
    RF register_file(.clk(clk), .reset_n(reset_n), .in_data(data_to_rf), .raddr_0(raddr_0), .raddr_1(raddr_1), .waddr(waddr), .out_data_0(data_f_rf0), .out_data_1(data_f_rf1), .WrX(wrx)); 
 
     always @(posedge clk, negedge reset_n) begin
            if(!reset_n) begin
                raddr_0<=0;
                raddr_1<=0;
                waddr<=0;
                state<=0;
                pc<=0;
                addr_to_mem<=0;
                wrx<=0;
                mem_write_enable<=0;
                data_to_mem<=0;
                contin<=0;
            end
            else begin
                wrx<=0;
                mem_write_enable<=0;
                
                if(opcode==4'b0000 && contin==0 || contin==1) begin               //load word, lw $t3, 0($t2) , t3=memory[t2]; $t2=rs, $t3=rd im=0
                    if(state==0) begin                          //read value of $t2
                        raddr_0<=reg_addr_source;
                        state<=1;
                    end
                    if(state==1) begin                          //send value of $t2 to memory to get memory[$t2]
                        addr_to_mem<=data_f_rf0;
                        waddr<=reg_addr_dest;
                        state<=2;
                        contin<=1;
                    end
                    if(state==2) begin                          //get value of memory[$t2] and store it into $t3
                        data_to_rf<=data_f_mem;
                        wrx<=1;
                        pc<=pc+1;
                        addr_to_mem<=pc+1;
                        state<=0;
                        contin<=0;
                    end
                end

                else if(opcode==4'b0001 && contin==0 || contin==2) begin          //store word, sw $t3, 0($t2) , Mem[t2+im] = $t3; , $t2=rs, $t3 = rd field, im=0
                    if(state==0) begin
                        raddr_0<=reg_addr_source+im;            //get value of $t2+im
                        raddr_1<=reg_addr_dest;                 //get value of $t3
                        state<=1;
                    end
                    else if(state==1) begin
                        addr_to_mem<=data_f_rf0;                //store $t3 in memory[$t2+im]
                        data_to_mem<=data_f_rf1;        
                        mem_write_enable<=1;
                        contin<=2;
                        state<=2;
                    end

                    else if(state==2) begin
                        addr_to_mem<=pc+1;
                        pc<=pc+1;
                        state<=0;
                        contin<=0;
                    end
                end

                else if(opcode==4'b0010 && contin==0) begin          //jump, j 4 , bits 4-15 = jump value. jump is absolute, not relative to pc
                    if(state==0) begin
                        pc<={reg_addr_source, reg_addr_dest, im};
                        addr_to_mem<={reg_addr_source, reg_addr_dest, im};
                        //$display("Jump intruction value: %d",{reg_addr_source, reg_addr_dest, im});
                    end
                end

                else if(opcode==4'b0011 && contin==0) begin          //beq, beq $t3, $t4, 4  , $t3 = rd  $t4=rs
                    if(state==0) begin
                        raddr_0<=reg_addr_source;
                        raddr_1<=reg_addr_dest;
                        state<=1;
                    end
                    else if(state==1) begin
                        if(data_f_rf0==data_f_rf1) begin
                            pc<=pc+im;
                            addr_to_mem<=pc+im;
                            state<=0;
                        end
                        else begin
                            pc<=pc+1;
                            addr_to_mem<=pc+1;
                            state<=0;
                        end
                    end
                end

                else if(opcode==4'b1000 && contin==0) begin          //addi, addi $t1, $t2, 5    $t1 = rd, $t2 = rs, im=5
                        if(state==0) begin
                            raddr_0<=reg_addr_source;
                            waddr<=reg_addr_dest;
                            state<=1;
                        end                    
                        else if(state==1) begin
                            data_to_rf<=data_f_rf0+im;
                            pc<=pc+1;
                            wrx<=1;
                            addr_to_mem<=pc+1;
                            state<=0;
                        end
                end
            
                else if(opcode==4'b0100 && contin==0) begin          //add , add $t1, $t2, $t3.  $t1=rd, $t2=rs, $t3=im field/rt
                    if(state==0) begin
                        waddr<=reg_addr_dest;
                        raddr_0<=reg_addr_source;
                        raddr_1<=im;
                        state<=1;
                    end
                    else if(state==1) begin
                        data_to_rf<=data_f_rf0+data_f_rf1;
                        pc<=pc+1;
                        addr_to_mem<=pc+1;
                        wrx<=1;
                        state<=0;
                    end
                end

                else if(opcode==4'b0101 && contin==0) begin          //sub, sub $t1, $t2, $t3. $t1=rd, $t2=rs, $t3=im field/rt
                    if(state==0) begin
                        waddr<=reg_addr_dest;
                        raddr_0<=reg_addr_source;
                        raddr_1<=im;
                        state<=1;
                    end
                    else if(state==1) begin
                        data_to_rf<=data_f_rf0-data_f_rf1;
                        pc<=pc+1;
                        addr_to_mem<=pc+1;
                        wrx<=1;
                        state<=0;
                    end
                end

            else if(opcode==4'b1111 && contin==0) begin              //halt instruction
                $finish;
            end
        end
    end
endmodule

module RF(
	input clk,
	input reset_n, 
	input [15:0] in_data,
	input [3:0] raddr_0,
	input [3:0] raddr_1,
	input [3:0] waddr,
	input WrX,
	output [15:0] out_data_0,
	output [15:0] out_data_1
);
	//initial $monitor("Data in register $t2 is: %d, Data in register $t3 is: %d, Data in register $t4 is: %d, Data in register $t5 is: %d, Data in register $6 is: %d, Data in register $7 is:",datastorage[2], datastorage[3], datastorage[4], datastorage[5], datastorage[6], datastorage[7]);

	reg [15:0] datastorage [15:0]; 
    initial $monitor("Loop_target($t3): %d, i($t5): %d, Sum($t4): %d, Mem[48]($t7 lw): %d", datastorage[3], datastorage[5], datastorage[4], datastorage[7]);
    //initial $monitor("sum: %d,", datastorage[4]);
    always@(posedge clk, negedge reset_n)
    begin
        if(!reset_n)
        begin
            datastorage[0]  <= $urandom;
            datastorage[1]  <= $urandom;
            datastorage[2]  <= $urandom;
            datastorage[3]  <= $urandom;
            datastorage[4]  <= $urandom;
            datastorage[5]  <= $urandom;
            datastorage[6]  <= $urandom;
            datastorage[7]  <= $urandom;
            datastorage[8]  <= $urandom;
            datastorage[9]  <= $urandom;
            datastorage[10] <= $urandom;
            datastorage[11] <= $urandom;
            datastorage[12] <= $urandom;
            datastorage[13] <= $urandom;
            datastorage[14] <= $urandom;
            datastorage[15] <= $urandom;
        end
        
        else
        begin
            if(WrX)
                datastorage[waddr] <= in_data;
        end
        
    end
        
    assign out_data_0 = datastorage[raddr_0];
    assign out_data_1 = datastorage[raddr_1];

endmodule