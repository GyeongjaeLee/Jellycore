`include "constants.vh"
`default_nettype none
// recovery is not implemented yet
module immediate_buffer(
    input wire                      clk,
    input wire                      reset,
    // dispatch (write)
    input wire                      invalid1,
    input wire                      invalid2,
    input wire [`IB_ENT_SEL-1:0]    imm_ptr_1,
    input wire [`IB_ENT_SEL-1:0]    imm_ptr_2,
    input wire [`DATA_LEN-1:0]      imm_value_1,
    input wire [`DATA_LEN-1:0]      imm_value_2,
    input wire                      prmiss,
    // issue (read)
    input wire                      issued_1,
    input wire                      issued_2,
    input wire [`IB_ENT_SEL-1:0]    issue_imm_ptr_1,
    input wire [`IB_ENT_SEL-1:0]    issue_imm_ptr_2,
    output reg [`DATA_LEN-1:0]      issue_imm_value_1,
    output reg [`DATA_LEN-1:0]      issue_imm_value_2
    );

    reg                             valid       [`IB_ENT_NUM-1:0];
    reg [`DATA_LEN-1:0]             imm_buffer  [`IB_ENT_NUM-1:0];
    
    reg [`IB_ENT_SEL:0]             i;

    wire                            reallocated_1;
    wire                            reallocated_2;
    
    // allow issued entries to be allocated in the very next cycle.
    assign reallocated_1 = (~invalid1 && (issue_imm_ptr_1 == imm_ptr_1))
                        || (~invalid2 && (issue_imm_ptr_1 == imm_ptr_2));
    assign reallocated_2 = (~invalid1 && (issue_imm_ptr_2 == imm_ptr_1))
                        || (~invalid2 && (issue_imm_ptr_2 == imm_ptr_2));


    // store immediate value in dispatch stage
    // invalidate issued entry when immediate instruction is selected
    always @ (posedge clk) begin
        if (reset) begin
            for (i = 0; i < `IB_ENT_NUM; i++) begin
                valid[i] <= 0;
            end
        end else if (prmiss) begin
            // branch miss prediction flush
        end else begin
            if (~invalid1) begin
                valid[imm_ptr_1] <= 1;
                imm_buffer[imm_ptr_1] <= imm_value_1;
            end
            if (~invalid2) begin
                valid[imm_ptr_2] <= 1;
                imm_buffer[imm_ptr_2] <= imm_value_2;
            end
            if (issued_1 && ~reallocated_1) begin
                valid[issue_imm_ptr_1] <= 0;
            end
            if (issued_2 && ~reallocated_2) begin
                valid[issue_imm_ptr_2] <= 0;
            end
        end
    end

    // read immediate value when immediate instruction is selected
    always @ (negedge clk) begin
        issue_imm_value_1 <= imm_buffer[issue_imm_ptr_1];
        issue_imm_value_2 <= imm_buffer[issue_imm_ptr_2];
    end

endmodule