`include "constants.vh"
`default_nettype none

module load_queue (
    input wire clk,
    input wire reset,
    input wire dispatch_load_valid,       // New Load instruction dispatch
    input wire [`REG_SEL-1:0] base_reg,   // Base register
    input wire [`IMM_WIDTH-1:0] offset,   // Immediate value
    input wire [`ROB_SEL-1:0] rob_idx,    // ROB Index
    input wire address_ready,             // Address calculation completed
    input wire [`ADDR_WIDTH-1:0] calculated_address, // Calculated address
    input wire [$clog2(`LQ_SIZE)-1:0] update_rob_idx,    // Index of the Load Queue entry to update
    input wire commit_enable,             // Commit Load instruction
    output reg lq_full,                   // Load Queue Full
    output reg lq_empty,                  // Load Queue Empty
    output reg [`ADDR_WIDTH-1:0] load_address, // Load Address for execution
    output reg [`ROB_SEL-1:0] load_rob_idx,    // ROB Index for execution
    output reg load_ready                 // Load Instruction Ready
);

    // Internal Load Queue Entry
    typedef struct {
        reg valid;
        reg [`REG_SEL-1:0] base_reg;
        reg [`IMM_WIDTH-1:0] offset;
        reg [`ROB_SEL-1:0] rob_idx;
        reg [`ADDR_WIDTH-1:0] address;
        reg address_ready;
    } lq_entry;

    lq_entry lq[`LQ_SIZE-1:0];
    reg [$clog2(`LQ_SIZE)-1:0] head, tail;
    reg [$clog2(`LQ_SIZE):0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            lq_full <= 0;
            lq_empty <= 1;
            load_ready <= 0;
        end else begin
            // Dispatch Logic
            if (dispatch_load_valid && !lq_full) begin
                lq[tail].valid <= 1;
                lq[tail].base_reg <= base_reg;
                lq[tail].offset <= offset;
                lq[tail].rob_idx <= rob_idx;
                lq[tail].address_ready <= 0;
                tail <= (tail + 1) % `LQ_SIZE;
                count <= count + 1;
            end

            // Address Calculation Update
            if (address_ready && lq[update_rob_idx].valid && !lq[update_rob_idx].address_ready) begin
                lq[update_rob_idx].address <= calculated_address;
                lq[update_rob_idx].address_ready <= 1;
            end


            /*
            // Commit Logic
            if (commit_enable && !lq_empty && lq[head].valid && lq[head].address_ready) begin
                lq[head].valid <= 0;
                head <= (head + 1) % `LQ_SIZE;
                count <= count - 1;
            end
            */


            
            // Update Status
            lq_full <= (count == `LQ_SIZE);
            lq_empty <= (count == 0);
        end
    end
endmodule
