`include "constants.vh"
`default_nettype none

module store_queue (
    input wire clk,
    input wire reset,
    input wire dispatch_store_valid,      // New Store instruction dispatch
    input wire [`REG_SEL-1:0] base_reg,   // Base register
    input wire [`IMM_WIDTH-1:0] offset,   // Immediate value
    input wire [`DATA_WIDTH-1:0] store_data, // Data to store
    input wire [`ROB_SEL-1:0] rob_idx,    // ROB Index
    input wire address_ready,             // Address calculation completed
    input wire [`ADDR_WIDTH-1:0] calculated_address, // Calculated address
    input wire [$clog2(`SQ_SIZE)-1:0] update_rob_idx,    // Index of the Store Queue entry to update
    input wire commit_enable,             // Commit Store instruction
    output reg sq_full,                   // Store Queue Full
    output reg sq_empty,                  // Store Queue Empty
    output reg [`ADDR_WIDTH-1:0] store_address, // Store Address for execution
    output reg [`DATA_WIDTH-1:0] store_value,   // Data to store
    output reg store_ready                // Store Instruction Ready
);

    // Internal Store Queue Entry
    typedef struct {
        reg valid;
        reg [`REG_SEL-1:0] base_reg;
        reg [`IMM_WIDTH-1:0] offset;
        reg [`DATA_WIDTH-1:0] data;
        reg [`ROB_SEL-1:0] rob_idx;
        reg [`ADDR_WIDTH-1:0] address;
        reg address_ready;
    } sq_entry;

    sq_entry sq[`SQ_SIZE-1:0];
    reg [$clog2(`SQ_SIZE)-1:0] head, tail;
    reg [$clog2(`SQ_SIZE):0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            sq_full <= 0;
            sq_empty <= 1;
            store_ready <= 0;
        end else begin
            // Dispatch Logic
            if (dispatch_store_valid && !sq_full) begin
                sq[tail].valid <= 1;
                sq[tail].base_reg <= base_reg;
                sq[tail].offset <= offset;
                sq[tail].data <= store_data;
                sq[tail].rob_idx <= rob_idx;
                sq[tail].address_ready <= 0;
                tail <= (tail + 1) % `SQ_SIZE;
                count <= count + 1;
            end

            // Address Calculation Update
            if (address_ready && sq[update_rob_idx].valid && !sq[update_rob_idx].address_ready) begin
                sq[update_rob_idx].address <= calculated_address;
                sq[update_rob_idx].address_ready <= 1;
            end


            /*
            // Commit Logic
            if (commit_enable && !sq_empty && sq[head].valid && sq[head].address_ready) begin
                sq[head].valid <= 0;
                head <= (head + 1) % `SQ_SIZE;
                count <= count - 1;
            end
            */


            
            // Update Status
            sq_full <= (count == `SQ_SIZE);
            sq_empty <= (count == 0);
        end
    end
endmodule
