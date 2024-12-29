`include "constants.vh"
`default_nettype none
// recovery is not implemented yet
module reorder_buffer (
    input wire                      clk,
    input wire                      reset,
    // dispatch
    input wire                      invalid1,
    input wire                      invalid2,
    input wire                      ld_valid1,
    input wire                      ld_valid2,
    input wire                      st_valid1,
    input wire                      st_valid2,
    input wire [`REG_SEL-1:0]       dst_1,
    input wire [`REG_SEL-1:0]       dst_2,
    input wire [`PHY_REG_SEL-1:0]   phy_ori_dst_1,
    input wire [`PHY_REG_SEL-1:0]   phy_ori_dst_2,
    input wire                      stall_DP,
    output wire [`ROB_SEL-1:0]      rob_idx_1,
    output wire [`ROB_SEL-1:0]      rob_idx_2,
    output wire                     rob_sorting_bit_1,
    output wire                     rob_sorting_bit_2,
    output wire                     wrap_around,
    output wire                     allocatable,
    input wire                      prmiss,                 // Branch Misprediction
    input wire [`ROB_SEL-1:0]       prmiss_rob_idx,
    input wire                      violation_detected,     // Memory Order Violation detected
    input wire [`ROB_SEL-1:0]       violation_rob_idx,
    // execution complete signal should be added
    // sent from write back stage, setting corresponding inst in rob entry complete

    // commit
    output wire                     commit_valid1,
    output wire                     commit_valid2,
    output wire                     commit_is_load_1,
    output wire                     commit_is_load_2,
    output wire                     commit_is_store_1,
    output wire                     commit_is_store_2,
    output wire [`REG_SEL-1:0]      commit_dst_1,
    output wire [`REG_SEL-1:0]      commit_dst_2,
    output wire [`PHY_REG_SEL-1:0]  commit_release_tag_1,
    output wire [`PHY_REG_SEL-1:0]  commit_release_tag_2
    );

    // ROB entry
    reg                             valid       [`ROB_NUM-1:0];
    reg                             complete    [`ROB_NUM-1:0];
    reg [`REG_SEL-1:0]              dst         [`ROB_NUM-1:0];
    reg [`PHY_REG_SEL-1:0]          phy_ori_dst [`ROB_NUM-1:0];
    reg                             is_load     [`ROB_NUM-1:0];
    reg                             is_store    [`ROB_NUM-1:0];
    reg [`ROB_SEL-1:0]              head;
    reg [`ROB_SEL-1:0]              tail;
    reg [`ROB_SEL:0]                count;

    reg [`ROB_SEL-1:0]              i;


    wire [1:0] reqnum;
    wire [1:0] comnum;

    // the number of reqested instructions
    assign reqnum = (~invalid1 && ~invalid2) ? 2'b10 : ((~invalid1) ? 2'b01 : 2'b00);
    // the number of committed instructions
    assign comnum = (commit_enable_1 && commit_enable_2) ? 2'b10 : ((commit_enable_1) ? 2'b01 : 2'b00);
    assign allocatable = ((count - comnum + reqnum) <= `ROB_NUM) ? 1'b1 : 1'b0;

    // rob_idx allocation in dispatch stage
    // when wrap_aroudn occurs, all sorting bits in structures are set (by Buyuktosunoglu).
    wire wrap_1;
    wire wrap_2;
    wire [`ROB_SEL-1:0] next_tail;

    assign wrap_1 = (tail == 0) && ~invalid1;
    assign wrap_2 = (tail == 1) && ~invalid1 && ~invalid2;
    
    assign rob_idx_1 = wrap_1 ? (`ROB_NUM - 1) : (tail - 1);
    assign rob_idx_2 = wrap_1 ? (`ROB_NUM - 2) : (wrap_2 ? (`ROB_NUM - 1) : (tail - 2));

    assign rob_sorting_bit_1 = wrap_2 ? 1'b1 : 1'b0;
    assign rob_sorting_bit_2 = 1'b0;

    assign wrap_around = wrap_1 | wrap_2;
    assign next_tail = wrap_around ? (`ROB_NUM - reqnum) : tail - reqnum;

    // Commit Logic - commit at most 2 instructions in ROB
    wire                    commit_enable_1;
    wire                    commit_enable_2;
    wire [`ROB_SEL-1:0]     commit_idx_1;
    wire [`ROB_SEL-1:0]     commit_idx_2;
    wire [`ROB_SEL-1:0]     next_head;
    wire                    wrap_head_1;
    wire                    wrap_head_2;
    wire                    overlap_1;
    wire                    overlap_2;

    // head can wrap around as well when commit
    assign wrap_head_1 = head == 0;
    assign wrap_head_2 = commit_enable_1 && (head == 1);

    assign commit_enable_1 = valid[head] && complete[head];
    assign commit_enable_2 = commit_enable_1 &&
                             (wrap_head_1 ? (valid[`ROB_NUM - 1] && complete[`ROB_NUM - 1])
                           : (valid[head - 1] && complete[head - 1]));

    assign commit_idx_1 = head;
    assign commit_idx_2 = wrap_head_1 ? (`ROB_NUM - 1) : (head - 1);

    assign next_head = commit_enable_2
                     ? (wrap_head_1 ? (`ROB_NUM - 2) : (wrap_head_2 ? (`ROB_NUM - 1) : (head - 2)))
                     : (commit_enable_1 ? (wrap_head_1 ? (`ROB_NUM - 1) : (head - 1))
                     : head);

    // addressing when a committed entry is allocated at the very next cycle
    assign overlap_1 = ~stall_DP && (((reqnum == 2'b10) && ((rob_idx_1 == commit_idx_1) || (rob_idx_2 == commit_idx_1)))
                    || ((reqnum == 2'b01) && (rob_idx_1 == commit_idx_1)));
    assign overlap_2 = ~stall_DP && ((reqnum == 2'b10) && (rob_idx_2 == commit_idx_2));

    // commit output
    assign commit_valid1 = commit_enable_1;
    assign commit_is_load_1 = is_load[commit_idx_1];
    assign commit_is_store_1 = is_store[commit_idx_1];
    assign commit_dst_1 = dst[commit_idx_1];
    assign commit_release_tag_1 = phy_ori_dst[commit_idx_1];

    assign commit_valid2 = commit_enable_2;
    assign commit_is_load_2 = is_load[commit_idx_2];
    assign commit_is_store_2 = is_store[commit_idx_2];
    assign commit_dst_2 = dst[commit_idx_2];
    assign commit_release_tag_2 = phy_ori_dst[commit_idx_2];
    

    // ROB entry update when dispatch, writeback, and commit
    always @ (posedge clk) begin
        if (reset) begin
            head <= `ROB_NUM - 1;
            tail <= 0;
            count <= 0;

            // Initialize valid bits to 0
            for (i = 0; i < `ROB_NUM; i = i + 1) begin
                valid[i] <= 0;
                complete[i] <= 0;
            end
        end else begin
            if (prmiss) begin
                // recovery -> backward traversal
                // the number of flushed instruction should be considered here.
                count <= count - comnum;
            end else if (~stall_DP) begin
                // Dispatch when allocatable
                if (reqnum[0] ^ reqnum[1]) begin
                    valid[rob_idx_1] <= 1;
                    complete[rob_idx_1] <= 0;
                    dst[rob_idx_1] <= dst_1;
                    phy_ori_dst[rob_idx_1] <= phy_ori_dst_1;
                    is_load[rob_idx_1] <= ld_valid1;
                    is_store[rob_idx_1] <= st_valid1;
                end
                if (reqnum == 2'b10) begin
                    valid[rob_idx_2] <= 1;
                    complete[rob_idx_2] <= 0;
                    dst[rob_idx_2] <= dst_2;
                    phy_ori_dst[rob_idx_2] <= phy_ori_dst_2;
                    is_load[rob_idx_2] <= ld_valid2;
                    is_store[rob_idx_2] <= st_valid2;
                end
                tail <= next_tail;
                count <= count - comnum + reqnum;
            end else begin
                count <= count - comnum;
            end

            // commit update status
            if (commit_enable_1 && ~overlap_1) begin
                valid[commit_idx_1] <= 0;
                complete[commit_idx_1] <= 0;
            end
            if (commit_enable_2 && ~overlap_2) begin
                valid[commit_idx_2] <= 0;
                complete[commit_idx_2] <= 0;
            end
        end
    end
endmodule