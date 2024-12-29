`include "constants.vh"
`default_nettype none

module store_queue (
    input wire                  clk,
    input wire                  reset,
    input wire                  dispatch_sq_valid_1,
    input wire                  dispatch_sq_valid_2,
    input wire [`DATA_LEN-1:0]  store_data_1,
    input wire [`DATA_LEN-1:0]  store_data_2,
    input wire                  address_ready,
    input wire [`ADDR_LEN-1:0]  calculated_address_1,
    input wire [`ADDR_LEN-1:0]  calculated_address_2,
    input wire                  commit_enable_1,
    input wire                  commit_enable_2,
    output wire                 sq_full,
    output wire                 sq_empty,
    output wire [`SQ_SEL-1:0]   sq_head,
    output wire [`SQ_SEL-1:0]   sq_tail,
    output reg [`ADDR_LEN-1:0]  store_address,
    output reg [`DATA_LEN-1:0]  store_value,
    output reg                  store_ready
);

    // Internal Store Queue Entries as separate arraysa
    reg                 valid       [`SQ_NUM-1:0];
    reg [`DATA_LEN-1:0] data        [`SQ_NUM-1:0];
    reg [`ADDR_LEN-1:0] address     [`SQ_NUM-1:0];
    reg                 calculated  [`SQ_NUM-1:0];

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

            for (integer i = 0; i < `SQ_NUM; i = i + 1) begin
                valid[i] <= 0;
                data[i] <= 0;
                address[i] <= 0;
                calculated[i] <= 0;
            end
        end else begin
            // Dispatch Logic
            if (dispatch_sq_valid_1 && !dispatch_sq_valid_2 && !sq_full) begin
                // Way 1 only
                valid[first_sq_idx] <= 1;
                data[first_sq_idx] <= store_data_1;
                calculated[first_sq_idx] <= 0;
            end else if (dispatch_sq_valid_2 && !dispatch_sq_valid_1 && !sq_full) begin
                // Way 2 only
                valid[first_sq_idx] <= 1;
                data[first_sq_idx] <= store_data_2;
                calculated[first_sq_idx] <= 0;
            end else if (dispatch_sq_valid_1 && dispatch_sq_valid_2 && !sq_full) begin
                // Both Way 1 and Way 2
                valid[first_sq_idx] <= 1;
                data[first_sq_idx] <= store_data_1;
                calculated[first_sq_idx] <= 0;

                valid[second_sq_idx] <= 1;
                data[second_sq_idx] <= store_data_2;
                calculated[second_sq_idx] <= 0;
            end

            // Update Tail
            tail <= next_tail;

            // // Address Update Logic
            // if (address_ready) begin
            //     if (valid[first_sq_idx] && !calculated[first_sq_idx]) begin
            //         address[first_sq_idx] <= calculated_address_1;
            //         calculated[first_sq_idx] <= 1;
            //     end
            //     if (valid[second_sq_idx] && !calculated[second_sq_idx]) begin
            //         address[second_sq_idx] <= calculated_address_2;
            //         calculated[second_sq_idx] <= 1;
            //     end
            // end
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