`default_nettype none
typedef enum {READ, WRITE} INSTR_TYPE;

module tb();
    reg[15:0] instructions [0:31];
    initial begin
    $readmemb("instructions3.mem", instructions); 
    end
    
    reg clk = 0;
    reg [15:0] address = 16'h0004;
    reg [15:0] data = 16'h0100;
    reg [15:0] data_f_dut;
    reg activate = 0;
    //wire wren = 0; /* If high, memory should write cache block */ 
    
    wire load_ready_f_mem;
    

    wire[31:0] block_f_cache;
    wire mem_load_req_f_cache;
    wire mem_store_req_f_cache;
    wire mem_load_req_rdy;
    wire mem_load_toggle;       /* This toggles back and forward when loading a cache block */
    wire mem_store_completed;   /*Memory confirming it has stored cache block */
    wire mem_store_ack;         /*Cache confirming it has ack the cache block write */
    wire [31:0] mem_data;       /*Cache block from memory*/

    wire [15:0] address_f_cache;

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
        .instr_type (instr_type),

        .data_to_mem(block_f_cache),
        .mem_load_req(mem_load_req_f_cache),
        .mem_store_req(mem_store_req_f_cache),
        .mem_load_req_rdy(mem_load_req_rdy),
        .mem_store_processed(mem_store_completed),
        .mem_store_ack(mem_store_ack),
        .mem_load_toggle(mem_load_toggle),
        .address_to_mem(address_f_cache)
        );

    RAM simple_ram (
        .clk(clk),
        .address_in(address_f_cache),
        .data_in(block_f_cache),
        .data_out(mem_data),
        .wren(mem_store_req_f_cache),
        .load_completed(mem_load_req_rdy),
        .store_completed(mem_store_completed),
        .store_ack (mem_store_ack),
        .mem_load_req (mem_load_req_f_cache),
        .load_toggle (mem_load_toggle)
    );

    
    initial begin
        #5;
        activate = 1;
        #100
        address = 16'h0008;
        data = 16'hDEAD;
        #200;
        $finish;
    end
    
    
endmodule

module cache_controller(
    input clk
); 

endmodule

module cache #(parameter CACHE_NUM_ROW = 8 /*Number of rows in the cache */
    //parameter WIDTH_AD   = 8
    )
    (
  
    input[15:0] address_in,
    input [15:0] data_in,
    output reg[15:0] data_out,
    input activate,
    input INSTR_TYPE instr_type,   // 0 = read, 1 = write

    output reg [31:0] data_to_mem,  /*The data(cache block) that should be saved from the cache to memory */
    input [31:0] data_f_mem,        /*The data from memory that will go in a cache block*/
    output reg mem_load_req,        /*If high, need to load data from memory into cache*/
    output reg mem_store_req,       /*If high, need to save cache block to memory */
    output reg mem_store_ack,       /*If high, then the memory has succesfully stored */
    input mem_store_processed,      /*If high, memory has stored 4 bytse from the cache block.*/
    input mem_load_req_rdy,         /*If high, the data loaded from memory is ready */
    input mem_load_toggle,          /* This is not used, this would be if we needed to 'burst' the ram, aka if we needed multiple clock cycles to fill the cache block*/
    output reg [15:0] address_to_mem /*Address to memory, used when requesting data to load/store*/
    
); 
    reg vld [0:7];                  /* 1 bit for each row  */
    reg [31:0] cache_data [0:7];    /* If you load address 0x02, get the data for 0x00 as well in the cache. If you grab 0x00, also get 0x02 */
    reg [10:0] tag_number [0:7];    /* We have a tag number for each cache line */
    reg [15:0] block_address;       /* We will divide address by cache size to get block address */ 
    reg [15:0] block_num;           /* We will modulo the block addres by cache size to get the column */
    reg [7:0] to_evict;             /* If any of the bits are set, the cache block should be written to memory and freed from the cache */

    parameter BL_NUM_BYTES = 4; /*Number of bytes in a block, aka number of columns */
    reg read_success = 0;   

    task send_to_mem (input int i);
        begin
           data_to_mem = cache_data[i];
           $display("Cache data[%d] is %h", i, cache_data[i]);
           mem_store_req = 1;
           address_to_mem = address_in;
           $display("%0t", $time);
           wait(mem_store_processed == 1) begin /* We will wait until memory has completed the store */
               $display("Memory store has been processed - from cache");
               $display("%0t", $time);
               mem_store_ack = 1;   /* We tell the memory that we ack the store, so now it can turn off its write enable*/ 
               mem_store_req = 0;   /* We do not have a request anymore */
               wait(mem_store_processed == 0) begin /* We will wait until the memory is able to store new data*/
                   mem_store_ack = 0;   /* We are done acknowledging that the memory has stored the cache block */
                   $display("Memory store has fully completed - from cache");
                   $display("%0t", $time);
               end
           end
        end
    endtask

    always@(*) begin

        if(activate) begin
            if(address_in % 2 != 0) begin
                $display("Address needs to be word aligned (divisible by 2) for now");
                $display("This most likely means to load a byte. If address 0x03, we should actually load word at 0x02. Then only return the upper 8 bits");
                $finish;
            end

            block_address = address_in / BL_NUM_BYTES; /* divide by number of columns to find the row # */
            block_num = block_address % CACHE_NUM_ROW; /* modulo to get the physical row number */ 
            $display("block_address is %d", block_address );
            $display("block_num is %d", block_num);

            /* Let's assume a load */
            if(instr_type == READ) begin
                if(vld[block_num] == 1) begin
                    if(tag_number[block_num] == address_in[15:5]) begin
                        read_success = 1;
                        if(address_in % 4 == 0) begin
                            data_out = cache_data[block_num][15:0];
                        end 
                        else if(address_in % 2 == 2) begin
                            data_out = cache_data[block_num][31:16];
                        end
                    end
                end
                if(read_success == 0) begin
                    /* We want to read the whole cache line from memory, since the memory has a 32 bit output, this is easy */
                    mem_load_req = 1;
                    wait (mem_load_req_rdy == 1) begin
                        cache_data[block_num] = data_f_mem;
                    end 
                    vld[block_num] = 1;
                    tag_number[block_num] = address_in[15:5];
                    
                end
            end

            /* Let's assume a store */
            else if(instr_type == WRITE) begin
                $display("Got a write instruction");
                if(vld[block_num] == 0) begin
                    vld[block_num] = 1;
                    cache_data[block_num] = '0;
                    tag_number[block_num] = address_in[15:5];
                end

                else if (vld[block_num == 1]) begin
                    /* If data is already present in this cache line, and we are writing to it
                       We should evict the current data first */
                       send_to_mem(block_num);
                end

                if(address_in % 4 == 0) begin
                    cache_data[block_num][15:0] = data_in;
                end

                else if(address_in % 2 == 0) begin
                    cache_data[block_num][31:16] = data_in;
                end
            end

            /* Let's write a cache block to memory */
            to_evict[block_num] = 1;
            
            for(int i = 0; i < CACHE_NUM_ROW; i++ ) begin
                if(to_evict[i] == 1) begin
                    send_to_mem(i);
                end
            end

            to_evict[block_num] = 0;    

            read_success = 0;
            $display("Block number is %d", block_num);
            $display("Data at cache_data[block_num] is %h", cache_data[block_num]);

        end
end
endmodule

module RAM
  #(parameter D_WIDTH     = 32,
    parameter WIDTH_AD   = 16
    )
   (
    input clk, 
    input [WIDTH_AD-1:0] address_in,
    input [D_WIDTH-1:0] data_in,
    output reg [D_WIDTH-1:0] data_out,
    input wren,
    output reg load_completed,
    output reg store_completed,
    input store_ack,
    input mem_load_req,
    output reg load_toggle
    );

reg [D_WIDTH-1:0] mem [0:(2**WIDTH_AD)-1];

always @(posedge clk) begin
    if(store_ack) begin
        mem[address_in] <= data_in;
        store_completed <= 0;   /*We need to tell the cache to continue */
    end
    else if(wren) begin 
        mem[address_in] <= data_in;
        store_completed <= 1;
    end

    if(mem_load_req) begin      /* If the cache requests a cache block sized data*/
        load_completed <= 1;
    end else begin
        load_completed <= 0;
    end
    
    if(wren) begin
        // $display("Write enable in memory is 1");
        // $display("Data in is %h", data_in);
        // $display("Data out is %h", data_out);
    end

    data_out <= mem[address_in];
end


endmodule
