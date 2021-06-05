/* 
This contains a 4 way set associative cache

Defaults:
Cache Block  = 32 bits
Address      = 16 bits
Memory data  = 32 bits
Cache Output = 16 bits

Address layout (MSB):
Tag         = 11 bits
Block       = 3 bits
Offset      = 2 bits
----------------------------------
Example breakdown 1:

Address = 0x0068
0000 0000 1010 1000

15                                     0
| 0000 0000 100 |   010   |     00     |
       Tag         Block      Offset
----------------------------------

*/
`default_nettype none

typedef enum {READ, WRITE} INSTR_TYPE;

module tb();
    reg clk = 0;
    reg rst_n = 0;
    reg [15:0] address = 0;
    reg [15:0] data = 0;
    reg [15:0] data_f_dut;
    reg activate = 0;
    
    wire[31:0] block_f_cache;
    wire cache_output_rdy;
    wire mem_load_req_f_cache;
    wire mem_store_req_f_cache;
    wire mem_load_req_rdy;
    wire mem_store_completed;   /* Memory confirming it has stored cache block */
    wire mem_store_ack;         /* Cache confirming it has ack the cache block write */
    wire [31:0] mem_data;       /* Cache block from memory*/

    wire [15:0] address_f_cache;

    INSTR_TYPE instr_type;

    initial begin
        instr_type = WRITE;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars();
    end

    always #5 clk = ~clk;

    cache dut (
        .clk(clk),
        .rst_n(rst_n),
        .address_in(address),
        .data_in(data), 
        .data_out(data_f_dut), 
        .instr_type (instr_type),

        .data_to_mem(block_f_cache),
        .mem_load_req(mem_load_req_f_cache),
        .mem_store_req(mem_store_req_f_cache),
        .mem_load_req_rdy(mem_load_req_rdy),
        .mem_store_completed(mem_store_completed),
        .mem_store_ack(mem_store_ack),
        .address_to_mem(address_f_cache),
        .data_f_mem(mem_data),
        .cache_output_rdy(cache_output_rdy)
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
        .mem_load_req (mem_load_req_f_cache)
    );

    initial begin
        rst_n = 0;        
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end


        /*tag = 0, block_num = 1, offset = 0 */
        rst_n = 1;
        instr_type = WRITE;
        address = 16'h0004;
        data = 16'h0100;
        @(posedge clk);
        $display("cache output status is %d", cache_output_rdy);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end
        

        /*tag = 0, block_num = 2, offset = 0 */
        instr_type = WRITE;
        address = 16'h0008;
        data = 16'hDEAD;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end
        
        
        /*tag = 1, block_num = 2, offset = 0*/
        instr_type = READ;
        address = 16'h0028;
        data = 16'hBEEF;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end
        

        /* tag = 3, block_num = 2, offset = 0 */
        instr_type = WRITE;
        address = 16'h0068;
        data = 16'hf01d;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end
        
        /* tag = 4, block_num = 2, offset = 0 */
        instr_type = WRITE;
        address = 16'h0088;
        data = 16'hf01d;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end
        

        /* tag = 5, block_num = 2, offset = 0 */
        /* At this point, there should be an eviction to main memory */
        instr_type = WRITE;
        address = 16'h00A8;
        data = 16'hca11;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end
        

        /* tag = 5, block_num = 2, offset = 0 */
        /* Verify the data above has replaced the oldest data in the cache data (hDEAD at cache set 0) */
        instr_type = READ;
        address = 16'h00A8;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end

        /* tag = 7, block_num = 6, offset = 0 */
        instr_type = WRITE;
        address = 16'h00F8;
        data = 16'hba1d;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end

        /* tag = 7, block_num = 6, offset = 0 */
        /* Read the above write */
        $display("cache output status is %d", cache_output_rdy);
        instr_type = READ;
        address = 16'h00F8;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end

        /* tag = 7, block_num = 6, offset = 2 */
        /* Write to the 2nd half of the cache block as the address above */
        instr_type = WRITE;
        address = 16'h00FA;
        data = 16'hfe11;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end

        /* tag = 7, block_num = 6, offset = 2 */
        /* Read back 2nd half of the cache block */
        instr_type = READ;
        address = 16'h00FA;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end

        /* tag = 7, block_num = 6, offset = 2 */
        /* Read back 1st half of the cache block */
        instr_type = READ;
        address = 16'h00F8;
        @(posedge clk);
        while(cache_output_rdy == 0) begin
            @(posedge clk);
        end


        
        #300;
        $finish;
    end
    
endmodule

module cache_controller(
    input clk
); 

endmodule

module cache #(
    parameter CACHE_NUM_ROW = 8,                        /* Number of rows in the cache */
    parameter CACHE_NUM_SET = 4,                        /* Number of sets per row in the cache */
    parameter LRU_BPS = 4,                              /* LRU Bits per set, How many bits allocated for the staleness of each set in the LRU */
    parameter LRU_BPS_SQRD = LRU_BPS * LRU_BPS - 1     /* Max value of 4 bits */
    
    )
    (
    
    /* To avoid the code becoming harder to read, the bit declaration sizes here are not replaced with `defines or params */
    input clk, rst_n,
    input[15:0] address_in,
    input [15:0] data_in,
    output reg[15:0] data_out,
    //input activate,
    input INSTR_TYPE instr_type,   // 0 = read, 1 = write

    output reg [31:0] data_to_mem,      /* The data(cache block) that should be saved from the cache to memory */
    input [31:0] data_f_mem,            /* The data from memory that will go in a cache block*/
    output reg mem_load_req,            /* If high, need to load data from memory into cache*/
    output reg mem_store_req,           /* If high, need to save cache block to memory */
    output reg mem_store_ack,           /* If high, then the memory has succesfully stored */
    input mem_store_completed,          /* If high, memory has stored 4 bytes from the cache block.*/
    input mem_load_req_rdy,             /* If high, the data loaded from memory is ready */
    output reg [15:0] address_to_mem,   /* Address to memory, used when requesting data to load/store*/
    output reg cache_output_rdy = 0        /* High when the cache is ready, tb/other modules can read now */
); 
    reg vld_set [0:7] [4];                          /* 1 bit for each set  */
    reg [31:0] cache_data [0:7] [4];                /* If you load address 0x02, get the data for 0x00 as well in the cache. If you grab 0x00, also get 0x02 */
    reg [10:0] tag_number_set [0:7] [4];            /* We have a tag number for each set in the cache block */
    reg [15:0] block_address;                       /* We will divide address by cache size to get block address */ 
    reg [15:0] block_num;                           /* We will modulo the block addres by cache size to get the column */
    reg [1:0] offset;                               /* The last two bits are the byte offset */

    parameter BL_NUM_BYTES = 4;                     /* Number of bytes in a block, aka number of columns */
    reg read_success = 0;                           /* If high, we have successfully read from memory */   
    reg [3:0] LRU [0:7][4];                         /* Used to keep track of the oldest column in the set. The oldest gets evicted*/

    reg output_ready = 0;                           /* Used by the main cache block to signal the output is ready
                                                        Then an always @(posedge clk) block uses this to synchronize the cache to a clock */
    reg activate = 0;                               /* If reset, this is set to 0 */

    task send_to_mem (
        input byte row, 
        input reg [1:0]set_col 
        );
        begin
           data_to_mem = cache_data[row][set_col];
           $display("Send to mem, set column is %d", set_col);
           $display("Send to mem, data[%d][%d] is %h", row, set_col , cache_data[row][set_col]);
           mem_store_req = 1;
           address_to_mem = address_in;
           $display("%0t", $time);
           wait(mem_store_completed == 1) begin /* We will wait until memory has completed the store */
               $display("Memory store has been processed - from cache");
               $display("%0t", $time);
               //mem_store_ack = 1;   /* We tell the memory that we ack the store, so now it can turn off its write enable*/ 
               mem_store_req = 0;   /* We do not have a request anymore */
               wait(mem_store_completed == 0) begin /* We will wait until the memory is able to store new data*/
                   //mem_store_ack = 0;   /* We are done acknowledging that the memory has stored the cache block */
                   $display("Memory store has fully completed - from cache");
                   $display("%0t", $time);
               end
           end
        end
    endtask

    /* This task checks if any of the sets columns in the block_num are vld and the tag matches 
        Used to check if our data is already in the cache */
    task automatic set_tag_match(
    input byte row,
    input [10:0] tag,
    output reg vld_bool,
    output reg [1:0] set_num); 
    reg state = 0;
        begin
            for(int i = 0; i < CACHE_NUM_SET; i++) begin
                if(
                    vld_set[block_num][i] == 1 && 
                    tag_number_set[row][i] == tag && 
                    state == 0
                ) 
                begin
                    vld_bool = 1;
                    set_num = i;
                    state = 1;
                end
            end
        end
    endtask

    /* This task finds an empty column in the set 
       Used to find if there is an empty column when writing, (if there isn't we call find_oldest_set_col instead, but not here) */
    task automatic find_space_in_set(
        input byte row,
        input reg [10:0] tag,
        output reg space_found,
        output reg[1:0] set_num
    );

    reg state = 0;
    begin
        space_found = 0;
        for(int i = 0; i < CACHE_NUM_SET; i++) begin
            /* Check if the cache column is invalid, aka it is available
               OR if it is valid AND the tag is the same as what was already in there, should write there */
            if(
                ((vld_set[row][i] == 0) && (state == 0)) || 
                ((vld_set[row][i] == 1) && (tag == tag_number_set[row][i]) && (state == 0))
            ) 
                begin
                    space_found = 1;
                    set_num = i;
                    state = 1;
                    $display("find_space_in_set - space at vld_set[%d][%d]", row, i);
                end
        end 
        if(space_found)
        $display("find_space_in_set - space_found at col %d, block_num is %d", set_num, row);
    end
    endtask

    /* This tasks finds the oldest value in the set in the cache. 
       This is used when there are no free columns in the set, we make room by ejecting the oldest value in the set */
    task automatic find_oldest_set_col(
        input byte row,
        output reg [1:0] oldest_set_col
    );
    reg [1:0] highest_index = 0;
    reg [3:0] highest_val;

    begin
        /* Set index to 0 initially, then start the loop at 1 to find the largest LRU value */
        highest_val = LRU[row][0];
        highest_index = 0;
        for(int i = 1; i < CACHE_NUM_SET; i++) begin
            if(highest_val < LRU[row][i]) begin
                highest_val = LRU[row][i];
                highest_index = i;
            end
        end
        oldest_set_col = highest_index;
    end
    endtask

    /* This task adds 1 to every entry in the LRU unless it is already at the max value(15 for now)
       It will then make the set being accessed have its value changed to 0  */
    task automatic update_lru(
        input byte row,
        input reg [1:0] set_num
    );
        /*  Increase the staleness value by 1 for each entry in the LRU 
            Not checking if it is VLD, it is probably faster to just add blindly */
        for(int i = 0; i < CACHE_NUM_ROW; i++) begin
            for(int j = 0; j < CACHE_NUM_SET; j++) begin
                if(LRU[i][j] != LRU_BPS_SQRD ) begin
                    LRU[i][j] = LRU[i][j] + 1;
                end
            end
        end
        /* Reset the staleness value for the value that was just accssed */
        LRU[row][set_num] = 0;
    endtask
    
    /* This block is used to synchronize the cache to a clock 
       cache_output_rdy is signaled to the outside world, output_ready is from internal combinational logic*/
    always @(posedge clk, negedge rst_n) begin
        if(rst_n == 0) begin
            activate <= 0;
            for(int  i = 0; i < 8; i=i+1) begin
                for(int j = 0; j < 4; j=j+1) begin
                    vld_set[i][j] <= 0;
                end
            end
            cache_output_rdy <= 1;

        end else if(rst_n) begin
            activate <= 1;
            if(output_ready) begin
                cache_output_rdy <= 1;
            end else begin
                cache_output_rdy <= 0;
            end

        end
    end

    /* Limited trigger list, want to avoid this getting called unnecessarily. Hopefully nothing bad happens! */
    always@(activate, address_in, data_in, instr_type) begin
        output_ready = 0;

        if(activate) begin
            
            $display("instr type is %d, time is: %0t", instr_type, $time);
            if(address_in % 2 != 0) begin
                $display("Address needs to be word aligned (divisible by 2) for now");
                $display("This most likely means to load a byte. If address 0x03, we should actually load word at 0x02. Then only return the upper 8 bits");
                $finish;
            end

            block_address = address_in / BL_NUM_BYTES; /* divide by number of columns to find the row, aka block address # */
            block_num = block_address % CACHE_NUM_ROW; /* modulo to get the physical row number (since the block address can be bigger than the block number ) */ 
            offset = address_in[1:0];
            $display("block_address is %d", block_address );
            $display("block_num is %d", block_num);
            $display("tag is %d", address_in[15:5]);
            $display("offset is %d", address_in [1:0]);

            /* Let's assume a load */
            if(instr_type == READ) begin
                /* Use the two variables below to send to set_tag_match, to check if data is in cache already */
                static  reg set_match_stm = 0;
                static  reg [1:0] set_num_stm = 0;

                /* Use the two variables below to send to find_space_in_set, used when data is not in cache, checks if there is space in the set to load from memory */
                static reg space_found_fsis = 0;
                static reg [1:0] set_num_fsis = 0;

                $display("Got a read instruction");
                set_tag_match(block_num, address_in[15:5], set_match_stm, set_num_stm);
                if(set_match_stm) begin
                    $display("vld[block_num] passed");
                    read_success = 1;
                    if(offset == 0) begin
                        data_out = cache_data[block_num][set_num_stm][15:0];
                    end 
                    else if(offset == 2) begin
                        data_out = cache_data[block_num][set_num_stm][31:16];
                    end
                    /* Increase the staleness for every value in the LRU and reset the one just accessed */
                    update_lru(block_num, set_num_stm);
                end

                if(read_success == 0) begin
                    $display("The tag did not match the address, going to memory");
                    /* We want to read the whole cache line from memory, since the memory has a 32 bit output, this is easy */
                    mem_load_req = 1;
                    address_to_mem = address_in;

                    find_space_in_set(block_num, address_in[15:5], space_found_fsis, set_num_fsis);
                    if(space_found_fsis) begin

                        wait (mem_load_req_rdy == 1) begin
                            cache_data[block_num][set_num_fsis] = data_f_mem;
                            $display("inside read, data_f_mem is %h", data_f_mem);
                        end 
                        
                        if(offset == 0) begin
                            data_out = cache_data[block_num][set_num_fsis][15:0];
                        end 
                        else if(offset == 2) begin
                            data_out = cache_data[block_num][set_num_fsis][31:16];
                        end

                        vld_set[block_num][set_num_fsis] = 1;
                        tag_number_set[block_num][set_num_fsis] = address_in[15:5];
                        /* Increase the staleness for every value in the LRU and reset the one just accessed */
                        update_lru(block_num, set_num_fsis);
                    end
                end
                $display("Read data from cache, data_out from cache is %h", data_out);
            end

            /* Let's assume a store */
            else if(instr_type == WRITE) begin
                static reg space_found_st = 0;
                static reg [1:0] set_num_st = 0;

                $display("Got a write instruction, data to write is %h", data_in);
                
                find_space_in_set(block_num, address_in[15:5], space_found_st, set_num_st);
                if(space_found_st) begin
                    vld_set[block_num][set_num_st] = 1;
                    $display("vld_set[%d][%d] is %d", block_num, set_num_st, vld_set[block_num][set_num_st]);
                end 

                else if(space_found_st == 0) begin
                    /* If the cache block is full, and we are writing to it and there is no free space in the set
                    We should evict the oldest column in the set */
                    $display("cache block is full, sending old set column to memory");
                    find_oldest_set_col(block_num, set_num_st);
                    send_to_mem(block_num, set_num_st); 
                end

                if(offset == 0) begin
                    cache_data[block_num][set_num_st][15:0] = data_in;
                end

                else if(offset == 2) begin
                    cache_data[block_num][set_num_st][31:16] = data_in;
                end

                tag_number_set[block_num][set_num_st] = address_in[15:5];

                /* Increase the staleness for every value in the LRU and reset the one just accessed */
                update_lru(block_num, set_num_st);
            end
            
            read_success = 0;
            output_ready = 1;
            $display("--------------");
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

/* This is just for simulation, put a number in each memory location */
initial begin
    for(int i = 0; i < (2**WIDTH_AD); i++) begin
        mem[i] = i;
    end
end

always @(posedge clk) begin

    if(wren) begin 
        mem[address_in] <= data_in;
        store_completed <= 1;
    end else begin
        store_completed <= 0;
    end

    if(mem_load_req) begin      /* If the cache requests a cache block sized data*/
        load_completed <= 1;
    end else begin
        load_completed <= 0;
    end

    data_out <= mem[address_in];
end


endmodule
