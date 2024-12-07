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
    input wire [`ADDR_LEN-1:0] calculated_address_1, // Calculated address (way 1)
    input wire [`ADDR_LEN-1:0] calculated_address_2, // Calculated address (way 2)
    input wire commit_enable_1,             // Commit Load instruction 1
    input wire commit_enable_2,             // Commit Load instruction 2
    output wire lq_full,                    // Load Queue Full
    output wire lq_empty,                   // Load Queue Empty
    output wire [`LQ_SEL-1:0] lq_head,      // Current Head Pointer
    output wire [`LQ_SEL-1:0] lq_tail,      // Current Tail Pointer
    output reg [`ADDR_LEN-1:0] load_address, // Load Address for execution
    output reg [`ROB_IDX_NUM-1:0] load_rob_idx, // ROB Index for execution
    output reg load_ready                   // Load Instruction Ready
);

    // Internal Load Queue Entries as separate arrays
    reg valid[`LQ_NUM-1:0];
    reg [`PHY_REG_SEL-1:0] base_reg_array[`LQ_NUM-1:0];
    reg [`IMM_LEN-1:0] offset_array[`LQ_NUM-1:0];
    reg [`ROB_IDX_NUM-1:0] rob_idx_array[`LQ_NUM-1:0];
    reg [`ADDR_LEN-1:0] address_array[`LQ_NUM-1:0];
    reg address_ready_array[`LQ_NUM-1:0];

    reg [`LQ_SEL-1:0] head, tail;
    reg [`LQ_SEL:0] count;

    assign lq_head = head;
    assign lq_tail = tail;
    assign lq_full = (count == `LQ_NUM);
    assign lq_empty = (count == 0);

    // Calculate the number of dispatched and committed instructions
    wire [1:0] reqnum;
    wire [1:0] comnum;

    assign reqnum = (dispatch_lq_valid_1 && dispatch_lq_valid_2) ? 2'b10 :
                    (dispatch_lq_valid_1 || dispatch_lq_valid_2) ? 2'b01 : 2'b00;

    assign comnum = (commit_enable_1 && commit_enable_2) ? 2'b10 :
                    (commit_enable_1 || commit_enable_2) ? 2'b01 : 2'b00;

    // Internal LQ indices for dispatch
    wire [`LQ_SEL-1:0] first_lq_idx, second_lq_idx;
    wire wrap_1, wrap_2, wrap_3, wrap_4;

    // Wrap-around logic for LQ indices
    assign wrap_1 = (tail == 0) && dispatch_lq_valid_1;
    assign wrap_2 = (tail == 0) && dispatch_lq_valid_2;
    assign wrap_3 = (tail == 0) && dispatch_lq_valid_1 && dispatch_lq_valid_2;
    assign wrap_4 = (tail == 1) && dispatch_lq_valid_1 && dispatch_lq_valid_2;

    assign first_lq_idx = wrap_1 ? (`LQ_NUM - 1) :
                          wrap_2 ? (`LQ_NUM - 1) :
                          wrap_3 ? (`LQ_NUM - 1) : (tail - 1);

    assign second_lq_idx = wrap_3 ? (`LQ_NUM - 2) :
                           wrap_4 ? (`LQ_NUM - 1) : (tail - 2);

    wire [`LQ_SEL-1:0] next_tail;
    assign next_tail = (wrap_1 || wrap_2 || wrap_3 || wrap_4) ? (`LQ_NUM - reqnum) : (tail - reqnum);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= `LQ_NUM - 1;
            tail <= 0;
            count <= 0;
            load_ready <= 0;

            // Initialize all entries
            for (integer i = 0; i < `LQ_NUM; i = i + 1) begin
                valid[i] <= 0;
                base_reg_array[i] <= 0;
                offset_array[i] <= 0;
                rob_idx_array[i] <= 0;
                address_array[i] <= 0;
                address_ready_array[i] <= 0;
            end
        end else begin
            // Dispatch Logic
            if (dispatch_lq_valid_1 && !dispatch_lq_valid_2 && !lq_full) begin
                // Way 1 only
                valid[first_lq_idx] <= 1;
                base_reg_array[first_lq_idx] <= base_reg_1;
                offset_array[first_lq_idx] <= offset_1;
                rob_idx_array[first_lq_idx] <= rob_idx_1;
                address_ready_array[first_lq_idx] <= 0;
            end else if (dispatch_lq_valid_2 && !dispatch_lq_valid_1 && !lq_full) begin
                // Way 2 only
                valid[first_lq_idx] <= 1;
                base_reg_array[first_lq_idx] <= base_reg_2;
                offset_array[first_lq_idx] <= offset_2;
                rob_idx_array[first_lq_idx] <= rob_idx_2;
                address_ready_array[first_lq_idx] <= 0;
            end else if (dispatch_lq_valid_1 && dispatch_lq_valid_2 && !lq_full) begin
                // Both Way 1 and Way 2
                valid[first_lq_idx] <= 1;
                base_reg_array[first_lq_idx] <= base_reg_1;
                offset_array[first_lq_idx] <= offset_1;
                rob_idx_array[first_lq_idx] <= rob_idx_1;
                address_ready_array[first_lq_idx] <= 0;

                valid[second_lq_idx] <= 1;
                base_reg_array[second_lq_idx] <= base_reg_2;
                offset_array[second_lq_idx] <= offset_2;
                rob_idx_array[second_lq_idx] <= rob_idx_2;
                address_ready_array[second_lq_idx] <= 0;
            end

            // Update Tail
            tail <= next_tail;

            // Address Update Logic
            if (address_ready) begin
                if (valid[first_lq_idx] && !address_ready_array[first_lq_idx]) begin
                    address_array[first_lq_idx] <= calculated_address_1;
                    address_ready_array[first_lq_idx] <= 1;
                end
                if (valid[second_lq_idx] && !address_ready_array[second_lq_idx]) begin
                    address_array[second_lq_idx] <= calculated_address_2;
                    address_ready_array[second_lq_idx] <= 1;
                end
            end
            /*
            // Commit Logic (Optional)
            if (commit_enable_1 && valid[head]) begin
                valid[head] <= 0;
                head <= (head == 0) ? (`LQ_NUM - 1) : (head - 1);
            end
            if (commit_enable_2 && valid[(head == 0) ? (`LQ_NUM - 1) : (head - 1)]) begin
                valid[(head == 0) ? (`LQ_NUM - 1) : (head - 1)] <= 0;
                head <= (head == 1) ? (`LQ_NUM - 1) : (head - 2);
            end
            */
            // Update Count
            count <= count - comnum + reqnum;
        end
    end
endmodule
