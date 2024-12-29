`include "constants.vh"
`include "rv32_opcodes.vh"
`include "alu_ops.vh"
`default_nettype none
// recovery is not implemented yet
module issue_queue(
    input wire                      clk,
    input wire                      reset,
    // allocate at most 2 instructions at dispatch stage
    input wire                      invalid1,
    input wire                      invalid2,
    input wire [`IQ_ENT_SEL-1:0]    iq_entry_num_1,
    input wire [`IQ_ENT_SEL-1:0]    iq_entry_num_2,
    input wire [`PORT_SEL-1:0]      port_num_1,
    input wire [`PORT_SEL-1:0]      port_num_2,
    input wire                      wr_reg_1,
    input wire                      wr_reg_2,
    input wire [`SRC_A_SEL_WIDTH-1:0]  src_a_sel_1,
    input wire [`SRC_B_SEL_WIDTH-1:0]  src_b_sel_1,
    input wire [`SRC_A_SEL_WIDTH-1:0]  src_a_sel_2,
    input wire [`SRC_B_SEL_WIDTH-1:0]  src_b_sel_2,
    input wire [`RS_ENT_SEL-1:0]    inst_type_1,
    input wire [`RS_ENT_SEL-1:0]    inst_type_2,
    input wire                      alu_op_1,
    input wire                      alu_op_2,
    input wire [`PHY_REG_SEL-1:0]   src1_1,
    input wire [`PHY_REG_SEL-1:0]   src2_1,
    input wire [`PHY_REG_SEL-1:0]   src1_2,
    input wire [`PHY_REG_SEL-1:0]   src2_2,
    input wire                      match1_1,
    input wire                      match2_1,
    input wire                      match1_2,
    input wire                      match2_2,
    input wire [`MAX_LATENCY-1:0]   shift_r1_1,
    input wire [`MAX_LATENCY-1:0]   shift_r2_1,
    input wire [`MAX_LATENCY-1:0]   shift_r1_2,
    input wire [`MAX_LATENCY-1:0]   shift_r2_2,
    input wire [`MAX_LATENCY-1:0]   delay1_1,
    input wire [`MAX_LATENCY-1:0]   delay2_1,
    input wire [`MAX_LATENCY-1:0]   delay1_2,
    input wire [`MAX_LATENCY-1:0]   delay2_2,
    input wire [`PHY_REG_SEL-1:0]   dst_1,
    input wire [`PHY_REG_SEL-1:0]   dst_2,
    input wire [`IB_ENT_SEL-1:0]    imm_ptr_1,
    input wire [`IB_ENT_SEL-1:0]    imm_ptr_2,
    input wire [`PB_ENT_SEL-1:0]    pc_ptr_1,
    input wire [`PB_ENT_SEL-1:0]    pc_ptr_2,
    input wire [`PAB_ENT_SEL-1:0]   pra_ptr_1,
    input wire [`PAB_ENT_SEL-1:0]   pra_ptr_2,
    input wire                      stall_DP,
    input wire [`LQ_SEL-1:0]        lq_idx_1,
    input wire [`LQ_SEL-1:0]        lq_idx_2,
    input wire [`SQ_SEL-1:0]        sq_idx_1,
    input wire [`SQ_SEL-1:0]        sq_idx_2,
    // misprediction triggers rob_num comparison to flush instructions on the wrong path
    input wire [`ROB_SEL-1:0]       rob_num_1,
    input wire [`ROB_SEL-1:0]       rob_num_2,
    input wire                      rob_sorting_bit_1,
    input wire                      rob_sorting_bit_2,
    input wire                      wrap_around,
    input wire [`ROB_SEL-1:0]       prmiss_rob_num,
    input wire                      prmiss_rob_sorting_bit,
    input wire                      prmiss,
    // output selected instructions to execute
    // broadcast signals for the scoreboard
    output wire                     bc_enable1,
    output wire                     bc_enable2,
    output wire                     bc_enable3,
    output wire [`PHY_REG_SEL-1:0]  bc_tag1,
    output wire [`PHY_REG_SEL-1:0]  bc_tag2,
    output wire [`PHY_REG_SEL-1:0]  bc_tag3,
    // Issue Port 1
    output reg                      sel_grant_1,
    output reg [`PHY_REG_SEL-1:0]   sel_src1_1,
    output reg [`PHY_REG_SEL-1:0]   sel_src2_1,
    output reg [`PHY_REG_SEL-1:0]   sel_dst_1,
    output reg                      sel_wr_reg_1,
    output reg [`ALU_OP_WIDTH-1:0]  sel_alu_op_1,
    output reg                      sel_sorting_bit_1,
    output reg [`ROB_SEL-1:0]       sel_rob_num_1,
    output reg [`RS_ENT_SEL-1:0]    sel_inst_type_1,
    output reg [`IB_ENT_SEL-1:0]    sel_imm_ptr_1,
    output reg [`SRC_A_SEL_WIDTH-1:0]   sel_src_a_sel_1,
    output reg [`SRC_A_SEL_WIDTH-1:0]   sel_src_b_sel_1,
    // Issue Port 2
    output reg                      sel_grant_2,
    output reg [`PHY_REG_SEL-1:0]   sel_src1_2,
    output reg [`PHY_REG_SEL-1:0]   sel_src2_2,
    output reg [`PHY_REG_SEL-1:0]   sel_dst_2,
    output reg                      sel_wr_reg_2,
    output reg [`ALU_OP_WIDTH-1:0]  sel_alu_op_2,
    output reg                      sel_sorting_bit_2,
    output reg [`ROB_SEL-1:0]       sel_rob_num_2,
    output reg [`RS_ENT_SEL-1:0]    sel_inst_type_2,
    output reg [`IB_ENT_SEL-1:0]    sel_imm_ptr_2,
    output reg [`PB_ENT_SEL-1:0]    sel_pc_ptr_2,
    output reg [`PAB_ENT_SEL-1:0]   sel_pra_ptr_2,
    output reg [`SRC_A_SEL_WIDTH-1:0]   sel_src_a_sel_2,
    output reg [`SRC_A_SEL_WIDTH-1:0]   sel_src_b_sel_2,
    // Issue Port 3
    output reg                      sel_grant_3,
    output reg [`PHY_REG_SEL-1:0]   sel_src1_3,
    output reg [`PHY_REG_SEL-1:0]   sel_src2_3,
    output reg [`PHY_REG_SEL-1:0]   sel_dst_3,
    output reg                      sel_wr_reg_3,
    output reg [`ALU_OP_WIDTH-1:0]  sel_alu_op_3,
    output reg                      sel_sorting_bit_3,
    output reg [`ROB_SEL-1:0]       sel_rob_num_3,
    output reg [`LQ_SEL-1:0]        sel_iq_idx_3,
    output reg [`SQ_SEL-1:0]        sel_sq_idx_3,
    output reg [`RS_ENT_SEL-1:0]    sel_inst_type_3,
    output reg [`IB_ENT_SEL-1:0]    sel_imm_ptr_3,
    output reg [`PB_ENT_SEL-1:0]    sel_pc_ptr_3,
    output reg [`SRC_A_SEL_WIDTH-1:0]   sel_src_a_sel_3,
    output reg [`SRC_A_SEL_WIDTH-1:0]   sel_src_b_sel_3
    );

    // wakeup logic entry
    reg                         valid       [`IQ_ENT_NUM-1:0];
    reg [`PHY_REG_SEL-1:0]      src1        [`IQ_ENT_NUM-1:0];
    reg [`PHY_REG_SEL-1:0]      src2        [`IQ_ENT_NUM-1:0];
    reg                         match1      [`IQ_ENT_NUM-1:0];
    reg                         match2      [`IQ_ENT_NUM-1:0];
    reg [`MAX_LATENCY-1:0]      shift_r1    [`IQ_ENT_NUM-1:0];
    reg [`MAX_LATENCY-1:0]      shift_r2    [`IQ_ENT_NUM-1:0];
    reg [`MAX_LATENCY-1:0]      delay1      [`IQ_ENT_NUM-1:0];
    reg [`MAX_LATENCY-1:0]      delay2      [`IQ_ENT_NUM-1:0];
    reg [`PHY_REG_SEL-1:0]      dst         [`IQ_ENT_NUM-1:0];
    reg [`PORT_SEL-1:0]         port_num    [`IQ_ENT_NUM-1:0];

    // payload RAM
    reg                         wr_reg      [`IQ_ENT_NUM-1:0];
    reg [`ALU_OP_WIDTH-1:0]     alu_op      [`IQ_ENT_NUM-1:0];
    reg                         sorting_bit [`IQ_ENT_NUM-1:0];
    reg [`ROB_SEL-1:0]          rob_num     [`IQ_ENT_NUM-1:0];
    reg [`LQ_SEL-1:0]           lq_idx      [`IQ_ENT_NUM-1:0];
    reg [`SQ_SEL-1:0]           sq_idx      [`IQ_ENT_NUM-1:0];
    reg [`RS_ENT_SEL-1:0]       inst_type   [`IQ_ENT_NUM-1:0];
    reg [`IB_ENT_SEL-1:0]       imm_ptr     [`IQ_ENT_NUM-1:0];
    reg [`PB_ENT_SEL-1:0]       pc_ptr      [`IQ_ENT_NUM-1:0];
    reg [`PAB_ENT_SEL-1:0]      pra_ptr     [`IQ_ENT_NUM-1:0];
    reg [`SRC_A_SEL_WIDTH-1:0]  src_a_sel   [`IQ_ENT_NUM-1:0];
    reg [`SRC_B_SEL_WIDTH-1:0]  src_b_sel   [`IQ_ENT_NUM-1:0];
    
    wire                    reallocated_1;
    wire                    reallocated_2;
    wire                    reallocated_3;

    wire                    request1        [`IQ_ENT_NUM-1:0];
    wire                    request2        [`IQ_ENT_NUM-1:0];
    wire                    request3        [`IQ_ENT_NUM-1:0];
    reg [`IQ_ENT_NUM-1:0]   request1_vec;
    reg [`IQ_ENT_NUM-1:0]   request2_vec;
    reg [`IQ_ENT_NUM-1:0]   request3_vec;

    wire                    broadcast_enable1;
    wire                    broadcast_enable2;
    wire                    broadcast_enable3;
    wire [`PHY_REG_SEL-1:0] broadcast_tag1;
    wire [`PHY_REG_SEL-1:0] broadcast_tag2;
    wire [`PHY_REG_SEL-1:0] broadcast_tag3;

    wire                    src1_match1;
    wire                    src1_match2;
    wire                    src1_match3;
    wire                    src2_match1;
    wire                    src2_match2;
    wire                    src2_match3;
    wire                    match1_result   [`IQ_ENT_NUM-1:0];
    wire                    match2_result   [`IQ_ENT_NUM-1:0];
    
    // at most 3 instruction can be selected
    wire                    grant1;
    wire                    grant2;
    wire                    grant3;
    wire [`IQ_ENT_SEL-1:0]  sel_ent_1;
    wire [`IQ_ENT_SEL-1:0]  sel_ent_2;
    wire [`IQ_ENT_SEL-1:0]  sel_ent_3;

    reg [`IQ_ENT_SEL:0]     k;
    reg [`IQ_ENT_SEL:0]     l;
    reg [`IQ_ENT_SEL:0]     m;
    reg [`IQ_ENT_SEL:0]     n;

    assign reallocated_1 = (~invalid1 && (sel_ent_1 == iq_entry_num_1))
                        || (~invalid2 && (sel_ent_1 == iq_entry_num_2));
    assign reallocated_2 = (~invalid1 && (sel_ent_2 == iq_entry_num_1))
                        || (~invalid2 && (sel_ent_2 == iq_entry_num_2));
    assign reallocated_3 = (~invalid1 && (sel_ent_3 == iq_entry_num_1))
                        || (~invalid2 && (sel_ent_3 == iq_entry_num_2));

    always @ (posedge clk)  begin
        if (reset) begin
            for (l = 0; l < `IQ_ENT_NUM; l++) begin
                valid[l] <= 0;
            end
        end else begin
            if (prmiss) begin
                // branch misprediction
            end else begin
                if (~stall_DP) begin
                    // allocate wakeup logic entry and payload RAM
                    if (~invalid1) begin
                        valid[iq_entry_num_1] <= 1;
                        src1[iq_entry_num_1] <= src1_1;
                        src2[iq_entry_num_1] <= src2_1;
                        match1[iq_entry_num_1] <= match1_1;
                        match2[iq_entry_num_1] <= match2_1;
                        shift_r1[iq_entry_num_1] <= shift_r1_1;
                        shift_r2[iq_entry_num_1] <= shift_r2_1;
                        delay1[iq_entry_num_1] <= delay1_1;
                        delay2[iq_entry_num_1] <= delay2_1;
                        dst[iq_entry_num_1] <= dst_1;
                        port_num[iq_entry_num_1] <= port_num_1;
                        wr_reg[iq_entry_num_1] <= wr_reg_1;
                        alu_op[iq_entry_num_1] <= alu_op_1;
                        rob_num[iq_entry_num_1] <= rob_num_1;
                        lq_idx[iq_entry_num_1] <= lq_idx_1;
                        sq_idx[iq_entry_num_1] <= sq_idx_1;
                        inst_type[iq_entry_num_1] <= inst_type_1;
                        imm_ptr[iq_entry_num_1] <= imm_ptr_1;
                        pc_ptr[iq_entry_num_1] <= pc_ptr_1;
                        pra_ptr[iq_entry_num_1] <= pra_ptr_1;
                        src_a_sel[iq_entry_num_1] <= src_a_sel_1;
                        src_b_sel[iq_entry_num_1] <= src_b_sel_1;
                    end
                    if (~invalid2) begin
                        valid[iq_entry_num_2] <= 1;
                        src1[iq_entry_num_2] <= src1_1;
                        src2[iq_entry_num_2] <= src2_1;
                        match1[iq_entry_num_2] <= match1_1;
                        match2[iq_entry_num_2] <= match2_1;
                        shift_r1[iq_entry_num_2] <= shift_r1_1;
                        shift_r2[iq_entry_num_2] <= shift_r2_1;
                        delay1[iq_entry_num_2] <= delay1_1;
                        delay2[iq_entry_num_2] <= delay2_1;
                        dst[iq_entry_num_2] <= dst_1;
                        port_num[iq_entry_num_2] <= port_num_1;
                        wr_reg[iq_entry_num_2] <= wr_reg_2;
                        alu_op[iq_entry_num_2] <= alu_op_2;
                        rob_num[iq_entry_num_2] <= rob_num_2;
                        lq_idx[iq_entry_num_2] <= lq_idx_2;
                        sq_idx[iq_entry_num_2] <= sq_idx_2;
                        inst_type[iq_entry_num_2] <= inst_type_2;
                        imm_ptr[iq_entry_num_2] <= imm_ptr_2;
                        pc_ptr[iq_entry_num_2] <= pc_ptr_2;
                        pra_ptr[iq_entry_num_2] <= pra_ptr_2;
                        src_a_sel[iq_entry_num_2] <= src_a_sel_2;
                        src_b_sel[iq_entry_num_2] <= src_b_sel_2;
                    end
                end
            end

            // match bit is set if src tags match with broadcasted dst tag through CAM search
            // if set, do arithmetic right shift shift_r, eventually set R bit
            for (m = 0; m < `IQ_ENT_NUM; m++) begin
                if (match1_result[m]) begin
                    match1[m] <= 1;
                    shift_r1[m] <= delay1[m];
                end
                if (match2_result[m]) begin
                    match2[m] <= 1;
                    shift_r2[m] <= delay2[m];
                end
                if (match1[m]) begin
                    shift_r1[m] <= shift_r1[m] >>> 1;
                end
                if (match2[m]) begin
                    shift_r2[m] <= shift_r2[m] >>> 1;
                end
            end

            // release issue queue entries when selected
            if (grant1 && ~reallocated_1) begin
                valid[sel_ent_1] <= 0;
            end
            if (grant2 && ~reallocated_2) begin
                valid[sel_ent_2] <= 0;
            end
            if (grant3 && ~reallocated_3) begin
                valid[sel_ent_3] <= 0;
            end
        end
    end

    always @ (posedge clk) begin
        // if rob wrap_around occurs, set all sorting bits
        if (wrap_around) begin
            for (n = 0; n < `IQ_ENT_NUM; n++) begin
                sorting_bit[n] = 1;
            end
        end
        sorting_bit[rob_num_1] = rob_sorting_bit_1;
        sorting_bit[rob_num_2] = rob_sorting_bit_2;
    end
    

    // Wakeup && Select Logic
    genvar i, j;
    generate
        // send request signals to the corresponding select logic when ready
        for (j = 0; j < `IQ_ENT_NUM; j = j + 1) begin
            assign request1[j] = valid[j] && (port_num[j] == 2'b00)
                            && (shift_r1[j][0] && shift_r2[j][0]);
            assign request2[j] = valid[j] && (port_num[j] == 2'b01)
                            && (shift_r1[j][0] && shift_r2[j][0]);
            assign request3[j] = valid[j] && (port_num[j] == 2'b10)
                            && (shift_r1[j][0] && shift_r2[j][0]);
        end
    endgenerate

    // array to vector transition for prefix-sum select module
    // this ensures select logic to synchronize
    always @ (negedge clk) begin
        for (k = 0; k < `IQ_ENT_NUM; k++) begin
            request1_vec[k] <= request1[k];
            request2_vec[k] <= request2[k];
            request3_vec[k] <= request3[k];
        end
    end
    
    // prefix-sum circuit per each issue port
    prefix_sum prefix_sum_1(
        .request(request1_vec),
        .grant(grant1),
        .selected_ent(sel_ent_1)
    );

    prefix_sum prefix_sum_2(
        .request(request2_vec),
        .grant(grant2),
        .selected_ent(sel_ent_2)
    );

    prefix_sum prefix_sum_3(
        .request(request3_vec),
        .grant(grant3),
        .selected_ent(sel_ent_3)
    );
    
    assign broadcast_enable1 = grant1 && sel_wr_reg_1;
    assign broadcast_enable2 = grant2 && sel_wr_reg_2;
    assign broadcast_enable3 = grant3 && sel_wr_reg_3;

    assign broadcast_tag1 = dst[sel_ent_1];
    assign broadcast_tag2 = dst[sel_ent_2];
    assign broadcast_tag3 = dst[sel_ent_3];

    generate
        // compare source tags with broadcasted dst tags (wakeup logic CAM search)
        for (i = 0; i < `IQ_ENT_NUM; i = i + 1) begin
            assign src1_match1 = broadcast_enable1 && (src1[i] == broadcast_tag1);
            assign src1_match2 = broadcast_enable2 && (src1[i] == broadcast_tag2);
            assign src1_match3 = broadcast_enable3 && (src1[i] == broadcast_tag3);
            assign match1_result[i] = valid[i] && (src1_match1 || src1_match2 || src1_match3);

            assign src2_match1 = broadcast_enable1 && (src2[i] == broadcast_tag1);
            assign src2_match2 = broadcast_enable2 && (src2[i] == broadcast_tag2);
            assign src2_match3 = broadcast_enable3 && (src2[i] == broadcast_tag3);
            assign match2_result[i] = valid[i] && (src2_match1 || src2_match2 || src2_match3);
        end
    endgenerate

    // broadcast to scoreborad
    assign bc_enable1 = broadcast_enable1;
    assign bc_enable2 = broadcast_enable2;
    assign bc_enable3 = broadcast_enable3;
    assign bc_tag1 = broadcast_tag1;
    assign bc_tag2 = broadcast_tag2;
    assign bc_tag3 = broadcast_tag3;

    // read information from Payload RAM
    always @ (posedge clk) begin
        // Issue Port 1
        sel_grant_1 = grant1;
        sel_src1_1 = src1[sel_ent_1];
        sel_src2_1 = src2[sel_ent_1];
        sel_dst_1 = dst[sel_ent_1];
        sel_wr_reg_1 = wr_reg[sel_ent_1];
        sel_alu_op_1 = alu_op[sel_ent_1];
        sel_sorting_bit_1 = sorting_bit[sel_ent_1];
        sel_rob_num_1 = rob_num[sel_ent_1];
        sel_inst_type_1 = inst_type[sel_ent_1];
        sel_imm_ptr_1 = imm_ptr[sel_ent_1];
        sel_src_a_sel_1 = src_a_sel[sel_ent_1];
        sel_src_b_sel_1 = src_b_sel[sel_ent_1];
        // Issue Port 2
        sel_grant_2 = grant2;
        sel_src1_2 = src1[sel_ent_2];
        sel_src2_2 = src2[sel_ent_2];
        sel_dst_2 = dst[sel_ent_2];
        sel_wr_reg_2 = wr_reg[sel_ent_2];
        sel_alu_op_2 = alu_op[sel_ent_2];
        sel_sorting_bit_2 = sorting_bit[sel_ent_2];
        sel_rob_num_2 = rob_num[sel_ent_2];
        sel_inst_type_2 = inst_type[sel_ent_2];
        sel_imm_ptr_2 = imm_ptr[sel_ent_2];
        sel_pc_ptr_2 = pc_ptr[sel_ent_2];
        sel_pra_ptr_2 = pra_ptr[sel_ent_2];
        sel_src_a_sel_2 = src_a_sel[sel_ent_2];
        sel_src_b_sel_2 = src_b_sel[sel_ent_2];
        // Issue Port 3
        sel_grant_3 = grant3;
        sel_src1_3 = src1[sel_ent_3];
        sel_src2_3 = src2[sel_ent_3];
        sel_dst_3 = dst[sel_ent_3];
        sel_wr_reg_3 = wr_reg[sel_ent_3];
        sel_alu_op_3 = alu_op[sel_ent_3];
        sel_sorting_bit_3 = sorting_bit[sel_ent_3];
        sel_rob_num_3 = rob_num[sel_ent_3];
        sel_iq_idx_3 = lq_idx[sel_ent_3];
        sel_sq_idx_3 = sq_idx[sel_ent_3];
        sel_inst_type_3 = inst_type[sel_ent_3];
        sel_imm_ptr_3 = imm_ptr[sel_ent_3];
        sel_pc_ptr_3 = pc_ptr[sel_ent_3];
        sel_src_a_sel_3 = src_a_sel[sel_ent_3];
        sel_src_b_sel_3 = src_b_sel[sel_ent_3];
    end
endmodule