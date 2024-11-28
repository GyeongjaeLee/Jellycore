`include "constants.vh"
`include "alu_ops.vh"
`include "rv32_opcodes.vh"

`default_nettype none

module pipeline (
	input wire 			clk,
	input wire 			reset,
	output reg [`ADDR_LEN-1:0] 		pc,
	input wire [4*`INSN_LEN-1:0] 	idata,
	output wire [`DATA_LEN-1:0] 	dmem_wdata,
	output wire 					dmem_we,
	output wire [`ADDR_LEN-1:0] 	dmem_addr,
	input wire [`DATA_LEN-1:0] 		dmem_data
	);
    wire stall_IF;
    wire kill_IF;
    wire stall_ID;
    wire kill_ID;
	wire stall_RN;
	wire kill_RN;
    wire stall_DP;
    wire kill_DP;
    
    // IF
    // Signal from pipe_if
    wire     	       prcond;
    wire [`ADDR_LEN-1:0] npc;
    wire [`INSN_LEN-1:0] inst1;
    wire [`INSN_LEN-1:0] inst2;
    wire 		invalid2_pipe;
    wire [`GSH_BHR_LEN-1:0] bhr;
    
    // Instruction Buffer
    reg 			   prcond_if;
    reg [`ADDR_LEN-1:0] 	   npc_if;
    reg [`ADDR_LEN-1:0] 	   pc_if;
    reg [`INSN_LEN-1:0] 	   inst1_if;
    reg [`INSN_LEN-1:0] 	   inst2_if;
    reg 			   inv1_if;
    reg 			   inv2_if;
    reg 			   bhr_if;
    
    
    // ID
    // Decode Info1
    wire [`IMM_TYPE_WIDTH-1:0] imm_type_1;
    wire [`REG_SEL-1:0] 	      rs1_1;
    wire [`REG_SEL-1:0] 	      rs2_1;
    wire [`REG_SEL-1:0] 	      rd_1;
    wire [`SRC_A_SEL_WIDTH-1:0] src_a_sel_1;
    wire [`SRC_B_SEL_WIDTH-1:0] src_b_sel_1;
    wire 		       wr_reg_1;
    wire 		       uses_rs1_1;
    wire 		       uses_rs2_1;
    wire 		       illegal_instruction_1;
    wire [`ALU_OP_WIDTH-1:0]    alu_op_1;
    wire [`RS_ENT_SEL-1:0]      rs_ent_1;
    wire [2:0] 		       dmem_size_1;
    wire [`MEM_TYPE_WIDTH-1:0]  dmem_type_1;
    wire [`MD_OP_WIDTH-1:0]     md_req_op_1;
    wire 		       md_req_in_1_signed_1;
    wire 		       md_req_in_2_signed_1;
    wire [`MD_OUT_SEL_WIDTH-1:0] md_req_out_sel_1;
    // Decode Info2
    wire [`IMM_TYPE_WIDTH-1:0] 	imm_type_2;
    wire [`REG_SEL-1:0] 		rs1_2;
    wire [`REG_SEL-1:0] 		rs2_2;
    wire [`REG_SEL-1:0] 		rd_2;
    wire [`SRC_A_SEL_WIDTH-1:0] 	src_a_sel_2;
    wire [`SRC_B_SEL_WIDTH-1:0] 	src_b_sel_2;
    wire 			wr_reg_2;
    wire 			uses_rs1_2;
    wire 			uses_rs2_2;
    wire 			illegal_instruction_2;
    wire [`ALU_OP_WIDTH-1:0] 	alu_op_2;
    wire [`RS_ENT_SEL-1:0] 	rs_ent_2;
    wire [2:0] 			dmem_size_2;
    wire [`MEM_TYPE_WIDTH-1:0] 	dmem_type_2;
    wire [`MD_OP_WIDTH-1:0] 	md_req_op_2;
    wire 			md_req_in_1_signed_2;
    wire 			md_req_in_2_signed_2;
    wire [`MD_OUT_SEL_WIDTH-1:0] md_req_out_sel_2;
    // Additional Info
    wire 			isbranch1;
    wire 			isbranch2;
    
    // ID/RN Pipeline Register
    // Decode Info1
    reg [`IMM_TYPE_WIDTH-1:0] 	imm_type_1_id;
    reg [`REG_SEL-1:0] 		rs1_1_id;
    reg [`REG_SEL-1:0] 		rs2_1_id;
    reg [`REG_SEL-1:0] 		rd_1_id;
    reg [`SRC_A_SEL_WIDTH-1:0] 	src_a_sel_1_id;
    reg [`SRC_B_SEL_WIDTH-1:0] 	src_b_sel_1_id;
    reg 				wr_reg_1_id;
    reg 				uses_rs1_1_id;
    reg 				uses_rs2_1_id;
    reg 				illegal_instruction_1_id;
    reg [`ALU_OP_WIDTH-1:0] 	alu_op_1_id;
    reg [`RS_ENT_SEL-1:0] 	rs_ent_1_id;
    reg [2:0] 			dmem_size_1_id;
    reg [`MEM_TYPE_WIDTH-1:0] 	dmem_type_1_id;
    reg [`MD_OP_WIDTH-1:0] 	md_req_op_1_id;
    reg 				md_req_in_1_signed_1_id;
    reg 				md_req_in_2_signed_1_id;
    reg [`MD_OUT_SEL_WIDTH-1:0] 	md_req_out_sel_1_id;
    // Decode Info2
    reg [`IMM_TYPE_WIDTH-1:0] 	imm_type_2_id;
    reg [`REG_SEL-1:0] 		rs1_2_id;
    reg [`REG_SEL-1:0] 		rs2_2_id;
    reg [`REG_SEL-1:0] 		rd_2_id;
    reg [`SRC_A_SEL_WIDTH-1:0] 	src_a_sel_2_id;
    reg [`SRC_B_SEL_WIDTH-1:0] 	src_b_sel_2_id;
    reg 				wr_reg_2_id;
    reg 				uses_rs1_2_id;
    reg 				uses_rs2_2_id;
    reg 				illegal_instruction_2_id;
    reg [`ALU_OP_WIDTH-1:0] 	alu_op_2_id;
    reg [`RS_ENT_SEL-1:0] 	rs_ent_2_id;
    reg [2:0] 			dmem_size_2_id;
    reg [`MEM_TYPE_WIDTH-1:0] 	dmem_type_2_id;
    reg [`MD_OP_WIDTH-1:0] 	md_req_op_2_id;
    reg 				md_req_in_1_signed_2_id;
    reg 				md_req_in_2_signed_2_id;
    reg [`MD_OUT_SEL_WIDTH-1:0] 	md_req_out_sel_2_id;
    // Additional Info
    reg [`INSN_LEN-1:0] 		inst1_id;
    reg [`INSN_LEN-1:0] 		inst2_id;
    reg 				prcond1_id;
    reg 				prcond2_id;
    reg 				inv1_id;
    reg 				inv2_id;
    reg [`ADDR_LEN-1:0] 		praddr1_id;
    reg [`ADDR_LEN-1:0] 		praddr2_id;
    reg [`ADDR_LEN-1:0] 		pc_id;
    reg [`GSH_BHR_LEN-1:0] 	bhr_id;
    reg 				isbranch1_id;
    reg 				isbranch2_id;
    
    // BRANCH
    wire 		       prmiss;
    wire 		       prsuccess;
    
    // RENAME
	// signals from physical tag freelist
    wire [`PHY_REG_SEL-1:0] phy_dst_1_from_freelist;
    wire [`PHY_REG_SEL-1:0] phy_dst_2_from_freelist;
    wire 					phy_dst_valid_1;
    wire 					phy_dst_valid_2;
    wire 					allocatable_phytag;

	// signals from frontend-RAT
    wire [`PHY_REG_SEL-1:0] phy_src1_1_from_rat;
    wire [`PHY_REG_SEL-1:0] phy_src2_1_from_rat;
    wire [`PHY_REG_SEL-1:0] phy_src1_2_from_rat;
    wire [`PHY_REG_SEL-1:0] phy_src2_2_from_rat;
	wire [`PHY_REG_SEL-1:0] phy_ori_dst_1;
	wire [`PHY_REG_SEL-1:0] phy_ori_dst_2;

	// signals from renaming logic
    wire [`PHY_REG_SEL-1:0] phy_dst_1;
    wire [`PHY_REG_SEL-1:0] phy_dst_2;
	wire [`PHY_REG_SEL-1:0] phy_src1_1;
	wire [`PHY_REG_SEL-1:0] phy_src2_1;
	wire [`PHY_REG_SEL-1:0] phy_src1_2;
	wire [`PHY_REG_SEL-1:0] phy_src2_2;
    wire 					WAW_valid;
    
	// signals from commit stage
	wire [`PHY_REG_SEL-1:0]	com_phy_tag_1;
	wire [`PHY_REG_SEL-1:0]	com_phy_tag_2;
	wire 					com_valid_1;
	wire 					com_valid_2;

    // signals from immediate generator
    wire [`DATA_LEN-1:0]    imm_1;
    wire [`DATA_LEN-1:0]    imm_2;
    wire [`DATA_LEN-1:0]    brimm_1;
    wire [`DATA_LEN-1:0]    brimm_2;


	// Latch
	// Decode Info1
    reg [`SRC_A_SEL_WIDTH-1:0] 	src_a_sel_1_rn;
    reg [`SRC_B_SEL_WIDTH-1:0] 	src_b_sel_1_rn;
    reg 				wr_reg_1_rn;
    reg 				uses_rs1_1_rn;
    reg 				uses_rs2_1_rn;
    reg [`ALU_OP_WIDTH-1:0] 	alu_op_1_rn;
    reg [`RS_ENT_SEL-1:0] 	rs_ent_1_rn;
    reg 				md_req_in_1_signed_1_rn;
    reg 				md_req_in_2_signed_1_rn;
	reg [`MD_OUT_SEL_WIDTH-1:0] 	md_req_out_sel_1_rn;
	// Decode Info2
    reg [`SRC_A_SEL_WIDTH-1:0] 	src_a_sel_2_rn;
    reg [`SRC_B_SEL_WIDTH-1:0] 	src_b_sel_2_rn;
    reg 				wr_reg_2_rn;
    reg 				uses_rs1_2_rn;
    reg 				uses_rs2_2_rn;
    reg [`ALU_OP_WIDTH-1:0] 	alu_op_2_rn;
    reg [`RS_ENT_SEL-1:0] 	rs_ent_2_rn;
    reg 				md_req_in_1_signed_2_rn;
    reg 				md_req_in_2_signed_2_rn;
    reg [`MD_OUT_SEL_WIDTH-1:0] 	md_req_out_sel_2_rn;
	// Rename Logic Info
	reg [`PHY_REG_SEL-1:0] 		src1_1_rn;
    reg [`PHY_REG_SEL-1:0] 		src2_1_rn;
	reg [`PHY_REG_SEL-1:0] 		src1_2_rn;
    reg [`PHY_REG_SEL-1:0] 		src2_2_rn;
    reg [`PHY_REG_SEL-1:0] 		dst_1_rn;
	reg [`PHY_REG_SEL-1:0] 		dst_2_rn;
    // Immediate Gerneration Info
    reg [`DATA_LEN-1:0]         imm_1_rn;
    reg [`DATA_LEN-1:0]         imm_2_rn;
	// Addional Info
    reg [`ADDR_LEN-1:0]         pc_rn;
	reg 						inv1_rn;
	reg							inv2_rn;


	// DISPATCH
    // signals from issue queue freelist
	wire [`IQ_ENT_SEL-1:0]	iq_free_ent_1;
	wire [`IQ_ENT_SEL-1:0]	iq_free_ent_2;
	wire 					iq_free_valid_1;
	wire 					iq_free_valid_2;

    // signals from immediate buffer freelist
    wire                    imm_valid_1;
    wire                    imm_valid_2;
    wire [`IB_ENT_SEL-1:0]  ib_free_ent_1;
    wire [`IB_ENT_SEL-1:0]  ib_free_ent_2;
    wire 					ib_free_valid_1;
	wire 					ib_free_valid_2;

    // signals from PC buffer freelist
    wire                    pc_valid_1;
    wire                    pc_valid_2;
    wire [`PB_ENT_SEL-1:0]  pb_free_ent_1;
    wire [`PB_ENT_SEL-1:0]  pb_free_ent_2;
    wire                    pb_free_valid_1;
    wire                    pb_free_valid_2;

	wire					allocatable_iq;
	wire					allocatable_ib;
	wire					allocatable_rob;
	wire					allocatable_lq;
	wire					allocatable_sq;
    wire                    allocatable_pb;

	// ISSUE
    // selected instructions
	wire [`IQ_ENT_SEL-1:0]	issued_1;
	wire [`IQ_ENT_SEL-1:0]	issued_2;
	wire					issued_valid_1;
	wire					issued_valid_2;

    // if immediate instruction is issued
    wire [`IB_ENT_SEL-1:0]	issued_imm_1;
	wire [`IB_ENT_SEL-1:0]	issued_imm_2;
	wire					issued_imm_valid_1;
	wire					issued_imm_valid_2;
    wire [`DATA_LEN-1:0]    issued_imm_value_1;
    wire [`DATA_LEN-1:0]    issued_imm_value_2;

    // if PC-relative instruction is issued
    wire [`PB_ENT_SEL-1:0]  issued_pc_1;
    wire [`PB_ENT_SEL-1:0]  issued_pc_2;
    wire                    issued_pc_valid_1;
    wire                    issued_pc_valid_2;
    wire [`ADDR_LEN-1:0]    issued_pc_value_1;
    wire [`ADDR_LEN-1:0]    issued_pc_value_2;


    // IF Stage********************************************************
    // assign stall_IF = stall_ID;
    // assign kill_IF  = prmiss;
    assign stall_IF    = stall_ID | stall_DP;
    assign kill_IF     = prmiss;
    wire [`ADDR_LEN-1:0]        jmpaddr;
    wire [`ADDR_LEN-1:0]        jmpaddr_taken;
    
    always @ (posedge clk) begin
        if (reset) begin
            pc <= `ENTRY_POINT;
		end else if (prmiss) begin
            pc <= jmpaddr;
		end else if (stall_IF) begin
            pc <= pc;
		end else begin
            pc <= npc;
        end
    end
    
    pipeline_if pipe_if(
    .clk(clk),
    .reset(reset),
    .pc(pc),
    .predict_cond(prcond),
    .npc(npc),
    .inst1(inst1),
    .inst2(inst2),
    .invalid2(invalid2_pipe),
    .btbpht_we(combranch),
    .btbpht_pc(pc_combranch),
    .btb_jmpdst(jmpaddr_combranch),
    .pht_wcond(brcond_combranch),
    .mpft_valid(mpft_valid),
    .pht_bhr(bhr_combranch), //when PHT write
    .prmiss(prmiss),
    .prsuccess(prsuccess),
    .prtag(buf_spectag_branch),
    .bhr(bhr),
    .spectagnow(tagreg),
    .idata(idata)
    );
    
	// IF/ID Pipeline Register Update
    always @ (posedge clk) begin
        if (reset | kill_IF) begin
            prcond_if <= 0;
            npc_if    <= 0;
            pc_if     <= 0;
            inst1_if  <= 0;
            inst2_if  <= 0;
            inv1_if   <= 1;
            inv2_if   <= 1;
            bhr_if    <= 0;
		end else if (~stall_IF) begin
            prcond_if <= prcond;
            npc_if    <= npc;
            pc_if     <= pc;
            inst1_if  <= inst1;
            inst2_if  <= inst2;
            inv1_if   <= 0;
            inv2_if   <= invalid2_pipe;
            bhr_if    <= bhr;
        end
    end
    
    // ID Stage*****************************************************
    assign stall_ID      = stall_DP;
    assign kill_ID       = prmiss;
    
    assign isbranch1 = (~inv1_if && (rs_ent_1 == `RS_ENT_BRANCH)) ?
    1'b1 : 1'b0;
    assign isbranch2 = (~inv2_if && (rs_ent_2 == `RS_ENT_BRANCH)) ?
    1'b1 : 1'b0;

	// ID Stage Instances
    decoder dec1(
    .inst(inst1_if),
    .imm_type(imm_type_1),
    .rs1(rs1_1),
    .rs2(rs2_1),
    .rd(rd_1),
    .src_a_sel(src_a_sel_1),
    .src_b_sel(src_b_sel_1),
    .wr_reg(wr_reg_1),
    .uses_rs1(uses_rs1_1),
    .uses_rs2(uses_rs2_1),
    .illegal_instruction(illegal_instruction_1),
    .alu_op(alu_op_1),
    .rs_ent(rs_ent_1),
    .dmem_size(dmem_size_1),
    .dmem_type(dmem_type_1),
    .md_req_op(md_req_op_1),
    .md_req_in_1_signed(md_req_in_1_signed_1),
    .md_req_in_2_signed(md_req_in_2_signed_1),
    .md_req_out_sel(md_req_out_sel_1)
    );
    
    decoder dec2(
    .inst(inst2_if),
    .imm_type(imm_type_2),
    .rs1(rs1_2),
    .rs2(rs2_2),
    .rd(rd_2),
    .src_a_sel(src_a_sel_2),
    .src_b_sel(src_b_sel_2),
    .wr_reg(wr_reg_2),
    .uses_rs1(uses_rs1_2),
    .uses_rs2(uses_rs2_2),
    .illegal_instruction(illegal_instruction_2),
    .alu_op(alu_op_2),
    .rs_ent(rs_ent_2),
    .dmem_size(dmem_size_2),
    .dmem_type(dmem_type_2),
    .md_req_op(md_req_op_2),
    .md_req_in_1_signed(md_req_in_1_signed_2),
    .md_req_in_2_signed(md_req_in_2_signed_2),
    .md_req_out_sel(md_req_out_sel_2)
    );
    
    
    // ID/RN Pipeline Register Update
    always @ (posedge clk) begin
        if (reset | kill_ID) begin
            imm_type_1_id            <= 0;
            rs1_1_id                 <= 0;
            rs2_1_id                 <= 0;
            rd_1_id                  <= 0;
            src_a_sel_1_id           <= 0;
            src_b_sel_1_id           <= 0;
            wr_reg_1_id              <= 0;
            uses_rs1_1_id            <= 0;
            uses_rs2_1_id            <= 0;
            illegal_instruction_1_id <= 0;
            alu_op_1_id              <= 0;
            rs_ent_1_id              <= 0;
            dmem_size_1_id           <= 0;
            dmem_type_1_id           <= 0;
            md_req_op_1_id           <= 0;
            md_req_in_1_signed_1_id  <= 0;
            md_req_in_2_signed_1_id  <= 0;
            md_req_out_sel_1_id      <= 0;
            imm_type_2_id            <= 0;
            rs1_2_id                 <= 0;
            rs2_2_id                 <= 0;
            rd_2_id                  <= 0;
            src_a_sel_2_id           <= 0;
            src_b_sel_2_id           <= 0;
            wr_reg_2_id              <= 0;
            uses_rs1_2_id            <= 0;
            uses_rs2_2_id            <= 0;
            illegal_instruction_2_id <= 0;
            alu_op_2_id              <= 0;
            rs_ent_2_id              <= 0;
            dmem_size_2_id           <= 0;
            dmem_type_2_id           <= 0;
            md_req_op_2_id           <= 0;
            md_req_in_1_signed_2_id  <= 0;
            md_req_in_2_signed_2_id  <= 0;
            md_req_out_sel_2_id      <= 0;
            
            inst1_id         <= 0;
            inst2_id         <= 0;
            prcond1_id       <= 0;
            prcond2_id       <= 0;
            inv1_id          <= 1;
            inv2_id          <= 1;
            praddr1_id       <= 0;
            praddr2_id       <= 0;
            pc_id            <= 0;
            bhr_id           <= 0;
            isbranch1_id     <= 0;
			isbranch2_id     <= 0;
		end else if (~stall_DP) begin
            imm_type_1_id            <= imm_type_1;
            rs1_1_id                 <= rs1_1;
            rs2_1_id                 <= rs2_1;
            rd_1_id                  <= rd_1;
            src_a_sel_1_id           <= src_a_sel_1;
            src_b_sel_1_id           <= src_b_sel_1;
            wr_reg_1_id              <= wr_reg_1;
            uses_rs1_1_id            <= uses_rs1_1;
            uses_rs2_1_id            <= uses_rs2_1;
            illegal_instruction_1_id <= illegal_instruction_1;
            alu_op_1_id              <= alu_op_1;
            rs_ent_1_id              <= inv1_if ? 0 : rs_ent_1;
            dmem_size_1_id           <= dmem_size_1;
            dmem_type_1_id           <= dmem_type_1;
            md_req_op_1_id           <= md_req_op_1;
            md_req_in_1_signed_1_id  <= md_req_in_1_signed_1;
            md_req_in_2_signed_1_id  <= md_req_in_2_signed_1;
            md_req_out_sel_1_id      <= md_req_out_sel_1;
            imm_type_2_id            <= imm_type_2;
            rs1_2_id                 <= rs1_2;
            rs2_2_id                 <= rs2_2;
            rd_2_id                  <= rd_2;
            src_a_sel_2_id           <= src_a_sel_2;
            src_b_sel_2_id           <= src_b_sel_2;
            wr_reg_2_id              <= wr_reg_2;
            uses_rs1_2_id            <= uses_rs1_2;
            uses_rs2_2_id            <= uses_rs2_2;
            illegal_instruction_2_id <= illegal_instruction_2;
            alu_op_2_id              <= alu_op_2;
            rs_ent_2_id              <= (inv2_if | (prcond_if & isbranch1)) ? 0 : rs_ent_2;
            dmem_size_2_id           <= dmem_size_2;
            dmem_type_2_id           <= dmem_type_2;
            md_req_op_2_id           <= md_req_op_2;
            md_req_in_1_signed_2_id  <= md_req_in_1_signed_2;
            md_req_in_2_signed_2_id  <= md_req_in_2_signed_2;
            md_req_out_sel_2_id      <= md_req_out_sel_2;
	
            inst1_id     <= inst1_if;
            inst2_id     <= inst2_if;
            prcond1_id   <= prcond_if & isbranch1;
            prcond2_id   <= isbranch2 & prcond_if & ~isbranch1;
            inv1_id      <= inv1_if;
            inv2_id      <= inv2_if | (prcond_if & isbranch1);
            praddr1_id   <= (prcond_if & isbranch1) ? npc_if : (pc_if + 4);
            praddr2_id   <= npc_if;
            pc_id        <= pc_if;
            bhr_id       <= bhr_if;
            isbranch1_id <= isbranch1;
            isbranch2_id <= isbranch2;
        end
    end
    
	// RN Stage*************************************************
	assign stall_RN = ~allocatable_phytag | stall_DP;
	assign kill_RN = prmiss;


	// Renaming Logic Instances
    freelist #(`PHY_REG_NUM, `PHY_REG_SEL)
	phy_tag_freelist(
    .clk(clk),
    .reset(reset),
    .invalid1(~inv1_id && wr_reg_1_id),
	.invalid2(~inv2_id && wr_reg_2_id),
    .prmiss(prmiss),
    .released_1(com_phy_tag_1),
    .released_2(com_phy_tag_2),
    .released_valid_1(com_valid_1),
    .released_valid_2(com_valid_2),
    .stall_DP(stall_DP),
    .phy_dst_1(phy_dst_1_from_freelist),
    .phy_dst_2(phy_dst_2_from_freelist),
    .phy_dst_valid_1(phy_dst_valid_1),
    .phy_dst_valid_2(phy_dst_valid_2),
    .allocatable(allocatable_phytag)
    );
    
    frontend_RAT frontend_rat(
    .clk(clk),
    .rs1_1(rs1_1_id),
    .rs2_1(rs2_1_id),
    .rs1_2(rs1_2_id),
    .rs2_2(rs2_2_id),
    .dst1(rd_1_id),
    .dst2(rd_2_id),
    .phy_dst_1(phy_dst_1_from_freelist),
    .phy_dst_2(phy_dst_2_from_freelist),
    .phy_dst_valid_1(phy_dst_valid_1),
    .phy_dst_valid_2(phy_dst_valid_2),
    .WAW_valid(WAW_valid),
    .prmiss(1'b0),                   // Replace with branch misprediction
    .phy_src1_1(phy_src1_1_from_rat),
    .phy_src2_1(phy_src2_1_from_rat),
    .phy_src1_2(phy_src1_2_from_rat),
    .phy_src2_2(phy_src2_2_from_rat),
    .phy_ori_dst_1(phy_ori_dst_1),
    .phy_ori_dst_2(phy_ori_dst_2)
    );

    renaming_logic renaming(
    .clk(clk),
    .reset(reset),
    .uses_rs1_1(uses_rs1__id),
    .uses_rs2_1(uses_rs2_1_id),
    .uses_rs1_2(uses_rs1_2_id),
    .uses_rs2_2(uses_rs2_2_id),
    .phy_dst_valid_1(phy_dst_valid_1),
    .phy_dst_valid_2(phy_dst_valid_2),
    .phy_src1_1_from_rat(phy_src1_1_from_rat),
    .phy_src2_1_from_rat(phy_src2_1_from_rat),
    .phy_src1_2_from_rat(phy_src1_2_from_rat),
    .phy_src2_2_from_rat(phy_src2_2_from_rat),
    .phy_dst_1_from_rat(phy_ori_dst_1),
    .phy_dst_2_from_rat(phy_ori_dst_2),
    .phy_dst_1_from_free_list(phy_dst_1_from_freelist),
    .phy_dst_2_from_free_list(phy_dst_2_from_freelist),
    .WAW_valid(WAW_valid),
    .phy_dst_1(phy_dst_1),
    .phy_dst_2(phy_dst_2),
    .phy_src1_1(phy_src1_1),
    .phy_src2_1(phy_src2_1),
    .phy_src1_2(phy_src1_2),
    .phy_src2_2(phy_src2_2)
	);

    // immediate generation
    imm_gen imm_gen1(
    .inst(inst1_id),
    .imm_type(imm_type_1_id),
    .imm(imm_1)
    );

    imm_gen imm_gen2(
    .inst(inst2_id),
    .imm_type(imm_type_2_id),
    .imm(imm_2)
    );

    brimm_gen   brimm_gen1(
    .inst(inst_1_id),
    .imm_type(brimm_1)
    );

    brimm_gen   brimm_gen2(
    .inst(inst_2_id),
    .imm_type(brimm_2)
    );

	// RN/DP Pipeline Register update
	always @ (posedge clk) begin
		if (reset | kill_RN) begin
			src_a_sel_1_rn					<= 0;
			src_b_sel_1_rn					<= 0;
			wr_reg_1_rn						<= 0;
			uses_rs1_1_rn					<= 0;
			uses_rs2_1_rn					<= 0;
			alu_op_1_rn						<= 0;
			rs_ent_1_rn						<= 0;
			md_req_in_1_signed_1_rn			<= 0;
			md_req_in_2_signed_1_rn			<= 0;
			md_req_out_sel_1_rn				<= 0;
            imm_1_rn                        <= 0;
			src_a_sel_2_rn					<= 0;
			src_b_sel_2_rn					<= 0;
			wr_reg_2_rn						<= 0;
			uses_rs1_2_rn					<= 0;
			uses_rs2_2_rn					<= 0;
			alu_op_2_rn						<= 0;
			rs_ent_2_rn						<= 0;
			md_req_in_1_signed_2_rn			<= 0;
			md_req_in_2_signed_2_rn			<= 0;
			md_req_out_sel_2_rn				<= 0;
            imm_2_rn                        <= 0;

            pc_rn                           <= 0;
			src1_1_rn						<= 0;
			src2_1_rn						<= 0;
			src1_2_rn						<= 0;
			src2_2_rn						<= 0;
			dst_1_rn						<= 0;
			dst_2_rn						<= 0;
			inv1_rn							<= 0;
			inv2_rn							<= 0;
            isbranch1_rn                    <= 0;
            isbranch2_rn                    <= 0;
		end else if (~stall_RN) begin
			src_a_sel_1_rn					<= src_a_sel_1_id;
			src_b_sel_1_rn					<= src_b_sel_1_id;
			wr_reg_1_rn						<= wr_reg_1_id;
			uses_rs1_1_rn					<= uses_rs1_1_id;
			uses_rs2_1_rn					<= uses_rs2_1_id;
			alu_op_1_rn						<= alu_op_1_id;
			rs_ent_1_rn						<= rs_ent_1_id;
			md_req_in_1_signed_1_rn			<= md_req_in_1_signed_1_id;
			md_req_in_2_signed_1_rn			<= md_req_in_2_signed_1_id;
			md_req_out_sel_1_rn				<= md_req_out_sel_1_id;
            imm_1_rn                        <= isbranch1_id ? brimm_1 : imm_1;
			src_a_sel_2_rn					<= src_a_sel_2_id;
			src_b_sel_2_rn					<= src_b_sel_2_id;
			wr_reg_2_rn						<= wr_reg_2_id;
			uses_rs1_2_rn					<= uses_rs1_2_id;
			uses_rs2_2_rn					<= uses_rs2_2_id;
			alu_op_2_rn						<= alu_op_2_id;
			rs_ent_2_rn						<= rs_ent_2_id;
			md_req_in_1_signed_2_rn			<= md_req_in_1_signed_2_id;
			md_req_in_2_signed_2_rn			<= md_req_in_2_signed_2_id;
			md_req_out_sel_2_rn				<= md_req_out_sel_2_id;
            imm_2_rn                        <= isbranch2_id ? brimm_2 : imm_2;

            pc_rn                           <= pc_id;
			src1_1_rn						<= phy_src1_1;
			src2_1_rn						<= phy_src2_1;
			src1_2_rn						<= phy_src1_2;
			src2_2_rn						<= phy_src2_2;
			dst_1_rn						<= phy_dst_1;
			dst_2_rn						<= phy_dst_2;
			inv1_rn							<= inv1_id;
			inv2_rn							<= inv2_id;
            isbranch1_rn                    <= isbranch1_id;
            isbranch2_rn                    <= isbranch2_id;
		end

	end

	// DP Stage*************************************************
	assign stall_DP = ~allocatable_iq | ~allocatable_ib | ~allocatable_pb
					| ~allocatable_rob| ~allocatable_lq | ~allocatable_sq;
	assign kill_DP = prmiss;

    // isbranch already includes JAL and JALR
    assign imm_valid_1 = ~inv1_rn && (isbranch1_rn || (src_b_sel_1_rn == `SRC_B_IMM));
    assign imm_valid_2 = ~inv2_rn && (isbranch2_rn || (src_b_sel_2_rn == `SRC_B_IMM));
    assign pc_valid_1 = ~inv1_rn && (isbranch1_rn || (src_a_sel_1_rn == `SRC_A_PC));
    assign pc_valid_2 = ~inv2_rn && (isbranch2_rn || (src_a_sel_2_rn == `SRC_A_PC));

	// Dispatch Instatnces
	freelist #(`IQ_ENT_NUM, `IQ_ENT_SEL)
	iq_freelist (
    .clk(clk),
    .reset(reset),
    .invalid1(inv1_rn),
    .invalid2(inv2_rn),
    .prmiss(prmiss),
    .released_1(issued_1),
    .released_2(issued_2),
    .released_valid_1(issued_valid_1),
    .released_valid_2(issued_valid_2),
    .stall_DP(stall_DP),
    .alloc_1(iq_free_ent_1),
    .alloc_2(iq_free_ent_2),
    .alloc_valid_1(iq_free_valid_1),
    .alloc_valid_2(iq_free_valid_2),
    .allocatable(allocatable_iq)
    );

    // 
    freelist #(`IB_ENT_NUM, `IB_ENT_SEL)
    ib_freelist (
    .clk(clk),
    .reset(reset),
    .invalid1(imm_valid_1),
    .invalid2(imm_valid_2),
    .prmiss(prmiss),
    .released_1(issued_imm_1),
    .released_2(issued_imm_2),
    .released_valid_1(issued_imm_valid_1),
    .released_valid_2(issued_imm_valid_2),
    .stall_DP(stall_DP),
    .alloc_1(ib_free_ent_1),
    .alloc_2(ib_free_ent_2),
    .alloc_valid_1(ib_free_valid_1),
    .alloc_valid_2(ib_free_valid_2),
    .allocatable(allocatable_ib)
    );


    // store immediate value 
    value_buffer #(`IB_ENT_NUM, `IB_ENT_SEL, `DATA_LEN)
    immediate_buffer (
    .clk(clk),
    .reset(reset),
    .invalid1(ib_free_valid_1),
    .invalid2(ib_free_valid_2),
    .ptr_1(ib_free_ent_1),
    .ptr_2(ib_free_ent_2),
    .value_1(imm_value_1),
    .value_2(imm_value_2),
    .prmiss(prmiss),
    .issued_1(),        // if selected instruction is immediate?
    .issued_2(),
    .issued_ptr_1(issued_imm_1),    // imm buffer ptr from select logic
    .issued_ptr_2(issued_imm_2),
    .issued_value_1(issued_imm_value_1),
    .issued_value_1(issued_imm_value_1)
    );

    freelist #(`PB_ENT_NUM, `PB_ENT_SEL)
    pb_freelist (
    .clk(clk),
    .reset(reset),
    .invalid1(pc_valid_1),
    .invalid2(pc_valid_2),
    .prmiss(prmiss),
    .released_1(issued_pc_1),
    .released_2(issued_pc_2),
    .released_valid_1(issued_pc_valid_1),
    .released_valid_2(issued_pc_valid_2),
    .stall_DP(stall_DP),
    .alloc_1(pb_free_ent_1),
    .alloc_2(pb_free_ent_2),
    .alloc_valid_1(pb_free_valid_1),
    .alloc_valid_2(pb_free_valid_2),
    .allocatable(allocatable_pb)
    );

    value_buffer #(`PB_ENT_NUM, `PB_ENT_SEL, `ADDR_LEN)
    pc_buffer (
    .clk(clk),
    .reset(reset),
    .invalid1(pb_free_valid_1),
    .invalid2(pb_free_valid_2),
    .ptr_1(pb_free_ent_1),
    .ptr_2(pb_free_ent_2),
    .value_1(pc_value_1),
    .value_2(pc_value_2),
    .prmiss(prmiss),
    .issued_1(),        // if selected instruction is immediate?
    .issued_2(),
    .issued_ptr_1(issued_pc_1),    // pc buffer ptr from select logic
    .issued_ptr_2(issued_pc_2),
    .issued_value_1(issued_pc_value_1),
    .issued_value_1(issued_pc_value_1)
    );


endmodule

