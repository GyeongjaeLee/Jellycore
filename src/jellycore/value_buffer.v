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
    input wire                      invalid1,
    input wire                      invalid2,
    input wire [BUFFER_SEL-1:0]     ptr_1,
    input wire [BUFFER_SEL-1:0]     ptr_2,
    input wire [DATA_DEPTH-1:0]     value_1,
    input wire [DATA_DEPTH-1:0]     value_2,
    input wire                      prmiss,
    // issue (read)
    input wire                      issued_1,
    input wire                      issued_2,
    input wire [BUFFER_SEL-1:0]     issue_ptr_1,
    input wire [BUFFER_SEL-1:0]     issue_ptr_2,
    output reg [DATA_DEPTH-1:0]     issue_value_1,
    output reg [DATA_DEPTH-1:0]     issue_value_2
    );

    reg                             valid           [BUFFER_SEL-1:0];
    reg [DATA_DEPTH-1:0]            value_buffer    [BUFFER_SEL-1:0];
    
    reg [BUFFER_SEL:0]              i;

    wire                            reallocated_1;
    wire                            reallocated_2;
    
    // allow issued entries to be allocated in the very next cycle.
    assign reallocated_1 = (~invalid1 && (issue_ptr_1 == ptr_1))
                        || (~invalid2 && (issue_ptr_1 == ptr_2));
    assign reallocated_2 = (~invalid1 && (issue_ptr_2 == ptr_1))
                        || (~invalid2 && (issue_ptr_2 == ptr_2));


    // store immediate or PC value in dispatch stage
    // invalidate issued entry when immediate or PC-relative instruction is selected
    always @ (posedge clk) begin
        if (reset) begin
            for (i = 0; i < BUFFER_SEL; i++) begin
                valid[i] <= 0;
            end
        end else if (prmiss) begin
            // branch miss prediction flush
        end else begin
            if (~invalid1) begin
                valid[ptr_1] <= 1;
                value_buffer[ptr_1] <= value_1;
            end
            if (~invalid2) begin
                valid[ptr_2] <= 1;
                value_buffer[ptr_2] <= value_2;
            end
            if (issued_1 && ~reallocated_1) begin
                valid[issue_ptr_1] <= 0;
            end
            if (issued_2 && ~reallocated_2) begin
                valid[issue_ptr_2] <= 0;
            end
        end
    end

    // read value when corresponding instruction is selected
    always @ (negedge clk) begin
        issue_value_1 <= value_buffer[issue_ptr_1];
        issue_value_2 <= value_buffer[issue_ptr_2];
    end

endmodule