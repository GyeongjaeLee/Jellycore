`include "constants.vh"
`default_nettype none

module load_queue (
    input wire clk,
    input wire reset,
    input wire dispatch_lq_valid_1,       // New Load instruction dispatch (way 1)
    input wire dispatch_lq_valid_2,       // New Load instruction dispatch (way 2)
    input wire [`PHY_REG_SEL-1:0] base_reg_1,   // Base register (way 1)
    input wire [`PHY_REG_SEL-1:0] base_reg_2,   // Base register (way 2)
    input wire [`IMM_LEN-1:0] offset_1,   // Immediate value (way 1)
    input wire [`IMM_LEN-1:0] offset_2,   // Immediate value (way 2)
    input wire [`ROB_IDX_NUM-1:0] rob_idx_1,    // ROB Index (way 1)
    input wire [`ROB_IDX_NUM-1:0] rob_idx_2,    // ROB Index (way 2)
    input wire address_ready,               // Address calculation completed
    input wire [`ADDR_LEN-1:0] calculated_address, // Calculated address
    input wire [`LQ_SEL-1:0] update_rob_idx, // Index of the Load Queue entry to update
    input wire commit_enable,               // Commit Load instruction
    output reg lq_full,                     // Load Queue Full
    output reg lq_empty,                    // Load Queue Empty
    output reg [`ADDR_LEN-1:0] load_address, // Load Address for execution
    output reg [`ROB_SEL-1:0] load_rob_idx,    // ROB Index for execution
    output reg load_ready                   // Load Instruction Ready
);

    // Internal Load Queue Entries as separate arrays
    reg valid[`LQ_NUM-1:0];
    reg [`PHY_REG_SEL-1:0] base_reg_array[`LQ_NUM-1:0];
    reg [`IMM_LEN-1:0] offset_array[`LQ_NUM-1:0];
    reg [`ROB_SEL-1:0] rob_idx_array[`LQ_NUM-1:0];
    reg [`ADDR_LEN-1:0] address_array[`LQ_NUM-1:0];
    reg address_ready_array[`LQ_NUM-1:0];

    reg [`LQ_SEL-1:0] head, tail;
    reg [`LQ_SEL:0] count;
    reg [`LQ_SEL:0] count_temp;
    reg [`LQ_SEL-1:0] loop_idx;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            lq_full <= 0;
            lq_empty <= 1;
            load_ready <= 0;

            // Initialize all entries
            for (loop_idx = 0; loop_idx < `LQ_NUM; loop_idx = loop_idx + 1) begin
                valid[loop_idx] <= 0;
                base_reg_array[loop_idx] <= 0;
                offset_array[loop_idx] <= 0;
                rob_idx_array[loop_idx] <= 0;
                address_array[loop_idx] <= 0;
                address_ready_array[loop_idx] <= 0;
            end
        end else begin
            count_temp = count;

            // Dispatch Logic
            if (dispatch_lq_valid_1 && !dispatch_lq_valid_2 && !lq_full) begin
                // Case 1: Only instruction 1 is valid
                valid[tail] <= 1;
                base_reg_array[tail] <= base_reg_1;
                offset_array[tail] <= offset_1;
                rob_idx_array[tail] <= rob_idx_1;
                address_ready_array[tail] <= 0;
                tail <= (tail + 1) % `LQ_NUM;
                count_temp = count_temp + 1;

            end else if (!dispatch_lq_valid_1 && dispatch_lq_valid_2 && !lq_full) begin
                // Case 2: Only instruction 2 is valid
                valid[tail] <= 1;
                base_reg_array[tail] <= base_reg_2;
                offset_array[tail] <= offset_2;
                rob_idx_array[tail] <= rob_idx_2;
                address_ready_array[tail] <= 0;
                tail <= (tail + 1) % `LQ_NUM;
                count_temp = count_temp + 1;

            end else if (dispatch_lq_valid_1 && dispatch_lq_valid_2 && (count < `LQ_NUM - 1)) begin
                // Case 3: Both instructions are valid
                valid[tail] <= 1;
                base_reg_array[tail] <= base_reg_1;
                offset_array[tail] <= offset_1;
                rob_idx_array[tail] <= rob_idx_1;
                address_ready_array[tail] <= 0;

                valid[(tail + 1) % `LQ_NUM] <= 1;
                base_reg_array[(tail + 1) % `LQ_NUM] <= base_reg_2;
                offset_array[(tail + 1) % `LQ_NUM] <= offset_2;
                rob_idx_array[(tail + 1) % `LQ_NUM] <= rob_idx_2;
                address_ready_array[(tail + 1) % `LQ_NUM] <= 0;

                tail <= (tail + 2) % `LQ_NUM;
                count_temp = count_temp + 2;
            end

            // Address Calculation Update
            if (address_ready && valid[update_rob_idx] && !address_ready_array[update_rob_idx]) begin
                address_array[update_rob_idx] <= calculated_address;
                address_ready_array[update_rob_idx] <= 1;
            end
            /*
            // Commit Logic
            if (commit_enable && !lq_empty && valid[head] && address_ready_array[head]) begin
                valid[head] <= 0;
                head <= (head + 1) % `LQ_NUM;
                count_temp = count_temp - 1;
            end
            */
            // Update Count
            count <= count_temp;

            // Update Status
            lq_full <= (count_temp >= `LQ_NUM - 1);
            lq_empty <= (count_temp == 0);
        end
    end
endmodule
