`include "constants.vh"
`default_nettype none

module store_queue (
    input wire clk,
    input wire reset,
    input wire dispatch_store_valid_1,      // New Store instruction dispatch for instruction 1
    input wire dispatch_store_valid_2,      // New Store instruction dispatch for instruction 2
    input wire [`REG_SEL-1:0] base_reg_1,   // Base register for instruction 1
    input wire [`REG_SEL-1:0] base_reg_2,   // Base register for instruction 2
    input wire [`IMM_WIDTH-1:0] offset_1,   // Immediate value for instruction 1
    input wire [`IMM_WIDTH-1:0] offset_2,   // Immediate value for instruction 2
    input wire [`DATA_WIDTH-1:0] store_data_1, // Data to store for instruction 1
    input wire [`DATA_WIDTH-1:0] store_data_2, // Data to store for instruction 2
    input wire [`ROB_SEL-1:0] rob_idx_1,    // ROB Index for instruction 1
    input wire [`ROB_SEL-1:0] rob_idx_2,    // ROB Index for instruction 2
    input wire address_ready,               // Address calculation completed
    input wire [`ADDR_WIDTH-1:0] calculated_address_1, // Calculated address for instruction 1
    input wire [`ADDR_WIDTH-1:0] calculated_address_2, // Calculated address for instruction 2
    input wire [`SQ_SEL-1:0] update_rob_idx_1, // Index of the Store Queue entry to update for instruction 1
    input wire [`SQ_SEL-1:0] update_rob_idx_2, // Index of the Store Queue entry to update for instruction 2
    input wire commit_enable,               // Commit Store instruction
    output reg sq_full,                     // Store Queue Full
    output reg sq_empty,                    // Store Queue Empty
    output reg [`ADDR_WIDTH-1:0] store_address, // Store Address for execution
    output reg [`DATA_WIDTH-1:0] store_value,   // Data to store
    output reg store_ready                  // Store Instruction Ready
);

    // Internal Store Queue Entries as separate arrays
    reg valid[`SQ_NUM-1:0];
    reg [`REG_SEL-1:0] base_reg_array[`SQ_NUM-1:0];
    reg [`IMM_WIDTH-1:0] offset_array[`SQ_NUM-1:0];
    reg [`DATA_WIDTH-1:0] data_array[`SQ_NUM-1:0];
    reg [`ROB_SEL-1:0] rob_idx_array[`SQ_NUM-1:0];
    reg [`ADDR_WIDTH-1:0] address_array[`SQ_NUM-1:0];
    reg address_ready_array[`SQ_NUM-1:0];

    reg [`SQ_SEL-1:0] head, tail;
    reg [`SQ_SEL:0] count;
    reg [`SQ_SEL-1:0] loop_idx; // Replace integer with reg

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            sq_full <= 0;
            sq_empty <= 1;
            store_ready <= 0;

            // Initialize all entries
            for (loop_idx = 0; loop_idx < `SQ_NUM; loop_idx = loop_idx + 1) begin
                valid[loop_idx] <= 0;
                base_reg_array[loop_idx] <= 0;
                offset_array[loop_idx] <= 0;
                data_array[loop_idx] <= 0;
                rob_idx_array[loop_idx] <= 0;
                address_array[loop_idx] <= 0;
                address_ready_array[loop_idx] <= 0;
            end
        end else begin
            // Dispatch Logic
            if (dispatch_store_valid_1 && !sq_full) begin
                valid[tail] <= 1;
                base_reg_array[tail] <= base_reg_1;
                offset_array[tail] <= offset_1;
                data_array[tail] <= store_data_1;
                rob_idx_array[tail] <= rob_idx_1;
                address_ready_array[tail] <= 0;
                tail <= (tail + 1) % `SQ_NUM;
                count <= count + 1;
            end
            if (dispatch_store_valid_2 && !sq_full && (count < `SQ_NUM - 1)) begin
                valid[tail] <= 1;
                base_reg_array[tail] <= base_reg_2;
                offset_array[tail] <= offset_2;
                data_array[tail] <= store_data_2;
                rob_idx_array[tail] <= rob_idx_2;
                address_ready_array[tail] <= 0;
                tail <= (tail + 1) % `SQ_NUM;
                count <= count + 1;
            end

            // Address Calculation Update
            if (address_ready && valid[update_rob_idx_1] && !address_ready_array[update_rob_idx_1]) begin
                address_array[update_rob_idx_1] <= calculated_address_1;
                address_ready_array[update_rob_idx_1] <= 1;
            end
            if (address_ready && valid[update_rob_idx_2] && !address_ready_array[update_rob_idx_2]) begin
                address_array[update_rob_idx_2] <= calculated_address_2;
                address_ready_array[update_rob_idx_2] <= 1;
            end

            /*
            // Commit Logic
            if (commit_enable && !sq_empty && valid[head] && address_ready_array[head]) begin
                valid[head] <= 0;
                head <= (head + 1) % `SQ_NUM;
                count <= count - 1;
            end
            */

            // Update Status
            sq_full <= (count >= `SQ_NUM - 1);
            sq_empty <= (count == 0);
        end
    end
endmodule
