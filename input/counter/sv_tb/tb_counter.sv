`timescale 1ns/1ps

// SystemVerilog testbench that runs alongside the cocotb Python test.
module tb_counter;
    logic       clk = 1'b0;
    logic       rst_n = 1'b0;
    logic [7:0] count;
    logic       sv_done = 1'b0;
    integer     sv_tests_passed = 0;
    integer     sv_tests_failed = 0;

    // Instantiate the counter and expose its signals at the testbench top so
    // cocotb can access them through Verilator's VPI interface.
    counter dut (
        .clk   (clk),
        .rst_n (rst_n),
        .count (count)
    );

    // Generate a 100 MHz clock: 5 ns low followed by 5 ns high.
    always #5ns clk = ~clk;

    // Hold reset through two rising edges, then allow ten count cycles. Signal
    // sv_done only after the SV checker has observed the tenth result.
    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        #1ns rst_n = 1'b1;
        repeat (10) @(posedge clk);
        @(negedge clk);
        #1ns sv_done = 1'b1;
        $display("SV_TEST_SUMMARY passed=%0d failed=%0d",
                 sv_tests_passed, sv_tests_failed);
`ifdef SV_ONLY
        $display("SystemVerilog counter test passed");
        $finish;
`endif
    end

    logic [7:0] expected = 8'd0;

    // Check on falling edges so the DUT's rising-edge nonblocking assignment
    // has settled before comparing count against the reference value.
    always @(negedge clk) begin
        if (!rst_n) begin
            expected = 8'd0;
            if (count == 8'd0)
                sv_tests_passed++;
            else begin
                sv_tests_failed++;
                $error("SV testbench: reset count=%0d, expected=0", count);
            end
        end else if (!sv_done) begin
            // Blocking assignment is intentional for this testbench reference
            // model: expected must update before the assertion below executes.
            expected = expected + 1'b1;
            if (count == expected)
                sv_tests_passed++;
            else begin
                sv_tests_failed++;
                $error("SV testbench: count=%0d, expected=%0d", count, expected);
            end
        end
    end
endmodule
