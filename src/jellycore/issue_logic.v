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
    input wire [`RS_ENT_SEL-1:0]    inst_type_1,
    input wire [`RS_ENT_SEL-1:0]    inst_type_2,
    input wire                      alu_op_1,
    input wire                      alu_op_2,
    input wire [`PHY_REG_SEL-1:0]   src1_1,
    input wire [`PHY_REG_SEL-1:0]   src2_1,
    input wire [`PHY_REG_SEL-1:0]   src1_2,
    input wire [`PHY_REG_SEL-1:0]   src2_2,
    input wire                      shift_r1_1,
    input wire                      shift_r2_1,
    input wire                      shift_r1_2,
    input wire                      shift_r2_2,
    input wire                      match1_1,
    input wire                      match2_1,
    input wire                      match1_2,
    input wire                      match2_2,
    input wire                      delay1_1,
    input wire                      delay2_1,
    input wire                      delay1_2,
    input wire                      delay2_2,
    input wire [`PHY_REG_SEL-1:0]   dst_1,
    input wire [`PHY_REG_SEL-1:0]   dst_2,
    input wire [`IB_ENT_SEL-1:0]    imm_ptr_1,
    input wire [`IB_ENT_SEL-1:0]    imm_ptr_2,
    input wire                      stall_DP,
    // misprediction triggers rob_num comparison to flush instructions in the wrong path
    input wire [`ROB_SEL-1:0]       rob_num_1,
    input wire [`ROB_SEL-1:0]       rob_num_2,
    input wire                      rob_sorting_bit_1,
    input wire                      rob_sorting_bit_2,
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
    reg [`ROB_SEL-1:0]          rob_num     [`IQ_ENT_NUM-1:0];
    reg [`LQ_SEL-1:0]           lq_idx      [`IQ_ENT_NUM-1:0];
    reg [`SQ_SEL-1:0]           sq_idx      [`IQ_ENT_NUM-1:0];
    reg [`RS_ENT_SEL-1:0]       inst_type   [`IQ_ENT_NUM-1:0];
    reg [`IB_ENT_SEL-1:0]       imm_ptr     [`IQ_ENT_NUM-1:0];
    
    // each entry forms its own always block
    genvar i;
    generate
        for (i = 0; i < `IQ_ENT_NUM; i = i + 1) begin
            always @ (posedge clk) begin
                if (reset) begin
                    valid[i] <= 0;
                    match1[i] <= 0;
                    match2[i] <= 0;
                    shift_r1[i] <= 0;
                    shift_r2[i] <= 0;
                    delay1[i] <= 0;
                    delay2[i] <= 0;
                end else if (prmiss) begin
                    // prmiss
                end else begin
                    // allocation
                    if(~stall_DP) begin
                        if (i == iq_entry_num_1 && ~invalid1) begin
                            valid[i] <= 1;
                            src1[i] <= src1_1;
                            src2[i] <= src2_1;
                            match1[i] <= match1_1;
                            match2[i] <= match2_1;
                            shift_r1[i] <= shift_r1_1;
                            shift_r2[i] <= shift_r2_1;
                            delay1[i] <= delay1_1;
                            delay2[i] <= delay2_1;
                            dst[i] <= dst_1;
                            port_num[i] <= port_num_1;
                        end
                        if (i == iq_entry_num_2 && ~invalid2) begin
                            valid[i] <= 1;
                            src1[i] <= src1_2;
                            src2[i] <= src2_2;
                            match1[i] <= match1_2;
                            match2[i] <= match2_2;
                            shift_r1[i] <= shift_r1_2;
                            shift_r2[i] <= shift_r2_2;
                            delay1[i] <= delay1_2;
                            delay2[i] <= delay2_2;
                            dst[i] <= dst_2;
                            port_num[i] <= port_num_2;
                        end
                    end

                    //wakeup
                end
            end
        end
    endgenerate

    
endmodule