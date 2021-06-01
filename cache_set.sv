`default_nettype none

typedef enum {READ, WRITE} INSTR_TYPE;

module tb();
    reg[15:0] instructions [0:31];
    initial begin
    $readmemb("instructions3.mem", instructions); 
    end
    
    reg clk = 0;
    reg [15:0] address = 0;
    reg [15:0] data = 0;
    reg [15:0] data_f_dut;
    reg activate = 0;
    
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

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars();
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
        .mem_store_completed(mem_store_completed),
        .mem_store_ack(mem_store_ack),
        .mem_load_toggle(mem_load_toggle),
        .address_to_mem(address_f_cache),
        .data_f_mem(mem_data)
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
        activate = 0;

        #5;
        /*tag = 0, block_num = 1, offset = 0 */
        activate = 1;
        address = 16'h0004;
        data = 16'h0100;
        
        #50;
        /*tag = 0, block_num = 2, offset = 0 */
        address = 16'h0008;
        data = 16'hDEAD;

        #200;
        instr_type = READ;
        address = 16'h0028;
        data = 16'hBEEF;
        #300;
        $finish;
    end
    
endmodule

module cache_controller(
    input clk
); 

endmodule

module cache #(
    parameter CACHE_NUM_ROW = 8, /*Number of rows in the cache */
    parameter CACHE_NUM_SET = 4  /* Number of sets per row in the cache */

    //parameter WIDTH_AD   = 8
    )
    (
  
    input[15:0] address_in,
    input [15:0] data_in,
    output reg[15:0] data_out,
    input activate,
    input INSTR_TYPE instr_type,   // 0 = read, 1 = write

    output reg [31:0] data_to_mem,      /*The data(cache block) that should be saved from the cache to memory */
    input [31:0] data_f_mem,            /*The data from memory that will go in a cache block*/
    output reg mem_load_req,            /*If high, need to load data from memory into cache*/
    output reg mem_store_req,           /*If high, need to save cache block to memory */
    output reg mem_store_ack,           /*If high, then the memory has succesfully stored */
    input mem_store_completed,          /*If high, memory has stored 4 bytse from the cache block.*/
    input mem_load_req_rdy,             /*If high, the data loaded from memory is ready */
    input mem_load_toggle,              /* This is not used, this would be if we needed to 'burst' the ram, aka if we needed multiple clock cycles to fill the cache block*/
    output reg [15:0] address_to_mem    /*Address to memory, used when requesting data to load/store*/
    
); 
    //reg vld [0:7];                                /* 1 bit for each row  */
    reg vld_set [0:7] [4];                          /* 1 bit for each set  */
    reg [31:0] cache_data [0:7] [4];                 /* If you load address 0x02, get the data for 0x00 as well in the cache. If you grab 0x00, also get 0x02 */
    //reg [10:0] tag_number [0:7];                  /* We have a tag number for each cache line */
    reg [10:0] tag_number_set [0:7] [4];            /* We have a tag number for each set in the cache line */
    reg [15:0] block_address;                       /* We will divide address by cache size to get block address */ 
    reg [15:0] block_num;                           /* We will modulo the block addres by cache size to get the column */
    
    reg [7:0] to_evict;                             /* If any of the bits are set, the cache block should be written to memory and freed from the cache */

    parameter BL_NUM_BYTES = 4;                     /* Number of bytes in a block, aka number of columns */
    reg read_success = 0;                           /* If high, we have successfully read from memory */   
    reg [3:0] LRU [0:7][4];                         /* Used to keep track of the oldest column in the set. The oldest gets evicted*/

    task send_to_mem (
        input byte row, 
        input set_col 
        );
        begin
           data_to_mem = cache_data[row][set_col];
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
    output vld_bool,
    output set_num); 
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
        output space_found,
        output set_num
    );
    reg state = 0;
    begin
        for(int i = 0; i < CACHE_NUM_SET; i++) begin
            if(vld_set[row][i] == 0 && state == 0) begin
                space_found = 1;
                set_num = i;
                state = 1;
            end
        end 
        $display("find_space_in_set - space_found at col %d", set_num);
    end
    endtask

    /* This tasks finds the oldest value in the set in the cache. 
       This is used when there are no free columns in the set, we make room by ejecting the oldest value in the set */
    task automatic find_oldest_set_col(
        input byte row,
        output oldest_set_col
    );
    reg highest_index = 0;
    reg [3:0] highest_val;

    for(int i = 0; i < CACHE_NUM_SET; i++) begin
        if(highest_val < LRU[row][i]) begin
            highest_val = LRU[row][i];
            highest_index = i;
        end
    end
    endtask
    

    always@(activate, address_in, data_in, instr_type) begin
        
        if(!activate) begin
            /* If we are not activated, set the vld bits to 0 */
            for(int i = 0; i < 8; i++) begin
                for(int j = 0; j < 4; j++) begin
                    vld_set[i][j] = 0;
                end
            end
        end

        if(activate) begin
            $display("instr type is %d, time is: %0t", instr_type, $time);
            if(address_in % 2 != 0) begin
                $display("Address needs to be word aligned (divisible by 2) for now");
                $display("This most likely means to load a byte. If address 0x03, we should actually load word at 0x02. Then only return the upper 8 bits");
                $finish;
            end

            block_address = address_in / BL_NUM_BYTES; /* divide by number of columns to find the row, aka block address # */
            block_num = block_address % CACHE_NUM_ROW; /* modulo to get the physical row number (since the block address can be bigger than the block number ) */ 
            $display("block_address is %d", block_address );
            $display("block_num is %d", block_num);

            /* Let's assume a load */
            if(instr_type == READ) begin
                /* Use the two variables below to send to set_tag_match, to check if data is in cache already */
                static  reg set_match_stm = 0;
                static  reg set_num_stm = 0;

                /* Use the two variables below to send to find_space_in_set, used when data is not in cache, checks if there is space in the set to load from memory */
                static reg space_found_fsis = 0;
                static reg set_num_fsis = 0;

                $display("Got a read instruction");
                set_tag_match(block_num, address_in[15:5], set_match_stm, set_num_stm);
                if(set_match_stm) begin
                    $display("vld[block_num] passed");
                    read_success = 1;
                    if(address_in % 4 == 0) begin
                        data_out = cache_data[block_num][set_num_stm][15:0];
                    end 
                    else if(address_in % 4 == 2) begin
                        data_out = cache_data[block_num][set_num_stm][31:16];
                    end
                end

                if(read_success == 0) begin
                    $display("The tag did not match the address, going to memory");
                    /* We want to read the whole cache line from memory, since the memory has a 32 bit output, this is easy */
                    mem_load_req = 1;
                    address_to_mem = address_in;

                    find_space_in_set(block_num, space_found_fsis, set_num_fsis);
                    if(space_found_fsis) begin

                        wait (mem_load_req_rdy == 1) begin
                            cache_data[block_num][set_num_fsis] = data_f_mem;
                            $display("inside read, data_f_mem is %h", data_f_mem);
                        end 
                        
                        if(address_in % 4 == 0) begin
                            data_out = cache_data[block_num][set_num_fsis][15:0];
                        end 
                        else if(address_in % 4 == 2) begin
                            data_out = cache_data[block_num][set_num_fsis][31:16];
                        end

                        vld_set[block_num][set_num_fsis] = 1;
                        tag_number_set[block_num][set_num_fsis] = address_in[15:5];

                    end
                end
                $display("Read data from ram, data_out from cache is %h", data_out);
            end

            /* Let's assume a store */
            else if(instr_type == WRITE) begin
                static reg space_found_st = 0;
                static reg set_num_st = 0;

                $display("Got a write instruction");

                find_space_in_set(block_num, space_found_st, set_num_st);
                if(space_found_st) begin
                    vld_set[block_num][set_num_st] = 1;
                    cache_data[block_num][set_num_st] = '0;
                    tag_number_set[block_num][set_num_st] = address_in[15:5];
                end 

                else if(space_found_st == 0) begin
                    /* If data is already present in this cache line, and we are writing to it and there is no free space in the set
                       We should evict the current set data first */
                       $display("block is already valid, sending old cache line to memory");
                       find_oldest_set_col(block_num, set_num_st);
                       send_to_mem(block_num, set_num_st); 
                       //send_to_mem(block_num);
                end

                if(address_in % 4 == 0) begin
                    cache_data[block_num][set_num_st][15:0] = data_in;
                end

                else if(address_in % 4 == 2) begin
                    cache_data[block_num][set_num_st][31:16] = data_in;
                end
            end

            // /* Let's write a cache block to memory */
            // to_evict[block_num] = 1;
            
            // for(int i = 0; i < CACHE_NUM_ROW; i++ ) begin
            //     if(to_evict[i] == 1) begin
            //         send_to_mem(i);
            //     end
            // end

            // to_evict[block_num] = 0;    
            $display("--------------");
            read_success = 0;
            // $display("Block number is %d", block_num);
            // $display("Data at cache_data[block_num] is %h", cache_data[block_num]);

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
    // if(store_ack) begin
    //     mem[address_in] <= data_in;
    //     store_completed <= 0;   /*We need to tell the cache to continue */
    // end
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
    
    if(wren) begin
        // $display("Write enable in memory is 1");
        // $display("Data in is %h", data_in);
        // $display("Data out is %h", data_out);
    end

    data_out <= mem[address_in];
end


endmodule
