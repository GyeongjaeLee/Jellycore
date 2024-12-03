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

    wire                    match1_result   [`IQ_ENT_NUM-1:0];
    wire                    match2_result   [`IQ_ENT_NUM-1:0];
    wire                    request         [`IQ_ENT_NUM-1:0];
    // at most 2 instruction can be selected
    wire [`PHY_REG_SEL-1:0] broadcast_tag1;
    wire [`PHY_REG_SEL-1:0] broadcast_tag2;

    reg [`IQ_ENT_SEL:0]     j;
    reg [`IQ_ENT_SEL:0]     k;

    genvar i;
    generate
        for (i = 0; i < `IQ_ENT_NUM; i = i + 1) begin
            // wakeup logic CAM search
            assign match1_result[i] = valid[i]
                && ((src1[i] == broadcast_tag1) || (src1[i] == broadcast_tag2));
            assign match2_result[i] = valid[i]
                && ((src2[i] == broadcast_tag1) || (src2[i] == broadcast_tag2));
            assign request[i] = shift_r1[i][0] && shift_r2[i][0];
            // select logic

        end
    endgenerate

    always @ (posedge clk)  begin
        if (reset) begin
            for (j = 0; j < `IQ_ENT_NUM; j++) begin
                valid[j] <= 0;
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
                    shift_r1[iq_entry_num_1] <= shift_r1_1;
                    shift_r2[iq_entry_num_1] <= shift_r2_1;
                    delay1[iq_entry_num_1] <= delay1_1;
                    delay2[iq_entry_num_1] <= delay2_1;
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
                    shift_r1[iq_entry_num_2] <= shift_r1_1;
                    shift_r2[iq_entry_num_2] <= shift_r2_1;
                    delay1[iq_entry_num_2] <= delay1_1;
                    delay2[iq_entry_num_2] <= delay2_1;
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
            for (j = 0; j < `IQ_ENT_NUM; j++) begin
                if (match1_result[j]) begin
                    match1[j] <= 1;
                    shift_r1[j] <= delay1[j];
                end
                if (match2_result[j]) begin
                    match2[j] <= 1;
                    shift_r2[j] <= delay2[j];
                end
                if (match1[j]) begin
                    shift_r1[j] <= shift_r1[j] >>> 1;
                end
                if (match2[j]) begin
                    shift_r2[j] <= shift_r2[j] >>> 1;
                end
            end

        end
    
    end


    always @ (posedge clk) begin
        // if rob wrap_around occurs, set all sorting bits
        if (wrap_around) begin
            for (k = 0; k < `IQ_ENT_NUM; k++) begin
                sorting_bit[k] = 1;
            end
        end
        sorting_bit[rob_num_1] = rob_sorting_bit_1;
        sorting_bit[rob_num_2] = rob_sorting_bit_2;
    end

endmodule