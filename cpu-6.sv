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

module IF(
    input clk, reset_n, 
    input [7:0] pc,
    input [3:0] first_bits, second_bits, third_bits, fourth_bits, 
    output reg [7:0] pc_f_if,
    output reg [3:0] opcode_f_if, rs1_f_if, rs2_f_if, rd_f_if, 
    output reg ALUsrc_f_if,
    output reg reg_write_enable_f_if, 
    output reg mem_write_enable_f_if,
    output reg is_immed_f_if,
    output reg is_jump_f_if,
    input STALL
    );
    
    

    always @(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            pc_f_if<=0;
            ALUsrc_f_if<=0;
        end
        else begin

            opcode_f_if<=first_bits;
            rs1_f_if<=second_bits;
            rs2_f_if<=third_bits;
            rd_f_if<=fourth_bits;
            pc_f_if<=pc+1;

            if(STALL) begin
                reg_write_enable_f_if <= 0;
                mem_write_enable_f_if <= 0;
                is_immed_f_if <= 0;
                ALUsrc_f_if <= 0;
            end
            
            else begin
                if(first_bits==4'b0000) begin    //load word, lw x3, 0(x2), rs1 = x2    rs2/im = 0      rd = x3
                    is_immed_f_if<=1;
                    ALUsrc_f_if<=1;
                    reg_write_enable_f_if <= 1;
                    mem_write_enable_f_if <= 0;
                end
                
                if(first_bits==4'b1000) begin   //addi
                    //$display("hello");
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
                
                if(first_bits==4'b0101) begin   //sub
                    is_immed_f_if <= 0;
                    mem_write_enable_f_if <= 0;
                    reg_write_enable_f_if <= 1;
                    ALUsrc_f_if<=0;
                end
    
                if(first_bits==4'b0001) begin   //sw
                    is_immed_f_if <= 1;
                    mem_write_enable_f_if <= 1;
                    reg_write_enable_f_if <= 0;
                    ALUsrc_f_if <= 1;
                end
    
                if(first_bits==4'b1111) begin
                    $finish;
                end
            end   
        end
    end
    
endmodule


module RF2 (
    input clk, reset_n, 
    input [7:0] pc_f_if,
    output reg [7:0] pc_f_rf,
    input reg_write_enable_f_if, 
    mem_write_enable_f_if, is_immed_f_if, 
    ALUsrc_f_if, 
    is_jump_f_if, 
    reg_write_enable_f_mem,
    output reg reg_write_enable_f_rf, mem_write_enable_f_rf, is_immed_f_rf, ALUsrc_f_rf, is_jump_f_rf,
    input [3:0] opcode_f_if, rs1_f_if, rs2_f_if, rd_f_if, 
    output reg[3:0] opcode_f_rf, rs1_f_rf, rs2_f_rf, rd_f_rf, 
    input[3:0] if_request_out_1, if_request_out_2, waddr, 
    input [15:0] rf_write_input_data, 
    output reg [15:0] rf_data_1, rf_data_2,
    input STALL, STALL_FELL
    //input [15:0] forward_data_f_alu_rs1, forward_data_f_alu_rs2

    ); 
    
    reg reg_write_enable_f_if_restore, mem_write_enable_f_if_restore;

    reg [15:0] datastorage [15:0];
    
    always@(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            datastorage[0]  <= 50;
            datastorage[1]  <= 200;
            datastorage[2]  <= 300;
            datastorage[3]  <= 400;
            datastorage[4]  <= 500;
            datastorage[5]  <= 600;
            datastorage[6]  <= 700;
            datastorage[7]  <= 800;
            datastorage[8]  <= 900;
            datastorage[9]  <= 950;
            datastorage[10] <= 960;
            datastorage[11] <= 970;
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
            ALUsrc_f_rf <= ALUsrc_f_if;
            pc_f_rf <=pc_f_if;
            rf_data_1 <= datastorage[if_request_out_1];
            rf_data_2 <= datastorage[if_request_out_2];

            if(STALL) begin
                reg_write_enable_f_rf <= 0;
                mem_write_enable_f_rf <= 0;
                is_immed_f_rf <= 0;
            end

            else if(STALL_FELL) begin
                reg_write_enable_f_rf <= reg_write_enable_f_if_restore;
                mem_write_enable_f_rf <= mem_write_enable_f_if_restore;
                
            end 

            else begin
                reg_write_enable_f_rf<=reg_write_enable_f_if;
                mem_write_enable_f_rf<=mem_write_enable_f_if;
                is_immed_f_rf<=is_immed_f_if;
                
                $display("register 2 contains %d\n", datastorage[2]);
                $display("register 3 contains: %d\n", datastorage[3]);
                $display("register 4 contains: %d\n", datastorage[4]);
                $display("register 6 contains %d\n", datastorage[6]);
                
                //$display("rs2_f_if is: %d\n", rs2_f_if);
                
                if(reg_write_enable_f_mem) begin
                    datastorage[waddr]<=rf_write_input_data;
                end
            end
        end
    end
    
    // assign rf_data_1 = datastorage[if_request_out_1];
    // assign rf_data_2 = datastorage[if_request_out_2];
    
endmodule

module ALU(
    input clk, reset_n, reg_write_enable_f_rf, mem_write_enable_f_rf, is_jump_f_rf, 
    input [7:0] pc_f_rf,
    output reg [7:0] pc_f_alu,
    input [3:0] opcode_f_rf, rs2_f_rf, rd_f_rf,
    output reg [3:0] opcode_f_alu, rd_f_alu,
    output reg reg_write_enable_f_alu, mem_write_enable_f_alu,  
    input [15:0] alu_input_rs1, alu_input_rs2, 
    output reg [15:0]alu_out,
    //input [15:0] data_f_alu_rs1,
    output reg [15:0] data_f_alu_rs1,
    input STALL, STALL_FELL
    //input forward_enable_rs1, forward_enable_rs2,
    //output reg [15:0] forward_data_f_alu_rs1, forward_data_f_alu_rs2
    );

    reg reg_write_enable_f_rf_restore;
    reg mem_write_enable_f_rf_restore;

    always @(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            pc_f_alu <= 0;
        end
        else begin

            if(STALL) begin
                reg_write_enable_f_rf_restore <= reg_write_enable_f_rf;
                mem_write_enable_f_rf_restore <= mem_write_enable_f_rf;
            end

            else if(STALL_FELL) begin
                reg_write_enable_f_alu <= reg_write_enable_f_rf_restore;
                mem_write_enable_f_alu <= mem_write_enable_f_rf_restore;
            end

            else begin
                reg_write_enable_f_alu <= reg_write_enable_f_rf;
                mem_write_enable_f_alu <= mem_write_enable_f_rf;
            end

            opcode_f_alu <= opcode_f_rf;
            rd_f_alu <= rd_f_rf;
            data_f_alu_rs1 <= alu_input_rs1;
            

            if(opcode_f_rf==4'b0100) begin    // add, add x1, x2, x3     rs1 = x2, rs2 = x3, rd=x1
                alu_out<=alu_input_rs1+alu_input_rs2;
                pc_f_alu<=pc_f_rf;
            end
            
            if(opcode_f_rf==4'b0000) begin   //load word
                alu_out<= alu_input_rs1 + alu_input_rs2;
                pc_f_alu<=pc_f_rf;
            end
            
            if(opcode_f_rf==4'b0001) begin   //store word
                alu_out<=alu_input_rs1 + alu_input_rs2;
                pc_f_alu<=pc_f_rf;
            end
            
            if(opcode_f_rf == 4'b0100) begin  //add
                alu_out<=alu_input_rs1 + alu_input_rs2;
                pc_f_alu<=pc_f_rf;
            end
            
            if(opcode_f_rf == 4'b0101) begin    //sub
               // $display("hello");
                alu_out<=alu_input_rs1 - alu_input_rs2;
                pc_f_alu<=pc_f_rf;
                //$display("testeststest");
            end
            
            if(opcode_f_rf == 4'b1000) begin    //addi
                alu_out <= alu_input_rs1 + alu_input_rs2;
                pc_f_alu<=pc_f_rf;
            end 
        end
    end
endmodule

module MEM(
    input clk,
    input [15:0] addr, data_in, 
    input write_enable, 
    input [7:0] pc_f_alu,
    input [7:0] pc,
    output reg [7:0] pc_f_mem,
    output reg [15:0] data_out, 
    output [15:0] data_out_pc,
    input reg_write_enable_f_alu, 
    input [3:0] rd_f_alu,
    output reg [3:0] rd_f_mem,
    output reg reg_write_enable_f_mem,

    input [15:0] alu_out,
    output reg [15:0] alu_out_f_mem,

    input [3:0] opcode_f_alu, 
    output reg MemtoReg
    
    );
    
    
    reg [15:0] instructions [0:256];
    /*
    8 bit input address limits memory space to 256 addresses as opposed to 65,536
    This will help will simluation.synthesis speed
    
    */
    //initial $monitor("Instruction in mem is %b", instructions[0] );
    
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

    //assign data_out_pc = instructions[pc_f_alu];
    assign data_out_pc = instructions[pc];
    
    always@(posedge clk)
    begin
        reg_write_enable_f_mem <= reg_write_enable_f_alu;
        //$display("Data at pc in mem is: %d", instructions[pc_f_alu] );
        $display("mem[14] is\n %d", instructions[14]);
        //$display("Data at 0 is %b", instructions[0]);
        //$display("%b", instructions[0]);
        data_out <= instructions[addr];
        pc_f_mem<=pc_f_alu;
        rd_f_mem <= rd_f_alu;
        alu_out_f_mem <= alu_out;

        

        if(write_enable) begin
            //$display("Should be false");
            instructions[addr]<=data_in;
        end

        if(opcode_f_alu==4'b0000) begin
            MemtoReg <= 1;
        end 
        else begin
            MemtoReg <= 0;
        end
    end
endmodule

module router(clk, reset_n);
    input clk, reset_n;  
  
    wire signed [15:0] data_f_mem;    //Data from the memory, used by lw/sw         
    wire signed [0:15] data_f_mem_pc; //Data at pc, flip bits, big endian easier for this 
  
    reg [7:0]pc;                 //Program Counter in this module, no seperate module needed. Same as addr_to_mem most of the itme.
    
    wire [3:0] first_bits, second_bits, third_bits, fourth_bits;

    assign first_bits = {data_f_mem_pc[0],data_f_mem_pc[1],data_f_mem_pc[2],data_f_mem_pc[3]};
    assign second_bits= { data_f_mem_pc[4], data_f_mem_pc[5], data_f_mem_pc[6], data_f_mem_pc[7]};
    assign third_bits = {data_f_mem_pc[8], data_f_mem_pc[9], data_f_mem_pc[10], data_f_mem_pc[11]};  
    assign fourth_bits = {data_f_mem_pc[12], data_f_mem_pc[13], data_f_mem_pc[14], data_f_mem_pc[15]};           
    
    wire [7:0] pc_f_if;
    wire [3:0] opcode_f_if, rs1_f_if, rs2_f_if, rd_f_if;
    wire reg_write_enable_f_if, is_immed_f_if, mem_write_enable_f_if, ALUsrc_f_if;

    wire [7:0] pc_f_rf;
    wire [3:0] opcode_f_rf, rs1_f_rf, rs2_f_rf, rd_f_rf;
    wire reg_write_enable_f_rf, is_immed_f_rf, mem_write_enable_f_rf;
    
    wire is_jump_f_if;
    wire is_jump_f_rf;
    
    wire [7:0] pc_f_alu;
    wire signed [15:0] write_data_f_alu;
    wire signed [15:0] data_f_rf_rs1;
    wire signed [15:0] data_f_rf_rs2;
    wire signed [15:0] alu_mux_rs1_input;

    wire signed [15:0] data_f_alu_rs1;

    reg forward_enable_rs1_EX_ID, forward_enable_rs2_EX_ID; 
    reg forward_enable_rs1_MEM_ID, forward_enable_rs2_MEM_ID;

    reg RS1_MEM_ID_CYCLE_DELAY, RS2_MEM_ID_CYCLE_DELAY;

    wire ALUsrc;    //for rs2 input, 0 is rs2 is from rf, 1 if from immediete value in instruction
    
    wire [3:0] opcode_f_alu, rd_f_alu;
    wire reg_write_enable_f_alu, mem_write_enable_f_alu;
    
    wire signed [15:0] alu_out;
    wire signed [15:0] rf_write_input_data;
    wire signed [15:0] rf_mux_write_input_data;
    
    wire signed [15:0] alu_out_f_mem;
    wire [7:0] pc_f_mem;
    wire reg_write_enable_f_mem;
    wire[3:0] rd_f_mem;
    wire MemtoReg;
    assign rf_mux_write_input_data = MemtoReg ? data_f_mem : alu_out_f_mem;

    wire signed [15:0] alu_mux_rs2_input;
    
    wire signed [15:0] alu_mux_rs2_input_1; //delete later not used
    
    wire [1:0] alu_mux_rs1_select;
    assign alu_mux_rs1_select =  {forward_enable_rs1_EX_ID, forward_enable_rs1_MEM_ID};
    assign alu_mux_rs1_input = alu_mux_rs1_select[1] ? alu_out : (alu_mux_rs1_select[0] ? alu_out_f_mem : data_f_rf_rs1);

    wire [2:0] alu_mux_rs2_select;  
    assign alu_mux_rs2_select = {forward_enable_rs2_EX_ID, forward_enable_rs2_MEM_ID, ALUsrc};
    assign alu_mux_rs2_input = alu_mux_rs2_select[2] ? alu_out : (alu_mux_rs2_select[1] ? alu_out_f_mem : (alu_mux_rs2_select[0] ? rs2_f_rf : data_f_rf_rs2)); 

    wire [1:0]alu_mux_rs2_combined_control; //delete later not used

    reg STALL;
    reg STALL_FELL;

    //assign data_f_rf_rs2 = is_immed_f_rf ? third_bits : data_f_rf_rs2;
    //initial $monitor ("First bits are: %b, instruction from memory out is %b, pc is %d, alu out is: %b,  data at reg write port is %d, reg_write_enable is %d, data sitting on mux rs1 is: %d, data sitting on mux rs2 is: %d, data_f_rf_rs1 is %d, data_f_rf_rs2 is %d, opcode_f_rf: %b, opcode_f_alu: %b, rs1_f_rf is: %b, rs2_f_rf is %b, ALUsrc, is: %d, alu_mux_rs2_combined_control is: %b, opcode_f_if: %b, mem_write_enable_f_alu is: %d, alu_mux_rs2_input_1 is: %d, rd_f_rf is %b", first_bits, data_f_mem_pc, pc, alu_out, rf_mux_write_input_data, reg_write_enable_f_mem, alu_mux_rs1_input, alu_mux_rs2_input, data_f_rf_rs1, data_f_rf_rs2, opcode_f_rf, opcode_f_alu, rs1_f_rf, rs2_f_rf, ALUsrc,alu_mux_rs2_combined_control, opcode_f_if, mem_write_enable_f_alu, alu_mux_rs2_input_1, rd_f_rf   );
    initial $monitor ("PC: %d, Instruction from memory: %b, alu out is: %d, data at reg_write port: %d", pc, data_f_mem_pc, alu_out, rf_mux_write_input_data);
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
      .mem_write_enable_f_if(mem_write_enable_f_if),
      .is_jump_f_if         (is_jump_f_if),
      .ALUsrc_f_if          (ALUsrc_f_if),
      .STALL                (STALL)
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
      .is_jump_f_if          (is_jump_f_if),
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
      .is_jump_f_rf          (is_jump_f_rf),
      .if_request_out_1      (rs1_f_if),
      .if_request_out_2      (rs2_f_if),
      .waddr                 (rd_f_mem),
      .rf_write_input_data   (rf_mux_write_input_data),
      .rf_data_1             (data_f_rf_rs1),
      .rf_data_2             (data_f_rf_rs2),
      .reg_write_enable_f_mem(reg_write_enable_f_mem),
      .STALL                 (STALL),
      .STALL_FELL            (STALL_FELL)
    //   .forward_data_f_alu_rs1 (forward_data_f_alu_rs1),
    //   .forward_data_f_alu_rs2 (forward_data_f_alu_rs2)
      
  );
  ALU alu (
      .clk                    (clk),
      .reset_n                (reset_n),
      .pc_f_rf                (pc_f_rf),
      .pc_f_alu               (pc_f_alu),
      .reg_write_enable_f_rf  (reg_write_enable_f_rf),
      .mem_write_enable_f_rf  (mem_write_enable_f_rf),
      .opcode_f_rf            (opcode_f_rf),
      .opcode_f_alu           (opcode_f_alu),
      .rd_f_rf                (rd_f_rf),
      .rd_f_alu               (rd_f_alu),
      .rs2_f_rf               (rs2_f_rf),
      .reg_write_enable_f_alu (reg_write_enable_f_alu),
      .mem_write_enable_f_alu (mem_write_enable_f_alu),
      .alu_input_rs1          (alu_mux_rs1_input),
      .alu_input_rs2          (alu_mux_rs2_input),
      .alu_out                (alu_out),
      .is_jump_f_rf           (is_jump_f_rf),
      .data_f_alu_rs1         (data_f_alu_rs1),
      .STALL                  (STALL),
      .STALL_FELL             (STAL_FELL)
    //   .forward_data_f_alu_rs1 (forward_data_f_alu_rs1),
    //   .forward_data_f_alu_rs2 (forward_data_f_alu_rs2),
    //   .forward_enable_rs1     (forward_enable_rs1),
    //   .forward_enable_rs2     (forward_enable_rs2)
  );
  MEM memory2 (
      .clk (clk),
      .addr                  (alu_out),
      .data_in               (data_f_alu_rs1),
      .pc_f_alu              (pc_f_alu),
      .pc_f_mem              (pc_f_mem),
      .write_enable          (mem_write_enable_f_alu),
      .data_out              (data_f_mem),
      .data_out_pc           (data_f_mem_pc),
      .rd_f_alu              (rd_f_alu),
      .rd_f_mem              (rd_f_mem),
      .reg_write_enable_f_alu(reg_write_enable_f_alu),
      .reg_write_enable_f_mem(reg_write_enable_f_mem),
      .pc                    (pc),
      .alu_out               (alu_out),
      .alu_out_f_mem         (alu_out_f_mem),
      .opcode_f_alu          (opcode_f_alu),
      .MemtoReg              (MemtoReg)
  );

  

    always @(posedge clk, negedge reset_n) begin    

        if(!reset_n) begin
            pc<=0;
            forward_enable_rs1_EX_ID <= 0;
            forward_enable_rs2_EX_ID <= 0;
            forward_enable_rs1_MEM_ID <= 0;
            forward_enable_rs2_MEM_ID <= 0;
            STALL<=0;
            RS1_MEM_ID_CYCLE_DELAY <= 0;
            RS2_MEM_ID_CYCLE_DELAY <= 0;
        end
        
        else begin

            if(STALL) begin
                STALL <= 0;
                STALL_FELL <= 1;
            end

            if(!STALL) 
                pc <= pc +1;
            
            if(STALL_FELL) 
                STALL_FELL <= 0;
            
            if(forward_enable_rs1_MEM_ID) begin
                RS1_MEM_ID_CYCLE_DELAY <= 1;
                forward_enable_rs1_MEM_ID <= 0;
            end

            if(forward_enable_rs2_MEM_ID) begin
                RS2_MEM_ID_CYCLE_DELAY <= 1;
                forward_enable_rs2_MEM_ID <=0;
            end
            
            if(RS1_MEM_ID_CYCLE_DELAY) 
                RS2_MEM_ID_CYCLE_DELAY <= 0;
            
            if(RS2_MEM_ID_CYCLE_DELAY)
                RS2_MEM_ID_CYCLE_DELAY <= 0;


            if((opcode_f_alu == 4'b0100 || 
            opcode_f_alu == 4'b0101 || 
            opcode_f_alu == 4'b1000 ||
            opcode_f_alu == 4'b0000 ||
            opcode_f_alu == 4'b0001) && 
            
            (opcode_f_if==4'b0100 || 
            opcode_f_if==4'b0101 || 
            opcode_f_if==4'b1000 || 
            opcode_f_if==4'b0001 ||
            opcode_f_if==4'b0000)) 

            begin   

                if(rd_f_alu == rs1_f_if && rd_f_rf!=rs1_f_if) begin
                    forward_enable_rs1_MEM_ID <= 1;
                    $display("forward_enable_rs1_MEM_ID triggered\n");
                end

                if(rd_f_alu == rs2_f_if && rd_f_rf!=rs2_f_if) begin
                    forward_enable_rs2_MEM_ID <= 1;
                    $display("forward_enable_rs2_MEM_ID triggered\n");
                end
            end
            
            if((opcode_f_rf == 4'b0100 || 
            opcode_f_rf == 4'b0101 || 
            opcode_f_rf == 4'b1000 ||
            opcode_f_rf == 4'b0000 ||
            opcode_f_rf == 4'b0001) && 
            
            (opcode_f_if==4'b0100 || 
            opcode_f_if==4'b0101 || 
            opcode_f_if==4'b1000 || 
            opcode_f_if==4'b0001 ||
            opcode_f_if==4'b0000)) 

            begin   
                $display("yooooooooooooooooooooooooo\n");

                if(opcode_f_rf == 4'b0000 && (rd_f_rf == rs1_f_if || rd_f_rf == rs2_f_if)) begin
                    $display("\nSTALL ACTIVE\n");
                    STALL<=1;
                end
                
                if(rd_f_rf == rs1_f_if)  begin
                    forward_enable_rs1_EX_ID <= 1;
                    $display("forward_enable_rs1_EX_ID triggered\n");
                end 
                    else begin
                        forward_enable_rs1_EX_ID <= 0;
                    end

                if(rd_f_rf == rs2_f_if) begin
                    forward_enable_rs2_EX_ID <= 1;
                    $display("forward_enable_rs2_EX_ID triggered\n");

                end 
                    else begin
                        forward_enable_rs2_EX_ID <= 0;
                    end

            end
            
            else begin
                 forward_enable_rs1_EX_ID <= 0;
                 forward_enable_rs2_EX_ID <= 0;
            end

            if(first_bits==4'b0101) begin
                //pc<=pc_f_mem;
            end

            else if(first_bits==4'b0001) begin
                //pc<=pc_f_mem;
            end

            else if(first_bits==4'b1000) begin
                //pc<=pc_f_mem;
            end

            if(pc==10) begin
                $finish;
            end
        end
    end
    
endmodule