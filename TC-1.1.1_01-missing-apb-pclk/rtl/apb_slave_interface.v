// ============================================================================
// APB Slave Interface Module - FIXED TYPOS
// ============================================================================

module apb_slave_interface #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  wire                                             pclk,
    input  wire                                             presetn,
    input  wire [ADDR_WIDTH-1:0]                            paddr,
    input  wire                                             psel,
    input  wire                                             penable,
    input  wire                                             pwrite,
    input  wire [DATA_WIDTH-1:0]                            pwdata,
    input  wire [2:0]                                       pprot,
    output reg  [DATA_WIDTH-1:0]                            prdata,
    output reg                                              pready,
    output reg                                              pslverr,
    
    output reg  [ADDR_WIDTH+DATA_WIDTH+(DATA_WIDTH/8)+3-1:0] wr_cmd_fifo_din,
    output reg                                              wr_cmd_fifo_wr_en,
    input  wire                                             wr_cmd_fifo_full,
    
    output reg  [ADDR_WIDTH+3-1:0]                          rd_cmd_fifo_din,
    output reg                                              rd_cmd_fifo_wr_en,
    input  wire                                             rd_cmd_fifo_full,
    
    input  wire [DATA_WIDTH+2-1:0]                          rd_resp_fifo_dout,
    output reg                                              rd_resp_fifo_rd_en,
    input  wire                                             rd_resp_fifo_empty
);

    localparam IDLE      = 2'b00;
    localparam WAIT_FIFO = 2'b01;
    localparam ACCESS    = 2'b10;
    
    reg [1:0] state, next_state;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) state <= IDLE;
        else          state <= next_state;
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:      if (psel && !penable) next_state = WAIT_FIFO;
            WAIT_FIFO: begin
                if (pwrite) begin
                    if (!wr_cmd_fifo_full) next_state = ACCESS;
                end else begin
                    // FIX 1: Changed from rd_cmd_fifo_empty to rd_resp_fifo_empty
                    if (!rd_resp_fifo_empty) next_state = ACCESS;
                end
            end
            ACCESS:    if (penable && pready) next_state = IDLE;
            default:   next_state = IDLE;
        endcase
    end
    
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pready <= 1'b0; prdata <= 0; pslverr <= 1'b0;
            wr_cmd_fifo_wr_en <= 1'b0; rd_cmd_fifo_wr_en <= 1'b0; rd_resp_fifo_rd_en <= 1'b0;
            wr_cmd_fifo_din <= 0; rd_cmd_fifo_din <= 0;
        end else begin
            // Default pulse clearances
            wr_cmd_fifo_wr_en  <= 1'b0;
            rd_cmd_fifo_wr_en  <= 1'b0;
            rd_resp_fifo_rd_en <= 1'b0; // FIX 2: Removed rd_resp_fifo_wr_en line entirely
            pready             <= 1'b0;

            case (state)
                IDLE: begin
                    pslverr <= 1'b0;
                    if (psel && !penable) begin
                        if (!pwrite && !rd_cmd_fifo_full) begin
                            rd_cmd_fifo_din   <= {paddr, pprot};
                            rd_cmd_fifo_wr_en <= 1'b1;
                        end
                    end
                end
                
                WAIT_FIFO: begin
                    if (pwrite && !wr_cmd_fifo_full) begin
                        wr_cmd_fifo_din   <= {paddr, pwdata, {DATA_WIDTH/8{1'b1}}, pprot};
                        wr_cmd_fifo_wr_en <= 1'b1;
                    end
                end
                
                ACCESS: begin
                    pready <= 1'b1;
                    if (!pwrite) begin
                        prdata  <= rd_resp_fifo_dout[DATA_WIDTH+1:2];
                        pslverr <= |rd_resp_fifo_dout[1:0];
                        
                        if (penable) begin
                            rd_resp_fifo_rd_en <= 1'b1;
                        end
                    end else begin
                        pslverr <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule