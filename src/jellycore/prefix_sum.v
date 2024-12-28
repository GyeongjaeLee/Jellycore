`include "constants.vh"
`default_nettype none
module prefix_sum(
    input wire  [`IQ_ENT_NUM-1:0]   request,
    output wire                     grant,
    output wire [`IQ_ENT_SEL-1:0]   selected_ent
    );

    wire [`IQ_ENT_NUM-1:0]  sum [`IQ_ENT_SEL:0];
    wire [`IQ_ENT_NUM-1:0]  grant_vec;

    genvar i, level;
    // Initialize sum with the input request
    generate
        for (i = 0; i < `IQ_ENT_NUM; i = i + 1) begin
            assign sum[0][i] = request[i];
        end
    endgenerate

    // calculate subsequent levels of sums (prefix-sum circuit for cumulative sum)
    // here, the circuit can grant up to 1 request signal so the adders can be replaced with OR
    generate
        for (level = 0; level < `IQ_ENT_SEL; level = level + 1) begin
            for (i = 0; i < (1 << level); i = i + 1) begin
                assign sum[level + 1][i] = sum[level][i];
            end
            for (i = (1 << level); i < `IQ_ENT_NUM; i = i + 1) begin
                assign sum[level + 1][i] = sum[level][i - (1 << level)] | sum[level][i];
            end
        end
    endgenerate

    // generate the grant signal based on cumulative sum
    // grant_vec holds the one-hot encoded grant signals
    generate
        for (i = 0; i < `IQ_ENT_NUM; i = i + 1) begin
            if (i == 0) begin
                assign grant_vec[i] = sum[`IQ_ENT_SEL][i];
            end else begin
                assign grant_vec[i] = ~sum[`IQ_ENT_SEL][i - 1] & sum[`IQ_ENT_SEL][i];
            end
        end
    endgenerate

    assign grant = |grant_vec;

    // return the index of the granted request
    generate
        for (i = 0; i < `IQ_ENT_NUM; i = i + 1) begin
            assign selected_ent = grant_vec[i] ? i[`IQ_ENT_SEL-1:0] : selected_ent;
        end
    endgenerate

endmodule