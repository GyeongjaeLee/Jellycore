`include "constants.vh"
`default_nettype none
// recovery is not implemented yet
// this freelist can be used as both a physical register tag freelist and an issue queue freelist
module freelist #(
                parameter FREE_NUM = 64,
                parameter FREE_SEL = 6
                )   
        (
        input wire          clk,
        input wire          reset,
        input wire          invalid1,
        input wire          invalid2,
        input wire          prmiss,
        input wire [FREE_SEL-1:0]  released_1,
        input wire [FREE_SEL-1:0]  released_2,
        input wire                  releaesd_valid_1,
        input wire                  released_valid_2,
        input wire                  stall_DP,   // if back-end stalls
        output reg [FREE_SEL-1:0]   alloc_1,
        output reg [FREE_SEL-1:0]   alloc_2,
        output reg                  alloc_valid_1,
        output reg                  alloc_valid_2,
        output reg                  allocatable
        );

    // bit vectors indicates whether physcial register tag is free
    reg [FREE_NUM-1:0]     free_bits;
    reg [FREE_SEL:0]       freenum;
    reg                     alloc_prev;
    reg [1:0]               count;
    reg [FREE_SEL:0]       i;
    reg [1:0]               reqnum;
    reg [1:0]               relnum;
    reg [1:0]               allocnum;

    // No stall_DP -> allocate
    // stall_DP but alloc failed in previous cycle-> allocate
    // stall_DP and alloc succeeded in previous cycle -> keep prev allocation info
    always @ (*) begin
        reqnum = {1'b0, ~invalid1} + {1'b0, ~invalid2};
        relnum = {1'b0, releaesd_valid_1} + {1'b0, released_valid_2};
        allocatable = (freenum >= reqnum) ? 1'b1 : 1'b0;
        if (allocatable && (~stall_DP || (stall_DP && ~alloc_prev))) begin
            alloc_valid_1 = 0;
            alloc_valid_2 = 0;
            count = 0;
            for (i = 0; i < FREE_NUM && count < reqnum; i++) begin
                if (free_bits[i]) begin
                    if (count == 0 && ~invalid1) begin
                        alloc_1 = i;
                        alloc_valid_1 = 1;
                    end else begin
                        alloc_2 = i;
                        alloc_valid_2 = 1;
                    end
                    count = count + 1;
                end
            end
        end else begin
            alloc_1 = alloc_1;
            alloc_2 = alloc_2;
            alloc_valid_1 = alloc_valid_1;
            alloc_valid_2 = alloc_valid_2;
        end
        allocnum = (allocatable && (~stall_DP || (stall_DP && ~alloc_prev))) ? count : 2'b00;
    end

    always @ (negedge clk) begin
        if(reset) begin
            freenum <= FREE_NUM;
            free_bits <= {FREE_NUM{1'b1}};
            alloc_prev <= 1'b1;
        end else if (prmiss) begin
            // dealing with branch misprediction
        end else begin
            freenum <= freenum + relnum - allocnum;
            free_bits <= (free_bits
                         | ({FREE_NUM{releaesd_valid_1}} & (1'b1 << released_1))
                         | ({FREE_NUM{released_valid_2}} & (1'b1 << released_2))
                         & ~({FREE_NUM{alloc_valid_1}} & (1'b1 << alloc_1))
                         & ~({FREE_NUM{alloc_valid_2}} & (1'b1 << alloc_2)));
            alloc_prev <= allocatable;
        end
    end

endmodule