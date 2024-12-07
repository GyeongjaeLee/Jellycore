`include "constants.vh"
`default_nettype none

module store_queue (
    input wire clk,
    input wire reset,
    input wire dispatch_sq_valid_1,      // New Store instruction dispatch for instruction 1
    input wire dispatch_sq_valid_2,      // New Store instruction dispatch for instruction 2
    input wire [`PHY_REG_SEL-1:0] base_reg_1,   // Base register for instruction 1
    input wire [`PHY_REG_SEL-1:0] base_reg_2,   // Base register for instruction 2
    input wire [`IMM_LEN-1:0] offset_1,   // Immediate value for instruction 1
    input wire [`IMM_LEN-1:0] offset_2,   // Immediate value for instruction 2
    input wire [`DATA_LEN-1:0] store_data_1, // Data to store for instruction 1
    input wire [`DATA_LEN-1:0] store_data_2, // Data to store for instruction 2
    input wire [`ROB_IDX_NUM-1:0] rob_idx_1,    // ROB Index for instruction 1
    input wire [`ROB_IDX_NUM-1:0] rob_idx_2,    // ROB Index for instruction 2
    input wire address_ready,               // Address calculation completed
    input wire [`ADDR_LEN-1:0] calculated_address_1, // Calculated address for instruction 1
    input wire [`ADDR_LEN-1:0] calculated_address_2, // Calculated address for instruction 2
    input wire commit_enable_1,             // Commit Store instruction 1
    input wire commit_enable_2,             // Commit Store instruction 2
    output wire sq_full,                    // Store Queue Full
    output wire sq_empty,                   // Store Queue Empty
    output wire [`SQ_SEL-1:0] sq_head,      // Current Head Pointer
    output wire [`SQ_SEL-1:0] sq_tail,      // Current Tail Pointer
    output reg [`ADDR_LEN-1:0] store_address, // Store Address for execution
    output reg [`DATA_LEN-1:0] store_value,   // Data to store
    output reg store_ready                  // Store Instruction Ready
);

    // Internal Store Queue Entries as separate arrays
    reg valid[`SQ_NUM-1:0];
    reg [`PHY_REG_SEL-1:0] base_reg_array[`SQ_NUM-1:0];
    reg [`IMM_LEN-1:0] offset_array[`SQ_NUM-1:0];
    reg [`DATA_LEN-1:0] data_array[`SQ_NUM-1:0];
    reg [`ROB_IDX_NUM-1:0] rob_idx_array[`SQ_NUM-1:0];
    reg [`ADDR_LEN-1:0] address_array[`SQ_NUM-1:0];
    reg address_ready_array[`SQ_NUM-1:0];

    reg [`SQ_SEL-1:0] head, tail;
    reg [`SQ_SEL:0] count;

    assign sq_head = head;
    assign sq_tail = tail;
    assign sq_full = (count == `SQ_NUM);
    assign sq_empty = (count == 0);

    // Calculate the number of dispatched and committed instructions
    wire [1:0] reqnum;
    wire [1:0] comnum;

    assign reqnum = (dispatch_sq_valid_1 && dispatch_sq_valid_2) ? 2'b10 :
                    (dispatch_sq_valid_1 || dispatch_sq_valid_2) ? 2'b01 : 2'b00;

    assign comnum = (commit_enable_1 && commit_enable_2) ? 2'b10 :
                    (commit_enable_1 || commit_enable_2) ? 2'b01 : 2'b00;

    // Internal SQ indices for dispatch
    wire [`SQ_SEL-1:0] first_sq_idx, second_sq_idx;
    wire wrap_1, wrap_2, wrap_3, wrap_4;

    // Wrap-around logic for SQ indices
    assign wrap_1 = (tail == 0) && dispatch_sq_valid_1;
    assign wrap_2 = (tail == 0) && dispatch_sq_valid_2;
    assign wrap_3 = (tail == 0) && dispatch_sq_valid_1 && dispatch_sq_valid_2;
    assign wrap_4 = (tail == 1) && dispatch_sq_valid_1 && dispatch_sq_valid_2;


    assign first_sq_idx = wrap_1 ? (`SQ_NUM - 1) :
                          wrap_2 ? (`SQ_NUM - 1) :
                          wrap_3 ? (`SQ_NUM - 1) : (tail - 1);

    assign second_sq_idx = wrap_3 ? (`SQ_NUM - 2) :
                           wrap_4 ? (`SQ_NUM - 1) : (tail - 2);

    wire [`SQ_SEL-1:0] next_tail;
    assign next_tail = (wrap_1 || wrap_2 || wrap_3 || wrap_4) ? (`SQ_NUM - reqnum) : (tail - reqnum);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= `SQ_NUM - 1;
            tail <= 0;
            count <= 0;
            store_ready <= 0;

            // Initialize all entries
            for (integer i = 0; i < `SQ_NUM; i = i + 1) begin
                valid[i] <= 0;
                base_reg_array[i] <= 0;
                offset_array[i] <= 0;
                data_array[i] <= 0;
                rob_idx_array[i] <= 0;
                address_array[i] <= 0;
                address_ready_array[i] <= 0;
            end
        end else begin
            // Dispatch Logic
            if (dispatch_sq_valid_1 && !dispatch_sq_valid_2 && !sq_full) begin
                // Way 1 only
                valid[first_sq_idx] <= 1;
                base_reg_array[first_sq_idx] <= base_reg_1;
                offset_array[first_sq_idx] <= offset_1;
                data_array[first_sq_idx] <= store_data_1;
                rob_idx_array[first_sq_idx] <= rob_idx_1;
                address_ready_array[first_sq_idx] <= 0;
            end else if (dispatch_sq_valid_2 && !dispatch_sq_valid_1 && !sq_full) begin
                // Way 2 only
                valid[first_sq_idx] <= 1;
                base_reg_array[first_sq_idx] <= base_reg_2;
                offset_array[first_sq_idx] <= offset_2;
                data_array[first_sq_idx] <= store_data_2;
                rob_idx_array[first_sq_idx] <= rob_idx_2;
                address_ready_array[first_sq_idx] <= 0;
            end else if (dispatch_sq_valid_1 && dispatch_sq_valid_2 && !sq_full) begin
                // Both Way 1 and Way 2
                valid[first_sq_idx] <= 1;
                base_reg_array[first_sq_idx] <= base_reg_1;
                offset_array[first_sq_idx] <= offset_1;
                data_array[first_sq_idx] <= store_data_1;
                rob_idx_array[first_sq_idx] <= rob_idx_1;
                address_ready_array[first_sq_idx] <= 0;

                valid[second_sq_idx] <= 1;
                base_reg_array[second_sq_idx] <= base_reg_2;
                offset_array[second_sq_idx] <= offset_2;
                data_array[second_sq_idx] <= store_data_2;
                rob_idx_array[second_sq_idx] <= rob_idx_2;
                address_ready_array[second_sq_idx] <= 0;
            end

            // Update Tail
            tail <= next_tail;

            // Address Update Logic
            if (address_ready) begin
                if (valid[first_sq_idx] && !address_ready_array[first_sq_idx]) begin
                    address_array[first_sq_idx] <= calculated_address_1;
                    address_ready_array[first_sq_idx] <= 1;
                end
                if (valid[second_sq_idx] && !address_ready_array[second_sq_idx]) begin
                    address_array[second_sq_idx] <= calculated_address_2;
                    address_ready_array[second_sq_idx] <= 1;
                end
            end
            /*
            // Commit Logic
            if (commit_enable_1 && valid[head]) begin
                valid[head] <= 0;
                head <= (head == 0) ? (`SQ_NUM - 1) : (head - 1);
            end
            if (commit_enable_2 && valid[(head == 0) ? (`SQ_NUM - 1) : (head - 1)]) begin
                valid[(head == 0) ? (`SQ_NUM - 1) : (head - 1)] <= 0;
                head <= (head == 1) ? (`SQ_NUM - 1) : (head - 2);
            end
            */
            // Update Count
            count <= count - comnum + reqnum;
        end
    end
endmodule
