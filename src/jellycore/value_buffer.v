`include "constants.vh"
`default_nettype none
// recovery is not implemented yet
module value_buffer #(
        parameter BUFFER_NUM = 32,
        parameter BUFFER_SEL = 5,
        parameter DATA_DEPTH = 32
        )
    (
    input wire                      clk,
    input wire                      reset,
    // dispatch (write)
    input wire                      valid_1,
    input wire                      valid_2,
    input wire [BUFFER_SEL-1:0]     ptr_1,
    input wire [BUFFER_SEL-1:0]     ptr_2,
    input wire [DATA_DEPTH-1:0]     value_1,
    input wire [DATA_DEPTH-1:0]     value_2,
    input wire                      stall,
    // issue (read)
    input wire [BUFFER_SEL-1:0]     sel_ptr_1,
    input wire [BUFFER_SEL-1:0]     sel_ptr_2,
    input wire [BUFFER_SEL-1:0]     sel_ptr_3,
    output reg [DATA_DEPTH-1:0]     sel_value_1,
    output reg [DATA_DEPTH-1:0]     sel_value_2,
    output reg [DATA_DEPTH-1:0]     sel_value_3
    );

    reg [DATA_DEPTH-1:0]            value_buffer    [BUFFER_NUM-1:0];
    reg [BUFFER_SEL:0]              i;

    // store immediate or PC value in dispatch stage
    always @ (posedge clk) begin
        if (~stall) begin
            if (valid_1) begin
                value_buffer[ptr_1] <= value_1;
            end
            if (valid_2) begin
                value_buffer[ptr_2] <= value_2;
            end
        end
    end

    // read value when corresponding instruction is selected
    always @ (negedge clk) begin
        sel_value_1 <= value_buffer[sel_ptr_1];
        sel_value_2 <= value_buffer[sel_ptr_2];
        sel_value_3 <= value_buffer[sel_ptr_3];
    end

endmodule