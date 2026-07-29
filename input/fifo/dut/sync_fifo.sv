// Four-entry synchronous FIFO with guarded read and write operations.
module sync_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 4
) (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   wr_en,
    input  logic                   rd_en,
    input  logic [WIDTH-1:0]       wr_data,
    output logic [WIDTH-1:0]       rd_data,
    output logic                   full,
    output logic                   empty,
    output logic [$clog2(DEPTH):0] count
);
    localparam int PTR_WIDTH = $clog2(DEPTH);
    typedef logic [PTR_WIDTH:0] count_t;
    localparam count_t DEPTH_COUNT = count_t'(DEPTH);

    logic [WIDTH-1:0] memory [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] write_ptr;
    logic [PTR_WIDTH-1:0] read_ptr;

    assign empty = (count == 0);
    assign full  = (count == DEPTH_COUNT);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            write_ptr <= '0;
            read_ptr  <= '0;
            rd_data   <= '0;
            count     <= '0;
        end else begin
            // A request is accepted only when its corresponding boundary flag
            // permits it. Simultaneous accepted read/write keeps count stable.
            if (wr_en && !full) begin
                memory[write_ptr] <= wr_data;
                write_ptr <= write_ptr + 1'b1;
            end

            if (rd_en && !empty) begin
                rd_data <= memory[read_ptr];
                read_ptr <= read_ptr + 1'b1;
            end

            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
