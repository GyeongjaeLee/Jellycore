`include "constants.vh"
`default_nettype none
// recovery is not implemented yet
module frontend_RAT (
    input wire                  clk,
    input wire [`REG_SEL-1:0]   rs1_1,
    input wire [`REG_SEL-1:0]   rs2_1,
    input wire [`REG_SEL-1:0]   rs1_2,
    input wire [`REG_SEL-1:0]   rs2_2,
    input wire [`REG_SEL-1:0]   dst1,
    input wire [`REG_SEL-1:0]   dst2,
    input wire [`PHY_REG_SEL-1:0]   phy_dst_1,
    input wire [`PHY_REG_SEL-1:0]   phy_dst_2,
    input wire                      phy_dst_valid_1,
    input wire                      phy_dst_valid_2,
    input wire                      prmiss,
    output reg [`PHY_REG_SEL-1:0]   phy_src1_1,
    output reg [`PHY_REG_SEL-1:0]   phy_src2_1,
    output reg [`PHY_REG_SEL-1:0]   phy_src1_2,
    output reg [`PHY_REG_SEL-1:0]   phy_src2_2,
    output reg [`PHY_REG_SEL-1:0]   phy_ori_dst_1,
    output reg [`PHY_REG_SEL-1:0]   phy_ori_dst_2
    );

    reg [`PHY_REG_SEL-1:0]      frontend_rat [`REG_SEL-1:0];
    
    always @ (posedge clk) begin
        if (prmiss) begin
            // dealing with branch misprediction
        end else begin
            if (phy_dst_valid_1)
                frontend_rat[dst1] <= phy_dst_1;
            if (phy_dst_valid_2)
                frontend_rat[dst2] <= phy_dst_2;
        end
    end

    always @ (negedge clk) begin
        phy_src1_1 <= frontend_rat[rs1_1];
        phy_src2_1 <= frontend_rat[rs2_1];
        phy_src1_2 <= frontend_rat[rs1_2];
        phy_src2_2 <= frontend_rat[rs2_2];
        phy_ori_dst_1 <= frontend_rat[dst1];
        phy_ori_dst_1 <= frontend_rat[dst2];
    end



endmodule