`timescale 1ns/1ps

// Drives boundary, wraparound, and simultaneous-operation FIFO scenarios.
module tb_sync_fifo;
    logic       clk = 1'b0;
    logic       rst_n = 1'b0;
    logic       wr_en = 1'b0;
    logic       rd_en = 1'b0;
    logic [7:0] wr_data = 8'h00;
    logic [7:0] rd_data;
    logic       full;
    logic       empty;
    logic [2:0] count;
    logic       sv_done = 1'b0;
    integer     sv_tests_passed = 0;
    integer     sv_tests_failed = 0;

    sync_fifo dut (.*);

    always #5ns clk = ~clk;

    logic [7:0] model [0:3];
    int model_write = 0;
    int model_read = 0;
    int model_count = 0;
    logic [7:0] expected_read = 8'h00;

    task automatic check(input logic condition, input string description);
        if (condition)
            sv_tests_passed++;
        else begin
            sv_tests_failed++;
            $error("SV FIFO: %s", description);
        end
    endtask

    // Apply one transaction and check the resulting FIFO state independently.
    task automatic transact(input logic write_request,
                             input logic read_request,
                             input logic [7:0] data);
        logic accept_write;
        logic accept_read;
        @(negedge clk);
        wr_en = write_request;
        rd_en = read_request;
        wr_data = data;

        accept_write = write_request && (model_count < 4);
        accept_read = read_request && (model_count > 0);

        @(posedge clk);
        #1ns;

        if (accept_write) begin
            model[model_write] = data;
            model_write = (model_write + 1) % 4;
        end
        if (accept_read) begin
            expected_read = model[model_read];
            model_read = (model_read + 1) % 4;
        end
        model_count = model_count + accept_write - accept_read;

        check(count == model_count[2:0], "count mismatch");
        check(empty == (model_count == 0), "empty mismatch");
        check(full == (model_count == 4), "full mismatch");
        if (accept_read)
            check(rd_data == expected_read, "read data mismatch");
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        #1ns rst_n = 1'b1;

        // Fill, reject overflow, read two, wrap pointers, perform a simultaneous
        // read/write, drain, and finally reject an underflow request.
        transact(1, 0, 8'h11);
        transact(1, 0, 8'h22);
        transact(1, 0, 8'h33);
        transact(1, 0, 8'h44);
        transact(1, 0, 8'hFF);
        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);
        transact(1, 0, 8'h55);
        transact(1, 1, 8'h66);
        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);
        transact(0, 1, 8'h00);

        @(negedge clk);
        wr_en = 0;
        rd_en = 0;
        #1ns sv_done = 1'b1;
        $display("SV_TEST_SUMMARY passed=%0d failed=%0d",
                 sv_tests_passed, sv_tests_failed);
`ifdef SV_ONLY
        $display("SystemVerilog FIFO test passed");
        $finish;
`endif
    end
endmodule
