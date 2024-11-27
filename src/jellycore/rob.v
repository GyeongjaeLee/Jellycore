`include "constants.vh"
`default_nettype none

module reorder_buffer (
    input wire clk,
    input wire reset,
    input wire dispatch_valid,            // New instruction dispatch
    input wire [`ROB_SEL-1:0] rob_idx,    // ROB Index
    input wire commit_enable,             // Commit instruction
    input wire violation_detected,        // Memory Order Violation detected
    output reg rob_full,                  // ROB Full
    output reg rob_empty,                 // ROB Empty
    output reg [`ROB_SEL-1:0] commit_rob_idx // Committed ROB Index
);

    reg valid[`ROB_SIZE-1:0];
    reg [$clog2(`ROB_SIZE)-1:0] head, tail;
    reg [$clog2(`ROB_SIZE):0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            rob_full <= 0;
            rob_empty <= 1;
        end else begin
            // Dispatch Logic
            if (dispatch_valid && !rob_full) begin
                valid[tail] <= 1;
                rob_idx[tail] <= rob_idx;
                tail <= (tail + 1) % `ROB_SIZE;
                count <= count + 1;
            end

            /*
            // Commit Logic
            if (commit_enable && !rob_empty && valid[head]) begin
                commit_rob_idx <= head;
                valid[head] <= 0;
                head <= (head + 1) % `ROB_SIZE;
                count <= count - 1;
            end
            */
            
            // Violation Handling
            if (violation_detected) begin
                // Flush logic (invalidate entries, reset state as needed)
            end

            // Update Status
            rob_full <= (count == `ROB_SIZE);
            rob_empty <= (count == 0);
        end
    end
endmodule
