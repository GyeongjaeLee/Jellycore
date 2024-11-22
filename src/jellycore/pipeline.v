`include "constants.vh"
`include "alu_ops.vh"
`include "rv32_opcodes.vh"

`default_nettype none

module pipeline
  (
   input wire 			clk,
   input wire 			reset,
   output reg [`ADDR_LEN-1:0] 	pc,
   input wire [4*`INSN_LEN-1:0] idata,
   output wire [`DATA_LEN-1:0] 	dmem_wdata,
   output wire 			dmem_we,
   output wire [`ADDR_LEN-1:0] 	dmem_addr,
   input wire [`DATA_LEN-1:0] 	dmem_data
   );
   wire  stall_IF;
   wire  kill_IF;
   wire  stall_ID;
   wire  kill_ID;
   wire  stall_DP;
   wire  kill_DP;

   //IF
   // Signal from pipe_if
   wire     	       prcond;
   wire [`ADDR_LEN-1:0] npc;
   wire [`INSN_LEN-1:0] inst1;
   wire [`INSN_LEN-1:0] inst2;
   wire 		invalid2_pipe;
   wire [`GSH_BHR_LEN-1:0] bhr;
   
   //Instruction Buffer
   reg 			   prcond_if;
   reg [`ADDR_LEN-1:0] 	   npc_if;
   reg [`ADDR_LEN-1:0] 	   pc_if;
   reg [`INSN_LEN-1:0] 	   inst1_if;
   reg [`INSN_LEN-1:0] 	   inst2_if;
   reg 			   inv1_if;
   reg 			   inv2_if;
   reg 			   bhr_if;
   wire 		   attachable;

  
   //ID
   //Decode Info1
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
   //Decode Info2
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
   //Additional Info
   wire [`SPECTAG_LEN-1:0] 	sptag1;
   wire [`SPECTAG_LEN-1:0] 	sptag2;
   wire [`SPECTAG_LEN-1:0] 	tagreg;
   wire 			spec1;
   wire 			spec2;
   wire 			isbranch1;
   wire 			isbranch2;
   wire 			branchvalid1;
   wire 			branchvalid2;
   
   //Latch
   //Decode Info1
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
   //Decode Info2
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
   //Additional Info
   reg 				rs1_2_eq_dst1_id;
   reg 				rs2_2_eq_dst1_id;
   reg [`SPECTAG_LEN-1:0] 	sptag1_id;
   reg [`SPECTAG_LEN-1:0] 	sptag2_id;
   reg [`SPECTAG_LEN-1:0] 	tagreg_id;
   reg 				spec1_id;
   reg 				spec2_id;
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

    //BRANCH
   wire 		       prmiss;
   wire 		       prsuccess;


  //IF Stage********************************************************
  //   assign stall_IF = stall_ID;
  //   assign kill_IF = prmiss;
   assign stall_IF = stall_ID | stall_DP;
   assign kill_IF = prmiss;
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

  	always @ (posedge clk) begin
      if (reset | kill_IF) begin
	 prcond_if <= 0;
	 npc_if <= 0;
	 pc_if <= 0;
	 inst1_if <= 0;
	 inst2_if <= 0;
	 inv1_if <= 1;
	 inv2_if <= 1;
	 bhr_if <= 0;
	 
      end else if (~stall_IF) begin
	 prcond_if <= prcond;
	 npc_if <= npc;
	 pc_if <= pc;
	 inst1_if <= inst1;
	 inst2_if <= inst2;
	 inv1_if <= 0;
	 inv2_if <= invalid2_pipe;
	 bhr_if <= bhr;
	 
      end
   end // always @ (posedge clk)

   //ID Stage********************************************************
//   assign stall_ID = stall_DP | ~attachable | (prsuccess & (isbranch1 | isbranch2));
//   assign kill_ID = prmiss;
   assign stall_ID = ~attachable | prsuccess;
   assign kill_ID = (stall_ID & ~stall_DP) | prmiss;
   
   assign isbranch1 = (~inv1_if && (rs_ent_1 == `RS_ENT_BRANCH)) ?
		      1'b1 : 1'b0;
   assign isbranch2 = (~inv2_if && (rs_ent_2 == `RS_ENT_BRANCH)) ?
		      1'b1 : 1'b0;
   assign branchvalid1 = isbranch1 & prcond_if;
   assign branchvalid2 = isbranch2 & ~branchvalid1;
   
   tag_generator taggen(
			.clk(clk),
			.reset(reset),
			.branchvalid1(isbranch1),
			.branchvalid2(branchvalid2),
			.prmiss(prmiss),
			.prsuccess(prsuccess),
			.enable(~stall_ID & ~stall_DP),
			.tagregfix(tagregfix),
			.sptag1(sptag1),
			.sptag2(sptag2),
			.speculative1(spec1),
			.speculative2(spec2),
			.attachable(attachable),
			.tagreg(tagreg)
			);
   
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

    always @ (posedge clk) begin
      if (reset | kill_ID) begin
	 imm_type_1_id <= 0;
	 rs1_1_id <= 0;
	 rs2_1_id <= 0;
	 rd_1_id <= 0;
	 src_a_sel_1_id <= 0;
	 src_b_sel_1_id <= 0;
	 wr_reg_1_id <= 0;
	 uses_rs1_1_id <= 0;
	 uses_rs2_1_id <= 0;
	 illegal_instruction_1_id <= 0;
	 alu_op_1_id <= 0;
	 rs_ent_1_id <= 0;
	 dmem_size_1_id <= 0;
	 dmem_type_1_id <= 0;			  
	 md_req_op_1_id <= 0;
	 md_req_in_1_signed_1_id <= 0;
	 md_req_in_2_signed_1_id <= 0;
	 md_req_out_sel_1_id <= 0;
	 imm_type_2_id <= 0;
	 rs1_2_id <= 0;
	 rs2_2_id <= 0;
	 rd_2_id <= 0;
	 src_a_sel_2_id <= 0;
	 src_b_sel_2_id <= 0;
	 wr_reg_2_id <= 0;
	 uses_rs1_2_id <= 0;
	 uses_rs2_2_id <= 0;
	 illegal_instruction_2_id <= 0;
	 alu_op_2_id <= 0;
	 rs_ent_2_id <= 0;
	 dmem_size_2_id <= 0;
	 dmem_type_2_id <= 0;			  
	 md_req_op_2_id <= 0;
	 md_req_in_1_signed_2_id <= 0;
	 md_req_in_2_signed_2_id <= 0;
	 md_req_out_sel_2_id <= 0;

	 rs1_2_eq_dst1_id <= 0;
  	 rs2_2_eq_dst1_id <= 0;
	 sptag1_id <= 0;
	 sptag2_id <= 0;
	 tagreg_id <= 0;
//	 spec1_id <= 0;
//	 spec2_id <= 0;
	 inst1_id <= 0;
	 inst2_id <= 0;
	 prcond1_id <= 0;
	 prcond2_id <= 0;
	 inv1_id <= 1;
	 inv2_id <= 1;
	 praddr1_id <= 0;
	 praddr2_id <= 0;
	 pc_id <= 0;
	 bhr_id <= 0;
	 isbranch1_id <= 0;
	 isbranch2_id <= 0;
	 
      end else if (~stall_DP) begin
	 imm_type_1_id <= imm_type_1;
	 rs1_1_id <= rs1_1;
	 rs2_1_id <= rs2_1;
	 rd_1_id <= rd_1;
	 src_a_sel_1_id <= src_a_sel_1;
	 src_b_sel_1_id <= src_b_sel_1;
	 wr_reg_1_id <= wr_reg_1;
	 uses_rs1_1_id <= uses_rs1_1;
	 uses_rs2_1_id <= uses_rs2_1;
	 illegal_instruction_1_id <= illegal_instruction_1;
	 alu_op_1_id <= alu_op_1;
	 rs_ent_1_id <= inv1_if ? 0 : rs_ent_1;
	 dmem_size_1_id <= dmem_size_1;
	 dmem_type_1_id <= dmem_type_1;			  
	 md_req_op_1_id <= md_req_op_1;
	 md_req_in_1_signed_1_id <= md_req_in_1_signed_1;
	 md_req_in_2_signed_1_id <= md_req_in_2_signed_1;
	 md_req_out_sel_1_id <= md_req_out_sel_1;
	 imm_type_2_id <= imm_type_2;
	 rs1_2_id <= rs1_2;
	 rs2_2_id <= rs2_2;
	 rd_2_id <= rd_2;
	 src_a_sel_2_id <= src_a_sel_2;
	 src_b_sel_2_id <= src_b_sel_2;
	 wr_reg_2_id <= wr_reg_2;
	 uses_rs1_2_id <= uses_rs1_2;
	 uses_rs2_2_id <= uses_rs2_2;
	 illegal_instruction_2_id <= illegal_instruction_2;
	 alu_op_2_id <= alu_op_2;
	 rs_ent_2_id <= (inv2_if | (prcond_if & isbranch1)) ? 0 : rs_ent_2;
	 dmem_size_2_id <= dmem_size_2;
	 dmem_type_2_id <= dmem_type_2;			  
	 md_req_op_2_id <= md_req_op_2;
	 md_req_in_1_signed_2_id <= md_req_in_1_signed_2;
	 md_req_in_2_signed_2_id <= md_req_in_2_signed_2;
	 md_req_out_sel_2_id <= md_req_out_sel_2;
	 
	 rs1_2_eq_dst1_id <= (rs1_2 == rd_1 && wr_reg_1) ? 1'b1 : 1'b0;
  	 rs2_2_eq_dst1_id <= (rs2_2 == rd_1 && wr_reg_1) ? 1'b1 : 1'b0;
	 sptag1_id <= sptag1;
	 sptag2_id <= sptag2;
	 tagreg_id <= tagreg;
//	 spec1_id <= spec1;
//	 spec2_id <= spec2;
	 inst1_id <= inst1_if;
	 inst2_id <= inst2_if;
	 prcond1_id <= prcond_if & isbranch1;
	 prcond2_id <= isbranch2 & prcond_if & ~isbranch1;
	 inv1_id <= inv1_if;
	 inv2_id <= inv2_if | (prcond_if & isbranch1);
	 /*
	 praddr1_id <= prcond_if & isbranch1 ? npc_if : pc_if + 4;
	 praddr2_id <= prcond_if & ~isbranch1 & isbranch2 ?
		       npc_if : pc_if + 8;
	  */
	 praddr1_id <= (prcond_if & isbranch1) ? npc_if : (pc_if + 4);
	 praddr2_id <= npc_if;
	 pc_id <= pc_if;
	 bhr_id <= bhr_if;
	 isbranch1_id <= isbranch1;
	 isbranch2_id <= isbranch2;
	 
      end
   end


endmodule