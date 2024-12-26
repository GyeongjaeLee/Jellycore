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
    input wire                      uses_rs1_1,
    input wire                      uses_rs2_1,
    input wire                      uses_rs1_2,
    input wire                      uses_rs2_2,
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
    input wire                      stall_DP,
    input wire [`LQ_SEL-1:0]        lq_idx_1,
    input wire [`LQ_SEL-1:0]        lq_idx_2,
    input wire [`SQ_SEL-1:0]        sq_idx_1,
    input wire [`SQ_SEL-1:0]        sq_idx_2,
    // misprediction triggers rob_num comparison to flush instructions in the wrong path
    input wire [`ROB_SEL-1:0]       rob_num_1,
    input wire [`ROB_SEL-1:0]       rob_num_2,
    input wire                      rob_sorting_bit_1,
    input wire                      rob_sorting_bit_2,
    input wire                      wrap_around,
    input wire [`ROB_SEL-1:0]       prmiss_rob_num,
    input wire                      prmiss_rob_sorting_bit,
    input wire                      prmiss,
    // selected instructions to execute
    output reg [`PHY_REG_SEL-1:0]   sel_src1_1,
    output reg [`PHY_REG_SEL-1:0]   sel_src2_1,
    output reg [`PHY_REG_SEL-1:0]   sel_src1_2,
    output reg [`PHY_REG_SEL-1:0]   sel_src2_2,
    output reg [`PHY_REG_SEL-1:0]   sel_dst_1,
    output reg [`PHY_REG_SEL-1:0]   sel_dst_2,
    output reg [`ALU_OP_WIDTH-1:0]  sel_alu_op_1,
    output reg [`ALU_OP_WIDTH-1:0]  sel_alu_op_2,
    output wire                     allocatable_FU
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
    reg [`ALU_OP_WIDTH-1:0]     alu_op      [`IQ_ENT_NUM-1:0];
    reg                         sorting_bit [`IQ_ENT_NUM-1:0];
    reg [`ROB_SEL-1:0]          rob_num     [`IQ_ENT_NUM-1:0];
    reg [`LQ_SEL-1:0]           lq_idx      [`IQ_ENT_NUM-1:0];
    reg [`SQ_SEL-1:0]           sq_idx      [`IQ_ENT_NUM-1:0];
    reg [`RS_ENT_SEL-1:0]       inst_type   [`IQ_ENT_NUM-1:0];
    reg [`IB_ENT_SEL-1:0]       imm_ptr     [`IQ_ENT_NUM-1:0];
    reg [`PB_ENT_SEL-1:0]       pc_ptr      [`IQ_ENT_NUM-1:0];
    reg [`SRC_A_SEL_WIDTH-1:0]  src_a_sel   [`IQ_ENT_NUM-1:0];
    reg [`SRC_B_SEL_WIDTH-1:0]  src_b_sel   [`IQ_ENT_NUM-1:0];

    wire [`MAX_LATENCY-1:0] shift_r1_1_use;
    wire [`MAX_LATENCY-1:0] shift_r2_1_use;
    wire [`MAX_LATENCY-1:0] shift_r1_2_use;
    wire [`MAX_LATENCY-1:0] shift_r2_2_use;
    wire [`MAX_LATENCY-1:0] delay1_1_use;
    wire [`MAX_LATENCY-1:0] delay2_1_use;
    wire [`MAX_LATENCY-1:0] delay1_2_use;
    wire [`MAX_LATENCY-1:0] delay2_2_use;

    wire                    match1_result   [`IQ_ENT_NUM-1:0];
    wire                    match2_result   [`IQ_ENT_NUM-1:0];
    wire                    request1        [`IQ_ENT_NUM-1:0];
    wire                    request2        [`IQ_ENT_NUM-1:0];
    wire                    request3        [`IQ_ENT_NUM-1:0];
    wire [`IQ_ENT_NUM-1:0]  request1_vec;
    wire [`IQ_ENT_NUM-1:0]  request2_vec;
    wire [`IQ_ENT_NUM-1:0]  request3_vec;
    // at most 3 instruction can be selected
    wire                    grant1;
    wire                    grant2;
    wire                    grant3;
    wire [`IQ_ENT_SEL-1:0]  selected_ent_1;
    wire [`IQ_ENT_SEL-1:0]  selected_ent_2;
    wire [`IQ_ENT_SEL-1:0]  selected_ent_3;

    wire [`PHY_REG_SEL-1:0] broadcast_tag1;
    wire [`PHY_REG_SEL-1:0] broadcast_tag2;
    wire [`PHY_REG_SEL-1:0] broadcast_tag3;

    reg [`IQ_ENT_SEL:0]     l;
    reg [`IQ_ENT_SEL:0]     m;
    reg [`IQ_ENT_SEL:0]     n;

    // ignore source tag readiness when insts don't use register source operands
    assign shift_r1_1_use = uses_rs1_1 ? shift_r1_1 : {{`MAX_LATENCY{1'b1}}};
    assign shift_r2_1_use = uses_rs2_1 ? shift_r2_1 : {{`MAX_LATENCY{1'b1}}};
    assign shift_r1_2_use = uses_rs1_2 ? shift_r1_2 : {{`MAX_LATENCY{1'b1}}};
    assign shift_r2_2_use = uses_rs2_2 ? shift_r2_2 : {{`MAX_LATENCY{1'b1}}};
    assign delay1_1_use = uses_rs1_1 ? delay1_1 : {{`MAX_LATENCY{1'b1}}};
    assign delay2_1_use = uses_rs2_1 ? delay2_1 : {{`MAX_LATENCY{1'b1}}};
    assign delay1_2_use = uses_rs1_2 ? delay1_2 : {{`MAX_LATENCY{1'b1}}};
    assign delay2_2_use = uses_rs2_2 ? delay2_2 : {{`MAX_LATENCY{1'b1}}};

    always @ (posedge clk)  begin
        if (reset) begin
            for (l = 0; l < `IQ_ENT_NUM; l++) begin
                valid[l] <= 0;
            end
        end else if (prmiss) begin
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
                    shift_r1[iq_entry_num_1] <= shift_r1_1_use;
                    shift_r2[iq_entry_num_1] <= shift_r2_1_use;
                    delay1[iq_entry_num_1] <= delay1_1_use;
                    delay2[iq_entry_num_1] <= delay2_1_use;
                    dst[iq_entry_num_1] <= dst_1;
                    port_num[iq_entry_num_1] <= port_num_1;
                    alu_op[iq_entry_num_1] <= alu_op_1;
                    rob_num[iq_entry_num_1] <= rob_num_1;
                    lq_idx[iq_entry_num_1] <= lq_idx_1;
                    sq_idx[iq_entry_num_1] <= sq_idx_1;
                    inst_type[iq_entry_num_1] <= inst_type_1;
                    imm_ptr[iq_entry_num_1] <= imm_ptr_1;
                    pc_ptr[iq_entry_num_1] <= pc_ptr_1;
                    src_a_sel[iq_entry_num_1] <= src_a_sel_1;
                    src_b_sel[iq_entry_num_1] <= src_b_sel_1;
                end
                if (~invalid2) begin
                    valid[iq_entry_num_2] <= 1;
                    src1[iq_entry_num_2] <= src1_1;
                    src2[iq_entry_num_2] <= src2_1;
                    match1[iq_entry_num_2] <= match1_1;
                    match2[iq_entry_num_2] <= match2_1;
                    shift_r1[iq_entry_num_2] <= shift_r1_1_use;
                    shift_r2[iq_entry_num_2] <= shift_r2_1_use;
                    delay1[iq_entry_num_2] <= delay1_1_use;
                    delay2[iq_entry_num_2] <= delay2_1_use;
                    dst[iq_entry_num_2] <= dst_1;
                    port_num[iq_entry_num_2] <= port_num_1;
                    alu_op[iq_entry_num_2] <= alu_op_2;
                    rob_num[iq_entry_num_2] <= rob_num_2;
                    lq_idx[iq_entry_num_2] <= lq_idx_2;
                    sq_idx[iq_entry_num_2] <= sq_idx_2;
                    inst_type[iq_entry_num_2] <= inst_type_2;
                    imm_ptr[iq_entry_num_2] <= imm_ptr_2;
                    pc_ptr[iq_entry_num_2] <= pc_ptr_2;
                    src_a_sel[iq_entry_num_2] <= src_a_sel_2;
                    src_b_sel[iq_entry_num_2] <= src_b_sel_2;
                end
            end
            // match bit set if src tags match with broadcasted dst tag through CAM search
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
        end
    end

    genvar i, j, k;
    generate
        // compare source tags with broadcasted dst tags (wakeup logic CAM search)
        for (i = 0; i < `IQ_ENT_NUM; i = i + 1) begin
            assign match1_result[i] = valid[i] && ((src1[i] == broadcast_tag1)
                || (src1[i] == broadcast_tag2) || (src1[i] == broadcast_tag3));
            assign match2_result[i] = valid[i] && ((src2[i] == broadcast_tag1)
                || (src2[i] == broadcast_tag2) || (src2[i] == broadcast_tag3));
        end

        // send request signals to the corresponding select logic when ready
        for (j = 0; j < `IQ_ENT_NUM; j = j + 1) begin
            assign request1[j] = valid[j] && (port_num[j] == 2'b00)
                            && (shift_r1[j][0] && shift_r2[j][0]);
            assign request2[j] = valid[j] && (port_num[j] == 2'b01)
                            && (shift_r1[j][0] && shift_r2[j][0]);
            assign request3[j] = valid[j] && (port_num[j] == 2'b10)
                            && (shift_r1[j][0] && shift_r2[j][0]);
        end

        // array to vector transition for prefix-sum select module
        for (k = 0; k < `IQ_ENT_NUM; k = k + 1) begin
            assign request1_vec[k] = request1[k];
            assign request2_vec[k] = request2[k];
            assign request3_vec[k] = request3[k];
        end
    endgenerate

    prefix_sum prefix_sum_1(
        .request(request1_vec),
        .grant(grant1),
        .selected_ent(selected_ent_1)
    );

    prefix_sum prefix_sum_2(
        .request(request2_vec),
        .grant(grant2),
        .selected_ent(selected_ent_2)
    );

    prefix_sum prefix_sum_3(
        .request(request3_vec),
        .grant(grant3),
        .selected_ent(selected_ent_3)
    );

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

endmodule