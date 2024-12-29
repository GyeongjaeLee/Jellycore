`include "constants.vh"
`default_nettype none

module load_queue (
    input wire                  clk,
    input wire                  reset,
    input wire                  dispatch_lq_valid_1,
    input wire                  dispatch_lq_valid_2,
    input wire                  dst_reg_1,
    input wire                  dst_reg_2,
    input wire                  address_ready,
    input wire [`ADDR_LEN-1:0]  calculated_address_1,
    input wire [`ADDR_LEN-1:0]  calculated_address_2,
    input wire                  commit_enable_1,
    input wire                  commit_enable_2,
    output wire                 lq_full,
    output wire                 lq_empty,
    output wire [`LQ_SEL-1:0]   lq_head,
    output wire [`LQ_SEL-1:0]   lq_tail,
    output reg [`ADDR_LEN-1:0]  load_address,
    output reg [`ROB_SEL-1:0]   load_rob_idx,
    output reg                  load_ready
);

    // Internal Load Queue Entries as separate arrays
    reg                     valid       [`LQ_NUM-1:0];
    reg [`PHY_REG_SEL-1:0]  dst         [`LQ_NUM-1:0];
    reg [`ADDR_LEN-1:0]     address     [`LQ_NUM-1:0];
    reg                     calculated  [`LQ_NUM-1:0];
    

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
                dst[i] <= 0;
                address[i] <= 0;
                calculated [i] <= 0;
            end
        end else begin
            // Dispatch Logic
            if (dispatch_lq_valid_1 && !dispatch_lq_valid_2 && !lq_full) begin
                // Way 1 only
                valid[first_lq_idx] <= 1;
                dst[first_lq_idx] <= dst_reg_1;
                calculated[first_lq_idx] <= 0;
            end else if (dispatch_lq_valid_2 && !dispatch_lq_valid_1 && !lq_full) begin
                // Way 2 only
                valid[first_lq_idx] <= 1;
                dst[first_lq_idx] <= dst_reg_2;
                calculated[first_lq_idx] <= 0;
            end else if (dispatch_lq_valid_1 && dispatch_lq_valid_2 && !lq_full) begin
                // Both Way 1 and Way 2
                valid[first_lq_idx] <= 1;
                dst[first_lq_idx] <= dst_reg_1;
                calculated[first_lq_idx] <= 0;

                valid[second_lq_idx] <= 1;
                dst[second_lq_idx] <= dst_reg_2;
                calculated[second_lq_idx] <= 0;
            end

            // Update Tail
            tail <= next_tail;

            // // Address Update Logic
            // if (address_ready) begin
            //     if (valid[first_lq_idx] && !calculated [first_lq_idx]) begin
            //         address[first_lq_idx] <= calculated_address_1;
            //         calculated[first_lq_idx] <= 1;
            //     end
            //     if (valid[second_lq_idx] && !calculated [second_lq_idx]) begin
            //         address[second_lq_idx] <= calculated_address_2;
            //         calculated[second_lq_idx] <= 1;
            //     end
            // end
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