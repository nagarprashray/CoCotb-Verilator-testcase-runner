// Eight-bit synchronous up-counter used as the design under test (DUT).
module counter (
    input  logic       clk,
    // Active-low synchronous reset, sampled on each rising clock edge.
    input  logic       rst_n,
    output logic [7:0] count
);
    // Reset to zero or increment once per rising edge. Natural overflow wraps
    // the eight-bit value from 255 back to zero.
    always_ff @(posedge clk) begin
        if (!rst_n)
            count <= '0;
        else
            count <= count + 1'b1;
    end
endmodule
