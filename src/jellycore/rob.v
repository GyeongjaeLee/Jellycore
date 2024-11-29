`include "constants.vh"
`default_nettype none

module reorder_buffer (
    input wire clk,
    input wire reset,
    input wire dispatch_valid_1,          // New instruction dispatch (entry 1)
    input wire dispatch_valid_2,          // New instruction dispatch (entry 2)
    input wire [`ROB_SEL-1:0] rob_idx_in_1, // ROB Index from dispatcher (entry 1)
    input wire [`ROB_SEL-1:0] rob_idx_in_2, // ROB Index from dispatcher (entry 2)
    input wire commit_enable_1,           // Commit instruction (entry 1)
    input wire commit_enable_2,           // Commit instruction (entry 2)
    input wire violation_detected,        // Memory Order Violation detected
    output reg rob_full,                  // ROB Full
    output reg rob_empty,                 // ROB Empty
    output reg [`ROB_SEL-1:0] commit_rob_idx_1, // Committed ROB Index (entry 1)
    output reg [`ROB_SEL-1:0] commit_rob_idx_2  // Committed ROB Index (entry 2)
);

    reg valid[`ROB_NUM-1:0];
    reg [`ROB_SEL-1:0] rob_idx_array[`ROB_NUM-1:0]; // Internal ROB Index array
    reg [`ROB_SEL-1:0] head, tail;
    reg [`ROB_SEL:0] count;


    reg [`ROB_SEL-1:0] loop_idx;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            rob_full <= 0;
            rob_empty <= 1;

            // Initialize valid bits to 0
            for (loop_idx = 0; loop_idx < `ROB_NUM; loop_idx = loop_idx + 1) begin
                valid[loop_idx] <= 0;
            end
        end else begin
            // Dispatch Logic
            if (dispatch_valid_1 && !rob_full) begin
                valid[tail] <= 1;
                rob_idx_array[tail] <= rob_idx_in_1; // Store incoming ROB index (entry 1)
                tail <= (tail + 1) % `ROB_NUM;
                count <= count + 1;
            end
            if (dispatch_valid_2 && !rob_full && (count < `ROB_NUM)) begin
                valid[tail] <= 1;
                rob_idx_array[tail] <= rob_idx_in_2; // Store incoming ROB index (entry 2)
                tail <= (tail + 1) % `ROB_NUM;
                count <= count + 1;
            end

            // Commit Logic
            if (commit_enable_1 && !rob_empty && valid[head]) begin
                commit_rob_idx_1 <= rob_idx_array[head]; // Output the committed ROB index (entry 1)
                valid[head] <= 0;
                head <= (head + 1) % `ROB_NUM;
                count <= count - 1;
            end else begin
                commit_rob_idx_1 <= 0; // Default to 0 if no commit
            end

            if (commit_enable_2 && !rob_empty && valid[head]) begin
                commit_rob_idx_2 <= rob_idx_array[head]; // Output the committed ROB index (entry 2)
                valid[head] <= 0;
                head <= (head + 1) % `ROB_NUM;
                count <= count - 1;
            end else begin
                commit_rob_idx_2 <= 0; // Default to 0 if no commit
            end

            // Violation Handling
            if (violation_detected) begin
                // Flush logic (invalidate entries, reset state as needed)
                for (loop_idx = 0; loop_idx < `ROB_NUM; loop_idx = loop_idx + 1) begin
                    valid[loop_idx] <= 0;
                end
                head <= 0;
                tail <= 0;
                count <= 0;
            end

            // Update Status
            rob_full <= (count >= `ROB_NUM);
            rob_empty <= (count == 0);
        end
    end
endmodule
