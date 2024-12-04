`include "constants.vh"
`include "alu_ops.vh"
`default_nettype none
// recovery is not implemented yet
module scoreboard(
    input wire                      clk,
    input wire                      reset,
    // dispatch
    input wire                      invalid1,
    input wire                      invalid2,
    input wire [`PHY_REG_SEL-1:0]   src1_1,
    input wire [`PHY_REG_SEL-1:0]   src2_1,
    input wire [`PHY_REG_SEL-1:0]   src1_2,
    input wire [`PHY_REG_SEL-1:0]   src2_2,
    output wire                     match1_1,
    output wire                     match2_1,
    output wire                     match1_2,
    output wire                     match2_2,
    output wire [`MAX_LATENCY-1:0]  shift_r1_1,
    output wire [`MAX_LATENCY-1:0]  shift_r2_1,
    output wire [`MAX_LATENCY-1:0]  shift_r1_2,
    output wire [`MAX_LATENCY-1:0]  shift_r2_2,
    output wire [`MAX_LATENCY-1:0]  delay1_1,
    output wire [`MAX_LATENCY-1:0]  delay2_1,
    output wire [`MAX_LATENCY-1:0]  delay1_2,
    output wire [`MAX_LATENCY-1:0]  delay2_2,
    input wire [`PHY_REG_SEL-1:0]   dst_1,
    input wire [`PHY_REG_SEL-1:0]   dst_2,
    input wire                      wr_reg_1,
    input wire                      wr_reg_2,
    input wire [`RS_ENT_SEL-1:0]    inst_type_1,
    input wire [`RS_ENT_SEL-1:0]    inst_type_2,
    // destination tag broadcasted
    input wire                      bc_valid_1,
    input wire                      bc_valid_2,
    input wire [`PHY_REG_SEL-1:0]   bc_dst_1,
    input wire [`PHY_REG_SEL-1:0]   bc_dst_2
    );
    
    reg                     match   [`PHY_REG_NUM-1:0];
    reg [`MAX_LATENCY-1:0]  shift_r [`PHY_REG_NUM-1:0];
    reg [`MAX_LATENCY-1:0]  delay   [`PHY_REG_NUM-1:0];


    // check readiness of src register and assign wakeup logic entry in dispatch stage
    assign match1_1 = match[src1_1];
    assign match2_1 = match[src2_1];
    assign shift_r1_1 = shift_r[src1_1];
    assign shift_r2_1 = shift_r[src2_1];
    assign delay1_1 = delay[src1_1];
    assign delay2_1 = delay[src2_1];

    assign match1_2 = match[src1_2];
    assign match2_2 = match[src2_2];
    assign shift_r1_2 = shift_r[src1_2];
    assign shift_r2_2 = shift_r[src2_2];
    assign delay1_2 = delay[src1_2];
    assign delay2_2 = delay[src2_2];

    genvar g;
    generate
        for (g = 0; g < `PHY_REG_NUM; g = g + 1) begin
            always @ (posedge clk) begin
                if (bc_valid_1) begin
                    shift_r[bc_dst_1] <= delay[bc_dst_1];
                end
                if (bc_valid_2) begin
                    shift_r[bc_dst_2] <= delay[bc_dst_2];
                end
                // do arithmatic right shift when match bit is set
                if (~shift_r[g][0] && match[g]) begin
                    shift_r[g] <= shift_r[g] >>> 1;
                end
            end
        end
    endgenerate

    always @ (negedge clk) begin
        // Dispatch
        // update scoreboard according to instruction type (latency)
        if (~invalid1 && wr_reg_1) begin
            match[dst_1] <= 0;
            case(inst_type_1)
                `RS_ENT_ALU :       delay[dst_1] <= {`MAX_LATENCY{1'b1}};
                `RS_ENT_BRANCH :    delay[dst_1] <= {`MAX_LATENCY{1'b1}};
                `RS_ENT_MUL :       delay[dst_1] <= {2'b11,{(`MAX_LATENCY-2){1'b0}}};
                `RS_ENT_LDST :      delay[dst_1] <= {1'b1,{(`MAX_LATENCY-1){1'b0}}};
                default :           delay[dst_1] <= {`MAX_LATENCY{1'b0}};
            endcase
        end
        if (~invalid2 && wr_reg_2) begin
            match[dst_2] <= 0;
            case(inst_type_2)
                `RS_ENT_ALU :       delay[dst_2] <= {`MAX_LATENCY{1'b1}};
                `RS_ENT_BRANCH :    delay[dst_2] <= {`MAX_LATENCY{1'b1}};
                `RS_ENT_MUL :       delay[dst_2] <= {2'b11,{(`MAX_LATENCY-2){1'b0}}};
                `RS_ENT_LDST :      delay[dst_2] <= {1'b1,{(`MAX_LATENCY-1){1'b0}}};
                default :           delay[dst_2] <= {`MAX_LATENCY{1'b0}};
            endcase
        end

        // set match bit when destination tag is broadcasted
        if (bc_valid_1) begin
            match[bc_dst_1] <= 1;
        end
        if (bc_valid_2) begin
            match[bc_dst_2] <= 1;
        end
    end
    
endmodule
