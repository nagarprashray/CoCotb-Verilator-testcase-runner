// ============================================================================
// AXI Master Interface Module - REVISED PRODUCTION VERSION
// ============================================================================

module axi_master_interface #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4
)(
    input  wire                                             aclk,
    input  wire                                             aresetn,
    
    output reg  [ID_WIDTH-1:0]                              awid,
    output reg  [ADDR_WIDTH-1:0]                            awaddr,
    output wire [7:0]                                       awlen,
    output wire [2:0]                                       awsize,
    output wire [1:0]                                       awburst,
    output wire                                             awlock,
    output wire [3:0]                                       awcache,
    output reg  [2:0]                                       awprot,
    output reg                                              awvalid,
    input  wire                                             awready,
    
    output reg  [DATA_WIDTH-1:0]                            wdata,
    output reg  [DATA_WIDTH/8-1:0]                          wstrb,
    output wire                                             wlast,
    output reg                                              wvalid,
    input  wire                                             wready,
    
    input  wire [ID_WIDTH-1:0]                              bid,
    input  wire [1:0]                                       bresp,
    input  wire                                             bvalid,
    output reg                                              bready,
    
    output reg  [ID_WIDTH-1:0]                              arid,
    output reg  [ADDR_WIDTH-1:0]                            araddr,
    output wire [7:0]                                       arlen,
    output wire [2:0]                                       arsize,
    output wire [1:0]                                       arburst,
    output wire                                             arlock,
    output wire [3:0]                                       arcache,
    output reg  [2:0]                                       arprot,
    output reg                                              arvalid,
    input  wire                                             arready,
    
    input  wire [ID_WIDTH-1:0]                              rid,
    input  wire [DATA_WIDTH-1:0]                            rdata,
    input  wire [1:0]                                       rresp,
    input  wire                                             rlast,
    input  wire                                             rvalid,
    output reg                                              rready,
    
    input  wire [ADDR_WIDTH+DATA_WIDTH+(DATA_WIDTH/8)+3-1:0] wr_cmd_fifo_dout,
    output reg                                              wr_cmd_fifo_rd_en,
    input  wire                                             wr_cmd_fifo_empty,
    
    input  wire [ADDR_WIDTH+3-1:0]                          rd_cmd_fifo_dout,
    output reg                                              rd_cmd_fifo_rd_en,
    input  wire                                             rd_cmd_fifo_empty,
    
    output reg  [DATA_WIDTH+2-1:0]                          rd_resp_fifo_din,
    output reg                                              rd_resp_fifo_wr_en,
    input  wire                                             rd_resp_fifo_full,
    
    input  wire [ID_WIDTH-1:0]                              alloc_id,
    input  wire                                             id_valid,
    output reg                                              id_alloc_req,
    output reg                                              id_dealloc_req,
    output reg  [ID_WIDTH-1:0]                              tracker_dealloc_id
);

    assign awlen   = 8'h00; assign awsize  = 3'b010; assign awburst = 2'b01;
    assign awlock  = 1'b0;  assign awcache = 4'b0000; assign wlast   = 1'b1;
    assign arlen   = 8'h00; assign arsize  = 3'b010; assign arburst = 2'b01;
    assign arlock  = 1'b0;  assign arcache = 4'b0000;
    
    localparam WR_IDLE = 2'b00, WR_ADDR = 2'b01, WR_DATA = 2'b10, WR_RESP = 2'b11;
    localparam RD_IDLE = 2'b00, RD_ADDR = 2'b01, RD_DATA = 2'b10;
    
    reg [1:0] wr_state, wr_next_state;
    reg [1:0] rd_state, rd_next_state;
    
    reg wr_alloc, wr_dealloc, rd_alloc, rd_dealloc;

    always @(*) begin
        id_alloc_req = wr_alloc || rd_alloc;
        id_dealloc_req = wr_dealloc || rd_dealloc;
        tracker_dealloc_id = (rd_dealloc) ? rid : bid;
    end

    // Write Channel Logic
    always @(posedge aclk) begin
        if (!aresetn) wr_state <= WR_IDLE;
        else          wr_state <= wr_next_state;
    end

    always @(*) begin
        wr_next_state = wr_state;
        case (wr_state)
            WR_IDLE: if (!wr_cmd_fifo_empty && id_valid) wr_next_state = WR_ADDR;
            WR_ADDR: if (awvalid && awready)             wr_next_state = WR_DATA;
            WR_DATA: if (wvalid && wready)               wr_next_state = WR_RESP;
            WR_RESP: if (bvalid && bready)               wr_next_state = WR_IDLE;
        endcase
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            awid <= 0; awaddr <= 0; awprot <= 0; awvalid <= 0;
            wdata <= 0; wstrb <= 0; wvalid <= 0; bready <= 0;
            wr_cmd_fifo_rd_en <= 0; wr_alloc <= 0; wr_dealloc <= 0;
        end else begin
            wr_cmd_fifo_rd_en <= 0; wr_alloc <= 0; wr_dealloc <= 0;
            case (wr_state)
                WR_IDLE: begin
                    if (!wr_cmd_fifo_empty && id_valid) begin
                        wr_cmd_fifo_rd_en <= 1'b1;
                        wr_alloc          <= 1'b1;
                        awid              <= alloc_id;
                        awaddr            <= wr_cmd_fifo_dout[70:39];
                        wdata             <= wr_cmd_fifo_dout[38:7];
                        wstrb             <= wr_cmd_fifo_dout[6:3];
                        awprot            <= wr_cmd_fifo_dout[2:0];
                        awvalid           <= 1'b1;
                    end
                end
                WR_ADDR: begin
                    if (awvalid && awready) begin
                        awvalid <= 1'b0;
                        wvalid  <= 1'b1;
                    end
                end
                WR_DATA: begin
                    if (wvalid && wready) begin
                        wvalid <= 1'b0;
                        bready <= 1'b1;
                    end
                end
                WR_RESP: begin
                    if (bvalid && bready) begin
                        bready     <= 1'b0;
                        wr_dealloc <= 1'b1;
                    end
                end
            endcase
        end
    end

    // Read Channel Logic
    always @(posedge aclk) begin
        if (!aresetn) rd_state <= RD_IDLE;
        else          rd_state <= rd_next_state;
    end

    always @(*) begin
        rd_next_state = rd_state;
        case (rd_state)
            RD_IDLE: if (!rd_cmd_fifo_empty && id_valid) rd_next_state = RD_ADDR;
            RD_ADDR: if (arvalid && arready)             rd_next_state = RD_DATA;
            RD_DATA: if (rvalid && rready && rlast && !rd_resp_fifo_full) rd_next_state = RD_IDLE;
        endcase
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            arid <= 0; araddr <= 0; arprot <= 0; arvalid <= 0; rready <= 0;
            rd_cmd_fifo_rd_en <= 0; rd_resp_fifo_wr_en <= 0; rd_resp_fifo_din <= 0;
            rd_alloc <= 0; rd_dealloc <= 0;
        end else begin
            rd_cmd_fifo_rd_en  <= 0;
            rd_resp_fifo_wr_en <= 0;
            rd_alloc           <= 0;
            rd_dealloc         <= 0;
            case (rd_state)
                RD_IDLE: begin
                    if (!rd_cmd_fifo_empty && id_valid) begin
                        rd_cmd_fifo_rd_en <= 1'b1;
                        rd_alloc          <= 1'b1;
                        arid              <= alloc_id;
                        araddr            <= rd_cmd_fifo_dout[34:3];
                        arprot            <= rd_cmd_fifo_dout[2:0];
                        arvalid           <= 1'b1;
                    end
                end
                RD_ADDR: begin
                    if (arvalid && arready) begin
                        arvalid <= 1'b0;
                        rready  <= 1'b1;
                    end
                end
                RD_DATA: begin
                    if (rvalid && rready && rlast && !rd_resp_fifo_full) begin
                        rd_resp_fifo_din   <= {rdata, rresp};
                        rd_resp_fifo_wr_en <= 1'b1;
                        rready             <= 1'b0;
                        rd_dealloc         <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule