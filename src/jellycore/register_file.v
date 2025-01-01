`include "constants.vh"
`default_nettype  none
module register_file #(
        parameter BRAM_ADDR_WIDTH = `ADDR_LEN,
        parameter BRAM_DATA_WIDTH = `DATA_LEN,
        parameter DATA_DEPTH      =  64
        )
    (
    input wire              clk,
    input wire [BRAM_ADDR_WIDTH-1:0]    raddr1,
    input wire [BRAM_ADDR_WIDTH-1:0]    raddr2,
    input wire [BRAM_ADDR_WIDTH-1:0]    raddr3,
    input wire [BRAM_ADDR_WIDTH-1:0]    raddr4,
    input wire [BRAM_ADDR_WIDTH-1:0]    raddr5,
    input wire [BRAM_ADDR_WIDTH-1:0]    raddr6,
    output reg [BRAM_DATA_WIDTH-1:0]    rdata1,
    output reg [BRAM_DATA_WIDTH-1:0]    rdata2,
    output reg [BRAM_DATA_WIDTH-1:0]    rdata3,
    output reg [BRAM_DATA_WIDTH-1:0]    rdata4,
    output reg [BRAM_DATA_WIDTH-1:0]    rdata5,
    output reg [BRAM_DATA_WIDTH-1:0]    rdata6,
    input wire [BRAM_ADDR_WIDTH-1:0]    waddr1,
    input wire [BRAM_ADDR_WIDTH-1:0]    waddr2,
    input wire [BRAM_ADDR_WIDTH-1:0]    waddr3,
    input wire [BRAM_DATA_WIDTH-1:0]    wdata1,
    input wire [BRAM_DATA_WIDTH-1:0]    wdata2,
    input wire [BRAM_DATA_WIDTH-1:0]    wdata3,
    input wire              we1,
    input wire              we2,
    input wire              we3
    );

    reg [BRAM_DATA_WIDTH-1:0]           mem [0:DATA_DEPTH-1];

    // synchronized RAM (6r3w)
    // write at posedge and read at negedge to address with structural hazard
    always @ (posedge clk) begin
        if (we1)
            mem[waddr1] <= wdata1;
        if (we2)
            mem[waddr2] <= wdata2;
        if (we3)
            mem[waddr3] <= wdata3;
    end

    always @ (negedge clk) begin
        rdata1 <= mem[raddr1];
        rdata2 <= mem[raddr2];
        rdata3 <= mem[raddr3];
        rdata4 <= mem[raddr4];
        rdata5 <= mem[raddr5];
        rdata6 <= mem[raddr6];
    end
endmodule