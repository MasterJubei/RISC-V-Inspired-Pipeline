typedef enum {READ, WRITE} INSTR_TYPE;

module tb();
    reg[15:0] instructions [0:31];
    initial begin
    $readmemb("instructions3.mem", instructions); 
    end
    
    reg clk;
    reg [15:0] address = 16'h0004;
    reg [15:0] data = 16'h0100;
    reg [15:0] data_f_dut;
    reg activate = 0;
    //reg [1:0] instr_type = 0;
    
    INSTR_TYPE instr_type;

    initial begin
        instr_type = WRITE;
    end

    always #5 clk = ~clk;

    cache dut (
        .address_in(address),
        .data_in(data), 
        .data_out(data_f_dut), 
        .activate(activate),
        .instr_type (instr_type)
        );

    
    initial begin
        #5;
        activate = 1;
        #5;
    end
    

endmodule

module cache(
    input[15:0] address_in,
    input [15:0] data_in,
    output reg[15:0] data_out,
    input activate,
    input INSTR_TYPE instr_type,   // 0 = read, 1 = write
    output save_to_mem, /* If high, save data to memory (due to cache eviction) */
    output [31:0] data_to_mem /*The data that should be saved from the cache to memory */
); 
    reg [7:0] vld;
    reg [31:0] cache_data [0:7]; /* If you load address 0x02, get the data for 0x00 as well in the cache. If you grab 0x00, also get 0x02 */
    reg [10:0] tag_number [0:7]; 
    reg [15:0] block_address; /*We will divide address by cache size to get block address */ 
    reg [15:0] block_number; /*We will modulo the block addres by cache size to get the column */

    parameter BL_NUM_BYTES = 4; /*Number of bytes in a block, aka number of columns */
    parameter CACHE_NUM_COL = 8; /*Number of rows in the cache */



    always@(*) begin

        if(activate) begin
            if(address_in % 2 != 0) begin
                $display("Address needs to be word aligned (divisible by 2) for now");
                $display("This most likely means to load a byte. If address 0x03, we should actually load word at 0x02. Then only return the upper 8 bits");
                $finish;
            end

            block_address = address_in / BL_NUM_BYTES;
            block_number = block_address % CACHE_NUM_COL;

            /* Let's assume a load */
            if(instr_type == READ) begin
                if(vld[block_number] == 1) begin
                    if(tag_number[block_number] == address_in[15:5]) begin
                        if(address_in % 4 == 0) begin
                            data_out = cache_data[block_number][15:0];
                        end 
                        else if(address_in % 2 == 2) begin
                            data_out = cache_data[block_number][31:16];
                        end
                    end
                end
            end

            /* Let's assume a store */
            else if(instr_type == WRITE) begin
                $display("Got a write instruction");
                if(vld[block_number] == 0) begin
                    vld[block_number] = 1;
                    cache_data[block_number] = '0;
                    tag_number[block_number] = address_in[15:6];
                end

                if(address_in % 4 == 0) begin
                    cache_data[block_number][15:0] = data_in;
                end

                else if(address_in % 2 == 0) begin
                    cache_data[block_number][31:16] = data_in;
                end
            end
            
            $display("Block number is %d", block_number);
            $display("Data at cache_data[block_number] is %h", cache_data[block_number]);
            
            $finish;


        end
end
endmodule

module simple_ram
  #(parameter D_WIDTH     = 16,
    parameter WIDTH_AD   = 8
    )
   (
    input clk, 
    input [WIDTH_AD] address_in,
    input [D_WIDTH] data_in,
    output reg [D_WIDTH] data_out,
    input wren
    );

reg [D_WIDTH-1:0] mem [0:(2**WIDTH_AD)-1];

always @(posedge clk) begin
    if(wren) mem[address_in] <= data_in;
    
    data_out <= mem[address_in];
end

endmodule
