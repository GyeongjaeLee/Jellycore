`include "constants.vh"

module renaming_logic (
    input wire                      clk,
    input wire                      reset,
    input wire                      uses_rs1_1,
    input wire                      uses_rs2_1,
    input wire                      uses_rs1_2,
    input wire                      uses_rs2_2,
    input wire                      phy_dst_valid_1,
    input wire                      phy_dst_valid_2,
    input wire [`REG_SEL-1:0]       src1_1,
    input wire [`REG_SEL-1:0]       src2_1,
    input wire [`REG_SEL-1:0]       src1_2,
    input wire [`REG_SEL-1:0]       src2_2,
    input wire [`REG_SEL-1:0]       dst_1,
    input wire [`REG_SEL-1:0]       dst_2,
    input wire [`PHY_REG_SEL-1:0]   phy_src1_1_from_rat,
    input wire [`PHY_REG_SEL-1:0]   phy_src2_1_from_rat,
    input wire [`PHY_REG_SEL-1:0]   phy_src1_2_from_rat,
    input wire [`PHY_REG_SEL-1:0]   phy_src2_2_from_rat,
    input wire [`PHY_REG_SEL-1:0]   phy_dst_1_from_rat,
    input wire [`PHY_REG_SEL-1:0]   phy_dst_2_from_rat,
    input wire [`PHY_REG_SEL-1:0]   phy_dst_1_from_free_list,
    input wire [`PHY_REG_SEL-1:0]   phy_dst_2_from_free_list,
    output reg                      WAW_valid,
    output reg [`PHY_REG_SEL-1:0]   phy_dst_1,
    output reg [`PHY_REG_SEL-1:0]   phy_dst_2,
    output reg [`PHY_REG_SEL-1:0]   phy_src1_1,
    output reg [`PHY_REG_SEL-1:0]   phy_src2_1,
    output reg [`PHY_REG_SEL-1:0]   phy_src1_2,
    output reg [`PHY_REG_SEL-1:0]   phy_src2_2
);

    always @(*) begin
        // Initialize outputs
        phy_dst_1 = {`PHY_REG_SEL{1'b0}};
        phy_dst_2 = {`PHY_REG_SEL{1'b0}};
        phy_src1_1 = phy_src1_1_from_rat; // Default mapping from RAT
        phy_src2_1 = phy_src2_1_from_rat;
        phy_src1_2 = phy_src1_2_from_rat;
        phy_src2_2 = phy_src2_2_from_rat;

        // Rename destination registers only if valid
        if (phy_dst_valid_1) begin
            phy_dst_1 = phy_dst_1_from_free_list;
        end
        if (phy_dst_valid_2) begin
            phy_dst_2 = phy_dst_2_from_free_list;
        end

        // Handle WAW dependency
        if (phy_dst_valid_1 && phy_dst_valid_2 && (dst_1 == dst_2)) begin
            WAW_valid = 1'b1;
        end

        // Handle RAW dependency (Forwarding for Instruction 2)
        if (uses_rs1_2) begin
            if (phy_dst_valid_1 && (src1_2 == dst_1)) begin
                phy_src1_2 = phy_dst_1; // Forward phy_dst_1 to rs1_2
            end
        end

        if (uses_rs2_2) begin
            if (phy_dst_valid_1 && (src2_2 == dst_1)) begin
                phy_src2_2 = phy_dst_1; // Forward phy_dst_1 to rs2_2
            end
        end
    end

endmodule
