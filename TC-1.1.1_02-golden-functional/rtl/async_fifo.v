// ============================================================================
// Asynchronous FIFO with Gray Code Pointers
// ============================================================================

module async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 4,
    parameter ADDR_WIDTH = $clog2(FIFO_DEPTH)
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,
    
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty
);

    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray, rd_ptr_bin, rd_ptr_gray;
    reg [ADDR_WIDTH:0] rd_p_gray_sync1, rd_p_gray_sync2, wr_p_gray_sync1, wr_p_gray_sync2;

    function [ADDR_WIDTH:0] bin2gray(input [ADDR_WIDTH:0] bin);
        bin2gray = bin ^ (bin >> 1);
    endfunction

    // Write Logic
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin wr_ptr_bin <= 0; wr_ptr_gray <= 0; end
        else if (wr_en && !full) begin
            wr_ptr_bin  <= wr_ptr_bin + 1'b1;
            wr_ptr_gray <= bin2gray(wr_ptr_bin + 1'b1);
        end
    end

    always @(posedge wr_clk) if (wr_en && !full) mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;

    // Read Synchronization
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin rd_p_gray_sync1 <= 0; rd_p_gray_sync2 <= 0; end
        else           begin rd_p_gray_sync1 <= rd_ptr_gray; rd_p_gray_sync2 <= rd_p_gray_sync1; end
    end

    assign full = (wr_ptr_gray == {~rd_p_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], rd_p_gray_sync2[ADDR_WIDTH-2:0]});

    // Read Logic
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin rd_ptr_bin <= 0; rd_ptr_gray <= 0; end
        else if (rd_en && !empty) begin
            rd_ptr_bin  <= rd_ptr_bin + 1'b1;
            rd_ptr_gray <= bin2gray(rd_ptr_bin + 1'b1);
        end
    end

    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    // Write Synchronization
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin wr_p_gray_sync1 <= 0; wr_p_gray_sync2 <= 0; end
        else           begin wr_p_gray_sync1 <= wr_ptr_gray; wr_p_gray_sync2 <= wr_p_gray_sync1; end
    end

    assign empty = (rd_ptr_gray == wr_p_gray_sync2);

endmodule