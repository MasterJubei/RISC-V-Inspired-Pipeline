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

module MEM(
    input [15:0] addr, data_in, 
    input write_enable, 
    input [7:0] pc_f_alu,
    output reg [7:0] pc_f_mem,
    output reg [15:0] data_out, 
    output [15:0] data_out_pc,
    input reg_write_enable_f_alu, 
    input [3:0] rd_f_alu,
    output [3:0] rd_f_mem,
    output reg_write_enable_f_mem);
    
    
    reg [15:0] instructions [0:256];
    /*
    8 bit input address limits memory space to 256 addresses as opposed to 65,536
    This will help will simluation.synthesis speed
    
    */
    initial $monitor("Instruction in mem is %b", instructions[0] );
    
    initial begin
        $readmemb("instructions2.mem", instructions); 
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

    assign data_out_pc = instructions[pc_f_alu];
    
    always@(*)
    begin
        $display("Data at pc in mem is: %d", instructions[pc_f_alu] );
        //$display("Data at 0 is %b", instructions[0]);
        //$display("%b", instructions[0]);
        data_out <= instructions[addr];
        pc_f_mem<=pc_f_alu+1;
        

        if(write_enable) begin
            $display("Should be false");
            instructions[addr]<=data_in;
        end
    end
endmodule

module ALU(
    input clk, reset_n, reg_write_enable_f_rf, mem_write_enable_f_rf, 
    input [7:0] pc_f_rf,
    output reg [7:0] pc_f_alu,
    input [3:0] opcode_f_rf, rs2_f_rf, rd_f_rf,
    output[3:0] opcode_f_alu, rd_f_alu,
    output reg reg_write_enable_f_alu, mem_write_enable_f_alu,  
    input [15:0] data_f_rf_rs1, data_f_rf_rs2, 
    output reg [15:0]alu_out);
    
    always @(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            pc_f_alu <= 0;
        end
        else begin
            if(opcode_f_rf==4'b0100) begin    // add, add x1, x2, x3     rs1 = x2, rs2 = x3, rd=x1
                alu_out<=data_f_rf_rs1+data_f_rf_rs2;
                pc_f_alu<=pc_f_rf;
            end
            
            if(opcode_f_rf==4'b0000) begin   //load word
                alu_out<= data_f_rf_rs1 + data_f_rf_rs2;
                mem_write_enable_f_alu<=1;
                pc_f_alu<=pc_f_rf;
            end
            
            if(opcode_f_rf==4'b0001) begin   //store word
                alu_out<=data_f_rf_rs1 + data_f_rf_rs2;
                pc_f_alu<=pc_f_rf;
            end
            
            if(opcode_f_rf == 4'b0100) begin  //add
                alu_out<=data_f_rf_rs1 + data_f_rf_rs2;
                pc_f_alu<=pc_f_rf;
            end
            
            if(opcode_f_rf == 4'b0101) begin    //sub
               // $display("hello");
                alu_out<=data_f_rf_rs1 - data_f_rf_rs2;
                pc_f_alu<=pc_f_rf;
            end
            
            if(opcode_f_rf == 4'b1000) begin    //addi
                alu_out <= data_f_rf_rs1 + data_f_rf_rs2;
                pc_f_alu<=pc_f_rf;
            end 
        end
    end
endmodule

module IF(
    input clk, reset_n, 
    input [7:0] pc,
    input [3:0] first_bits, second_bits, third_bits, fourth_bits, 
    output reg [7:0] pc_f_if,
    output reg [3:0] opcode_f_if, rs1_f_if, rs2_f_if, rd_f_if, 
    output reg ALUsrc_f_if,
    output reg reg_write_enable_f_if, 
    output reg mem_write_enable_f_if,
    output reg is_immed_f_if );
    
    always @(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            pc_f_if<=0;
            // opcode_f_if<=4'b0000;
            // rs1_f_if<=0;
            // rs2_f_if<=0;
            // rd_f_if<=0;
            // reg_write_enable_f_if<=0;
            // mem_write_enable_f_if<=0;
            // is_immed_f_if<=0;
        end
        else begin
            opcode_f_if<=first_bits;
            rs1_f_if<=second_bits;
            rs2_f_if<=third_bits;
            rd_f_if<=fourth_bits;
            pc_f_if<=pc;
            

            if(first_bits==4'b0000) begin    //load word, lw x3, 0(x2), rs1 = x2    rs2/im = 0      rd = x3
                is_immed_f_if<=1;
            end
            
            if(first_bits==4'b0001) begin   //addi
                $display("hello");
                is_immed_f_if<=1;
                ALUsrc_f_if<=1;
                mem_write_enable_f_if <= 0;
                reg_write_enable_f_if <= 1;
            end
            
            if(first_bits==4'b0100) begin   //add
                is_immed_f_if <= 0;
                mem_write_enable_f_if <= 0;
                reg_write_enable_f_if <= 1;
                ALUsrc_f_if<=0;
                
                
            end
            
            if(first_bits==4'b0101) begin //sub
                //$display("hello");
                is_immed_f_if <= 0;
                mem_write_enable_f_if <= 0;
                reg_write_enable_f_if <= 1;
                ALUsrc_f_if<=0;
            end
        end
    end
    
endmodule


module RF2 (
    input clk, reset_n, 
    input [7:0] pc_f_if,
    output reg [7:0] pc_f_rf,
    input reg_write_enable_f_if, mem_write_enable_f_if, is_immed_f_if, ALUsrc_f_if,
    output reg reg_write_enable_f_rf, mem_write_enable_f_rf, is_immed_f_rf, ALUsrc_f_rf,
    input [3:0] opcode_f_if, rs1_f_if, rs2_f_if, rd_f_if, 
    output reg[3:0] opcode_f_rf, rs1_f_rf, rs2_f_rf, rd_f_rf, 
    input[3:0] if_request_out_1, if_request_out_2, waddr, 
    input [15:0] rf_write_input_data, 
    output [15:0] rf_data_1, rf_data_2, 
    input reg_write_enable_f_mem); 
    
    

    reg [15:0] datastorage [15:0];
    
    always@(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
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
        else begin
            opcode_f_rf<=opcode_f_if;
            rs1_f_rf<=rs1_f_if;
            rs2_f_rf<=rs2_f_if;
            rd_f_rf<=rd_f_if;
            reg_write_enable_f_rf<=reg_write_enable_f_if;
            mem_write_enable_f_rf<=mem_write_enable_f_if;
            is_immed_f_rf<=is_immed_f_if;
            ALUsrc_f_rf <= ALUsrc_f_if;
            pc_f_rf <=pc_f_if;

            if(reg_write_enable_f_mem)
            datastorage[waddr]<=rf_write_input_data;
        end
    end
    assign rf_data_1 = datastorage[if_request_out_1];
    assign rf_data_2 = datastorage[if_request_out_2];
    
endmodule

module router(clk, reset_n);
    input clk, reset_n;  
  
    wire[0:15] data_f_mem;             //Data at pc, flip bits, big endian easier for this  
    wire [0:15] data_f_mem_pc; 
  
    reg signed[7:0]pc;                 //Program Counter in this module, no seperate module needed. Same as addr_to_mem most of the itme.
    
    wire [3:0] first_bits, second_bits, third_bits, fourth_bits;

    assign first_bits = {data_f_mem_pc[0],data_f_mem_pc[1],data_f_mem_pc[2],data_f_mem_pc[3]};
    assign second_bits= { data_f_mem_pc[4], data_f_mem_pc[5], data_f_mem_pc[6], data_f_mem_pc[7]};
    assign third_bits = {data_f_mem_pc[8], data_f_mem_pc[9], data_f_mem_pc[10], data_f_mem_pc[11]};  
    assign fourth_bits = {data_f_mem_pc[12], data_f_mem_pc[13], data_f_mem_pc[14], data_f_mem_pc[15]};           
    
    
    // initial first_bits = 4'b0101;
    // initial second_bits = 0;
    // initial third_bits = 0;
    // initial fourth_bits = 0;
    
    wire [7:0] pc_f_if;
    wire [3:0] opcode_f_if, rs1_f_if, rs2_f_if, rd_f_if;
    wire reg_write_enable_f_if, is_immed_f_if, mem_write_enable_f_if, ALUsrc_f_if;

    wire [7:0] pc_f_rf;
    wire [3:0] opcode_f_rf, rs1_f_rf, rs2_f_rf, rd_f_rf;
    wire reg_write_enable_f_rf, is_immed_f_rf, mem_write_enable_f_rf;
    
    wire [7:0] pc_f_alu;
    wire [15:0] write_data_f_alu;
    wire signed[15:0] data_f_rf_rs1;
    wire signed[15:0] data_f_rf_rs2;
    
    wire ALUsrc;    
    
    wire signed [15:0] alu_mux_rs2_input;
    assign alu_mux_rs2_input = ALUsrc ? data_f_rf_rs2 : rs2_f_rf;
    wire [3:0] opcode_f_alu, rd_f_alu;
    wire reg_write_enable_f_alu, mem_write_enable_f_alu;
    
    wire signed [15:0] alu_out;
    wire signed [15:0] rf_write_input_data;
    wire signed [15:0] rf_mux_write_input_data;
    assign rf_mux_write_input_data = reg_write_enable_f_mem ? data_f_mem : alu_out;
    
    wire [7:0] pc_f_mem;
    wire reg_write_enable_f_mem;
    wire[3:0] rd_f_mem;
    
    //assign data_f_rf_rs2 = is_immed_f_rf ? third_bits : data_f_rf_rs2;
    initial $monitor ("First bits are: %b, data from memory out is %b, pc is %d", first_bits, data_f_mem_pc, pc);
    //initial $monitor("Data in target register: Binary: %b Decimal: %d Hex:%h  Program Counter:%d", data_f_rf_rs1, data_f_rf_rs2, data_to_rf, pc);
    //initial $monitor ("First bits are: %b", first_bits);
    
  IF instr_fetch (
      .clk                  (clk),
      .reset_n              (reset_n),
      .pc                   (pc),
      .pc_f_if              (pc_f_if),
      .first_bits           (first_bits),
      .second_bits          (second_bits),
      .third_bits           (third_bits),
      .fourth_bits          (fourth_bits),
      .opcode_f_if          (opcode_f_if),
      .rs1_f_if             (rs1_f_if),
      .rs2_f_if             (rs2_f_if),
      .rd_f_if              (rd_f_if),
      .reg_write_enable_f_if(reg_write_enable_f_if),
      .is_immed_f_if        (is_immed_f_if),
      .mem_write_enable_f_if(mem_write_enable_f_if)
  );
  RF2 register_file2 (
      .clk                   (clk),
      .reset_n               (reset_n),
      .pc_f_if               (pc_f_if),
      .pc_f_rf               (pc_f_rf),
      .reg_write_enable_f_if (reg_write_enable_f_if),
      .mem_write_enable_f_if (mem_write_enable_f_if),
      .ALUsrc_f_if           (ALUsrc_f_if),
      .ALUsrc_f_rf           (ALUsrc),
      .is_immed_f_if         (is_immed_f_if),
      .opcode_f_if           (opcode_f_if),
      .rs1_f_if              (rs1_f_if),
      .rs2_f_if              (rs2_f_if),
      .rd_f_if               (rd_f_if),
      .opcode_f_rf           (opcode_f_rf),
      .rs1_f_rf              (rs1_f_rf),
      .rs2_f_rf              (rs2_f_rf),
      .rd_f_rf               (rd_f_rf),
      .reg_write_enable_f_rf (reg_write_enable_f_rf),
      .mem_write_enable_f_rf (mem_write_enable_f_rf),
      .is_immed_f_rf         (is_immed_f_rf),
      .if_request_out_1      (rs1_f_if),
      .if_request_out_2      (rs2_f_if),
      .waddr                 (rd_f_mem),
      .rf_write_input_data   (rf_mux_write_input_data),
      .rf_data_1             (data_f_rf_rs1),
      .rf_data_2             (data_f_rf_rs2),
      .reg_write_enable_f_mem(reg_write_enable_f_mem)
  );
  ALU alu (
      .clk                   (clk),
      .reset_n               (reset_n),
      .pc_f_rf               (pc_f_rf),
      .pc_f_alu              (pc_f_alu),
      .reg_write_enable_f_rf (reg_write_enable_f_rf),
      .mem_write_enable_f_rf (mem_write_enable_f_rf),
      .opcode_f_rf           (opcode_f_rf),
      .rd_f_rf               (rd_f_rf),
      .rd_f_alu              (rd_f_alu),
      .rs2_f_rf              (rs2_f_rf),
      .reg_write_enable_f_alu(reg_write_enable_f_alu),
      .mem_write_enable_f_alu(mem_write_enable_f_alu),
      .data_f_rf_rs1         (data_f_rf_rs1),
      .data_f_rf_rs2         (data_f_rf_rs2),
      .alu_out               (alu_out)
  );
  MEM memory2 (
      .addr                  (alu_out),
      .data_in               (data_f_rf_rs2),
      .pc_f_alu              (pc_f_alu),
      .pc_f_mem              (pc_f_mem),
      .write_enable          (mem_write_enable_f_alu),
      .data_out              (data_f_mem),
      .data_out_pc           (data_f_mem_pc),
      .rd_f_alu              (rd_f_alu),
      .rd_f_mem              (rd_f_mem),
      .reg_write_enable_f_alu(reg_write_enable_f_alu),
      .reg_write_enable_f_mem(reg_write_enable_f_mem)
  );

    always @(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            pc<=0;
        end
        else if(first_bits==4'b0101) begin
            pc<=pc_f_mem;
        end

        else if(first_bits==4'b0001) begin
            pc<=pc_f_mem;
        end

        if(pc==5) begin
            $finish;
        end
    end
    
endmodule
