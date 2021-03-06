`default_nettype none
/* The TB reads the instructions file 
   While sending the instructions to the DUT's memory, valid_n = 1
   When we start, set start = 1, valid_n = 0
*/
module tb; 
    reg [15:0] instruction;
    reg [15:0] instructions [0:256];
    wire [15:0] register_file [15:0];

    initial begin
    $readmemb("instructions4.mem", instructions); 
    end
    reg reset_n,clock, valid_n, start;
    wire finished;

    initial clock = 0;      
    initial reset_n = 1;    /* Resets the dut */
    initial valid_n = 1;    /* Used to signal the DUT to read incoming instructions */
    always #5 clock=!clock; 

    integer i = 0;
    assign instruction = instructions[i];
    always @(posedge clock, negedge reset_n) begin
        
        if(!reset_n) begin
            i <= 0;
        end

        else begin
            if(valid_n) begin
                //$display("%b", instruction);
                if(i<8) begin
                    i<=i+1;
                end else begin
                    valid_n <=0;
                    @(posedge clock);
                    start <= 1;
                end  
            end
            if(finished) begin
                for(int i = 0; i <16; i++) begin
                    $display("%d", register_file[i]);
                end
                $finish;
            end
            
        end
    end

    router cpu(.clk(clock), .reset_n(reset_n), .instruction(instruction), .valid_n(valid_n), .start(start), .finished_o2(finished), .register_file_out(register_file));
    initial begin 
        repeat(2) @(posedge clock) ;
        @(posedge clock) ;
        reset_n = 0;
        repeat(4) @(posedge clock)
        @(posedge clock) ;
        reset_n = 1;
    end

    
endmodule

/*  Instruction Fetch 
    Most outputs are from forwarding data to the next stage (Instruction Decode(Register File))
*/
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
    input STALL,
    output reg finished,
    output reg forward_disable,
    input start
    );
    
    always @(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            pc_f_if<=0;
            ALUsrc_f_if<=0;
            finished <= 0;
            forward_disable <= 0;
        end
        else if(start) begin

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
    
                if(first_bits==4'b0001) begin   //store word, sw x3, 0(x2), rs1 = x2    rs2/im = 0      rd = x3
                    is_immed_f_if <= 1;
                    mem_write_enable_f_if <= 1;
                    reg_write_enable_f_if <= 0;
                    ALUsrc_f_if <= 1;
                end
    
                if(first_bits==4'b1111) begin   //halt
                    finished <= 1;
                    mem_write_enable_f_if <= 0;
                    reg_write_enable_f_if <= 0;
                    ALUsrc_f_if <= 0;
                end
            end   
        end
    end
    
endmodule

/*  Register File
    16 registers, 16 bits each
*/

module RF2 (
    input clk, reset_n, 
    input [7:0] pc_f_if,
    output reg [7:0] pc_f_rf,
    input reg_write_enable_f_if, 
    mem_write_enable_f_if, 
    is_immed_f_if, 
    ALUsrc_f_if, 
    is_jump_f_if, 
    reg_write_enable_f_mem,

    output reg reg_write_enable_f_rf, 
    mem_write_enable_f_rf, 
    is_immed_f_rf, 
    ALUsrc_f_rf, 
    is_jump_f_rf,

    input [3:0] opcode_f_if, rs1_f_if, rs2_f_if, rd_f_if, 
    output reg[3:0] opcode_f_rf, rs1_f_rf, rs2_f_rf, rd_f_rf, 
    input[3:0] if_request_out_1, if_request_out_2, waddr, 
    input [15:0] rf_write_input_data, 
    output reg [15:0] rf_data_1, rf_data_2,
    output reg [15:0] rf_data_rd, /* This is used in SW */
    input STALL, STALL_FELL, 
    input start,
    output reg [15:0] datastorage [15:0]

    ); 
    
    reg reg_write_enable_f_if_restore, mem_write_enable_f_if_restore;
    
    always@(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            datastorage[0]  <= 50;          //using readable and acessible values, $urandom is not good for testing
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
            datastorage[12] <= 980;
            datastorage[13] <= 990;
            datastorage[14] <= 991;
            datastorage[15] <= 992;
            //datastorage[15] <= $urandom;
        end 

        else if(start) begin
  
            opcode_f_rf<=opcode_f_if;
            rs1_f_rf<=rs1_f_if;
            rs2_f_rf<=rs2_f_if;
            rd_f_rf<=rd_f_if;
            ALUsrc_f_rf <= ALUsrc_f_if;
            pc_f_rf <=pc_f_if;

            /* Get the data of pointed by RS1 and RS2 from the RF */
            rf_data_1 <= datastorage[if_request_out_1];
            rf_data_2 <= datastorage[if_request_out_2];
            rf_data_rd <= datastorage[rd_f_if]; /* This is used in SW, the last 4 bits of the instruction (rd) is the register to store at the address  */
            
            /* If we are stalled, we do not want to commit the instruction (they are garbage data) */
            if(STALL) begin
                reg_write_enable_f_rf <= 0;
                mem_write_enable_f_rf <= 0;
                is_immed_f_rf <= 0;
            end

            else begin
            /* Under normal conditions we can forward data from the IF stage */
                reg_write_enable_f_rf<=reg_write_enable_f_if;
                mem_write_enable_f_rf<=mem_write_enable_f_if;
                is_immed_f_rf<=is_immed_f_if;
            
            /* If the write signal is enabled, write to the register file */
                if(reg_write_enable_f_mem) begin
                    datastorage[waddr] <= rf_write_input_data;
                end
            end
        end
    end
    
    
endmodule

/* ALU module
   Even though we decoded the opcode in the IF stage, it is not a big deal to check the arithmatic instruction by checking the opcode here
   We would only be saving a bit of area if we encoded the ALU operation  */

module ALU(
    input clk, reset_n, reg_write_enable_f_rf, mem_write_enable_f_rf, is_jump_f_rf, 
    input [7:0] pc_f_rf,
    output reg [7:0] pc_f_alu,
    input [3:0] opcode_f_rf, rs2_f_rf, rd_f_rf,
    output reg [3:0] opcode_f_alu, rd_f_alu,
    output reg reg_write_enable_f_alu, mem_write_enable_f_alu,  
    input [15:0] alu_input_rs1, alu_input_rs2, 
    input [15:0] alu_input_rd,
    output reg [15:0]alu_out,
    output reg [15:0] data_f_alu_rs1,
    output reg [15:0] data_f_alu_rd,
    input STALL, STALL_FELL,
    input start
    );

    always @(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            pc_f_alu <= 0;
        end
        else if (start) begin

            /* Forwarding data from previous stages */
            reg_write_enable_f_alu <= reg_write_enable_f_rf;
            mem_write_enable_f_alu <= mem_write_enable_f_rf;

            opcode_f_alu <= opcode_f_rf;
            rd_f_alu <= rd_f_rf;
            data_f_alu_rs1 <= alu_input_rs1;
            data_f_alu_rd <= alu_input_rd;
            $display("alu printing data_f_alu_rd", alu_input_rd);
            /* Checking the opcode again for the operation */
            
            if(opcode_f_rf==4'b0100) begin    // add, add x1, x2, x3     rs1 = x2, rs2 = x3, rd=x1
                alu_out <= alu_input_rs1+alu_input_rs2;
                pc_f_alu <= pc_f_rf;
            end
            
            if(opcode_f_rf==4'b0000) begin   //load word
                alu_out <= alu_input_rs1 + alu_input_rs2;
                pc_f_alu <= pc_f_rf;
            end
            
            if(opcode_f_rf == 4'b0001) begin   //store word
                alu_out <= alu_input_rs1 + alu_input_rs2;
                pc_f_alu <= pc_f_rf;
            end
            
            if(opcode_f_rf == 4'b0100) begin  //add
                alu_out <= alu_input_rs1 + alu_input_rs2;
                pc_f_alu <= pc_f_rf;
            end
            
            if(opcode_f_rf == 4'b0101) begin    //sub
                alu_out <= alu_input_rs1 - alu_input_rs2;
                pc_f_alu <= pc_f_rf;
            end
            
            if(opcode_f_rf == 4'b1000) begin    //addi
                alu_out <= alu_input_rs1 + alu_input_rs2;
                pc_f_alu <= pc_f_rf;
            end 
        end
    end
endmodule

/* Memory stage, a cache is to be added here
   This is essentially an SRAM as it is now */

module MEM(
    input clk, reset_n,
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
    output reg MemtoReg,
    input [15:0] instruction,
    input valid_n,
    input start
    );

    reg [15:0] instructions [0:256];    /* Instruction Memory */
    reg [15:0] memory [0:1024];
    //reg [7:0] memory2 [0:1024];         /* We will make the memory 8 bits long instead */
    reg [7:0] instruction_counter;      /* We have a seperate counter for loading instructions
                                           We use the pc in normal operation */
    
    assign data_out_pc = instructions[pc];
    
    always@(posedge clk, negedge reset_n)
    begin
        if(!reset_n) begin
            instruction_counter <= 0;
        end 
        else begin
            if(valid_n) begin
                /* If valid_n is high, load instructions from the TB */
                instructions[instruction_counter] <= instruction;
                instruction_counter++;
            end else if(start) begin
                /*Forward data from previous stages */
                reg_write_enable_f_mem <= reg_write_enable_f_alu;
                data_out <= memory[addr];
                //data_out <= { memory2[addr+1], memory2[addr] };
                pc_f_mem <= pc_f_alu;
                rd_f_mem <= rd_f_alu;
                alu_out_f_mem <= alu_out;
        
                if(write_enable) begin
                    $display("data in is %h", data_in);
                    memory[addr] <= data_in;
                    //memory2[addr] <= data_in[7:0];
                    //memory2[addr+1] <= data_in[15:8];
                end

                if(opcode_f_alu==4'b0000) begin
                    /* If we have a load word instruction, we will be writing to the RF */
                    MemtoReg <= 1;
                end 
                else begin
                    MemtoReg <= 0;
                end
            end 
        end
    end
endmodule

module router(input clk, input reset_n, input [15:0] instruction, input valid_n, input start, output [15:0] register_file_out [15:0], output valido_n, output reg finished_o2, output reg start_o);

    wire finished_internal;
    assign valido_n = valid_n;
    assign start_o = start;
    
    wire signed [15:0] data_f_mem;      //Data from the memory, used by lw/sw         
    wire signed [0:15] data_f_mem_pc;   //Data at pc, flip bits, big endian is possibly easier for this 
  
    reg [7:0]pc;                        //Program Counter in this module, no seperate module needed. Same as addr_to_mem most of the itme.
    
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
    wire signed [15:0] data_f_rf_rd;
    wire signed [15:0] alu_mux_rs1_input;
    wire signed [15:0] data_f_alu_rs1;

    /* Forwarding signals */
    reg forward_enable_rs1_EX_ID, forward_enable_rs2_EX_ID; 
    reg forward_enable_rs1_MEM_ID, forward_enable_rs2_MEM_ID;

    wire ALUsrc;    //for rs2 input, 0 is rs2 is from rf, 1 if from immediete value in instruction
    
    wire [3:0] opcode_f_alu, rd_f_alu;
    wire reg_write_enable_f_alu, mem_write_enable_f_alu;
    
    wire signed [15:0] alu_out;
    wire signed [15:0] rf_write_input_data;
    wire signed [15:0] rf_mux_write_input_data;
    wire signed [15:0] data_f_alu_rd;
    
    wire signed [15:0] alu_out_f_mem;
    wire [7:0] pc_f_mem;
    wire reg_write_enable_f_mem;    //control write_enable for register file
    wire[3:0] rd_f_mem;
    wire MemtoReg;                  //control whether data is writing to memory or register file
    assign rf_mux_write_input_data = MemtoReg ? data_f_mem : alu_out_f_mem;

    wire signed [15:0] alu_mux_rs2_input;
    
    wire [1:0] alu_mux_rs1_select;
    assign alu_mux_rs1_select =  {forward_enable_rs1_EX_ID, forward_enable_rs1_MEM_ID};
    assign alu_mux_rs1_input = alu_mux_rs1_select[1] ? alu_out : (alu_mux_rs1_select[0] ? alu_out_f_mem : data_f_rf_rs1);

    wire [2:0] alu_mux_rs2_select;  
    assign alu_mux_rs2_select = {forward_enable_rs2_EX_ID, forward_enable_rs2_MEM_ID, ALUsrc};
    assign alu_mux_rs2_input = alu_mux_rs2_select[2] ? alu_out : (alu_mux_rs2_select[1] ? alu_out_f_mem : (alu_mux_rs2_select[0] ? rs2_f_rf : data_f_rf_rs2)); 

    reg STALL;
    reg STALL_FELL;
    wire forward_disable;
    reg [15:0] terminate_in_5;

    initial $monitor ("PC: %d, rs1_f_if %d, rs2_f_if %d, rd_f_if %d, rs1_f_rf %d, rs2_f_rf %d, rd_f_rf %d, rd_f_alu %d, alu_out %d, rs1_on_alu %d, rs2_on_alu %d" , pc, rs1_f_if, rs2_f_if, rd_f_if, rs1_f_rf,rs2_f_rf, rd_f_rf, rd_f_alu, alu_out, alu_mux_rs1_input, alu_mux_rs2_input  );
  
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
      .STALL                (STALL),
      .finished             (finished_internal),
      .forward_disable      (forward_disable),
      .start                (start)
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
      .rf_data_rd            (data_f_rf_rd),
      .reg_write_enable_f_mem(reg_write_enable_f_mem),
      .STALL                 (STALL),
      .STALL_FELL            (STALL_FELL),
      .datastorage           (register_file_out),
      .start                 (start)
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
      .alu_input_rd           (data_f_rf_rd),
      .data_f_alu_rd          (data_f_alu_rd),
      .STALL                  (STALL),
      .STALL_FELL             (STALL_FELL),
      .start                  (start)
  );

  MEM memory2 (
      .clk                   (clk),
      .reset_n               (reset_n),
      .addr                  (alu_out),
      .data_in               (data_f_alu_rd),
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
      .MemtoReg              (MemtoReg),
      .instruction           (instruction),
      .valid_n               (valid_n),
      .start                 (start)
  );

/* lw x1, 0(x2) //load into x1, the address in x2 
   add x2, x1, x1, need to stall here */

  always @(*) begin
      if(opcode_f_alu == 4'b0000 && (rd_f_alu == rs1_f_rf || rd_f_alu == rs2_f_rf)) begin
        STALL = 1;
        $display("Stall activated");
      end else begin
          STALL = 0;
          $display("Stall deactivated");
      end
  end

    always @(posedge clk, negedge reset_n) begin    
        
        if(!reset_n) begin
            pc <= 0;
            forward_enable_rs1_EX_ID <= 0;
            forward_enable_rs2_EX_ID <= 0;
            forward_enable_rs1_MEM_ID <= 0;
            forward_enable_rs2_MEM_ID <= 0;
            STALL <= 0;
            finished_o2 <= 0;
            terminate_in_5 <= 0;
        end
        
        else begin

            $display("Instruction is %b", instruction);

            if(start) begin

                // if(STALL) begin
                //     STALL <= 0;
                //     STALL_FELL <= 1;
                // end

                if(!STALL && !finished_internal) 
                    pc <= pc + 1;
                
                // if(STALL_FELL) begin
                //     STALL_FELL <= 0;
                // end
                
                if(forward_enable_rs1_MEM_ID) begin
                    //RS1_MEM_ID_CYCLE_DELAY <= 1;
                    forward_enable_rs1_MEM_ID <= 0;
                end

                if(forward_enable_rs2_MEM_ID) begin
                    //RS2_MEM_ID_CYCLE_DELAY <= 1;
                    forward_enable_rs2_MEM_ID <=0;
                end
                
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
                /*Forwarding support, distance of 2. We are looking from IF to ALU_OUT
                This data then will take priority over the stale copy 
                Example:
                1.  x2 = x3 = x4  ,
                2.  x3 = x2 + x3
                3.  x2 = x2 + x2  ,need x2 from line 1 
                
                x2 is consumed line 2, EX_ID handles that instead. We are handling consumption of x2 on line 3. 
                We also should make sure RD from line 1 and line 2 do not match. Otherwise EX_ID would handle this.
                */
                    if(rd_f_alu == rs1_f_if && (rd_f_alu != rd_f_rf)) begin
                        forward_enable_rs1_MEM_ID <= 1;
                        $display("forward_enable_rs1_MEM_ID triggered\n");
                    end

                    if(rd_f_alu == rs2_f_if && (rd_f_alu != rd_f_rf)) begin
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
                    //$display("Inside trigger loops\n");

                    // if(opcode_f_rf == 4'b0000 && (rd_f_rf == rs1_f_if || rd_f_rf == rs2_f_if)) begin
                    //     $display("\nSTALL ACTIVE\n");
                    //     STALL<=1;
                    // end
                    if(!forward_disable) begin
                        /*Forwarding support, distance of 1. We are looking from IF output to RF output
                        This data then will take priority over the stale copy 
                        Example:
                        1.  x2 = x3 = x4  
                        2.  x3 = x2 + x3
                        3.  x2 = x2 + x2  
                        
                        x2 consumed line 2, We are handling that case here.
                        We are not handling x2 being consumed on line 3, that is handled by MEM_ID.*/
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
                end
                
                else begin
                    forward_enable_rs1_EX_ID <= 0;
                    forward_enable_rs2_EX_ID <= 0;
                    forward_enable_rs1_MEM_ID <= 0;
                    forward_enable_rs2_MEM_ID <= 0;
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
                
                if(finished_internal) begin
                    terminate_in_5 <= 7;
                    //$display("Activated\n");
                end

                if(terminate_in_5 > 1) begin
                    terminate_in_5 <= terminate_in_5 - 1;
                end

                if(terminate_in_5 == 1) begin
                    finished_o2 <= 1;
                end

                if(pc==10) begin

                end
            end
        end
    end
    
endmodule