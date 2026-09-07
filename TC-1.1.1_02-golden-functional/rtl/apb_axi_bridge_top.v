`timescale 1ns / 10ps
// ============================================================================
// APB to AXI4 Bridge - Top Level Module
// ============================================================================

module apb_axi_bridge_top #(
    parameter DATA_WIDTH     = 32,
    parameter ADDR_WIDTH     = 32,
    parameter ID_WIDTH       = 4,
    parameter FIFO_DEPTH     = 4,
    parameter TIMEOUT_CYCLES = 1024
)(
    // APB Clock Domain
    input  wire                      pclk,
    input  wire                      presetn,
    input  wire [ADDR_WIDTH-1:0]    paddr,
    input  wire                      psel,
    input  wire                      penable,
    input  wire                      pwrite,
    input  wire [DATA_WIDTH-1:0]    pwdata,
    input  wire [2:0]               pprot,
    output wire [DATA_WIDTH-1:0]    prdata,
    output wire                      pready,
    output wire                      pslverr,
    
    // AXI Clock Domain
    input  wire                      aclk,
    input  wire                      aresetn,
    
    // AXI Write Address Channel
    output wire [ID_WIDTH-1:0]      awid,
    output wire [ADDR_WIDTH-1:0]    awaddr,
    output wire [7:0]               awlen,
    output wire [2:0]               awsize,
    output wire [1:0]               awburst,
    output wire                      awlock,
    output wire [3:0]               awcache,
    output wire [2:0]               awprot,
    output wire                      awvalid,
    input  wire                      awready,
    
    // AXI Write Data Channel
    output wire [DATA_WIDTH-1:0]    wdata,
    output wire [DATA_WIDTH/8-1:0]  wstrb,
    output wire                      wlast,
    output wire                      wvalid,
    input  wire                      wready,
    
    // AXI Write Response Channel
    input  wire [ID_WIDTH-1:0]      bid,
    input  wire [1:0]               bresp,
    input  wire                      bvalid,
    output wire                      bready,
    
    // AXI Read Address Channel
    output wire [ID_WIDTH-1:0]      arid,
    output wire [ADDR_WIDTH-1:0]    araddr,
    output wire [7:0]               arlen,
    output wire [2:0]               arsize,
    output wire [1:0]               arburst,
    output wire                      arlock,
    output wire [3:0]               arcache,
    output wire [2:0]               arprot,
    output wire                      arvalid,
    input  wire                      arready,
    
    // AXI Read Data Channel
    input  wire [ID_WIDTH-1:0]      rid,
    input  wire [DATA_WIDTH-1:0]    rdata,
    input  wire [1:0]               rresp,
    input  wire                      rlast,
    input  wire                      rvalid,
    output wire                      rready
);

    // Dynamic sizing helper parameters
    localparam WR_CMD_WIDTH  = ADDR_WIDTH + DATA_WIDTH + (DATA_WIDTH/8) + 3; // 71 bits
    localparam RD_CMD_WIDTH  = ADDR_WIDTH + 3;                              // 35 bits
    localparam RD_RESP_WIDTH = DATA_WIDTH + 2;                              // 34 bits

    // Internal signal interconnections
    wire [WR_CMD_WIDTH-1:0]  wr_cmd_fifo_din,  wr_cmd_fifo_dout;
    wire [RD_CMD_WIDTH-1:0]  rd_cmd_fifo_din,  rd_cmd_fifo_dout;
    wire [RD_RESP_WIDTH-1:0] rd_resp_fifo_din, rd_resp_fifo_dout;

    wire wr_cmd_fifo_wr_en,  wr_cmd_fifo_rd_en,  wr_cmd_fifo_full,  wr_cmd_fifo_empty;
    wire rd_cmd_fifo_wr_en,  rd_cmd_fifo_rd_en,  rd_cmd_fifo_full,  rd_cmd_fifo_empty;
    wire rd_resp_fifo_wr_en, rd_resp_fifo_rd_en, rd_resp_fifo_full, rd_resp_fifo_empty;

    wire presetn_sync, aresetn_sync;
    wire [ID_WIDTH-1:0] alloc_id, tracker_dealloc_id;
    wire id_valid, id_alloc_req, id_dealloc_req;

    // APB Slave Interface Block
    apb_slave_interface #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_apb_slave (
        .pclk(pclk),
        .presetn(presetn_sync),
        .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata), .pprot(pprot),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .wr_cmd_fifo_din(wr_cmd_fifo_din), .wr_cmd_fifo_wr_en(wr_cmd_fifo_wr_en), .wr_cmd_fifo_full(wr_cmd_fifo_full),
        .rd_cmd_fifo_din(rd_cmd_fifo_din), .rd_cmd_fifo_wr_en(rd_cmd_fifo_wr_en), .rd_cmd_fifo_full(rd_cmd_fifo_full),
        .rd_resp_fifo_dout(rd_resp_fifo_dout), .rd_resp_fifo_rd_en(rd_resp_fifo_rd_en), .rd_resp_fifo_empty(rd_resp_fifo_empty)
    );

    // AXI Master Interface Block
    axi_master_interface #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) u_axi_master (
        .aclk(aclk), .aresetn(aresetn_sync),
        .awid(awid), .awaddr(awaddr), .awlen(awlen), .awsize(awsize), .awburst(awburst), .awlock(awlock), .awcache(awcache), .awprot(awprot), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
        .bid(bid), .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .arid(arid), .araddr(araddr), .arlen(arlen), .arsize(arsize), .arburst(arburst), .arlock(arlock), .arcache(arcache), .arprot(arprot), .arvalid(arvalid), .arready(arready),
        .rid(rid), .rdata(rdata), .rresp(rresp), .rlast(rlast), .rvalid(rvalid), .rready(rready),
        .wr_cmd_fifo_dout(wr_cmd_fifo_dout), .wr_cmd_fifo_rd_en(wr_cmd_fifo_rd_en), .wr_cmd_fifo_empty(wr_cmd_fifo_empty),
        .rd_cmd_fifo_dout(rd_cmd_fifo_dout), .rd_cmd_fifo_rd_en(rd_cmd_fifo_rd_en), .rd_cmd_fifo_empty(rd_cmd_fifo_empty),
        .rd_resp_fifo_din(rd_resp_fifo_din), .rd_resp_fifo_wr_en(rd_resp_fifo_wr_en), .rd_resp_fifo_full(rd_resp_fifo_full),
        .alloc_id(alloc_id), .id_valid(id_valid), .id_alloc_req(id_alloc_req), .id_dealloc_req(id_dealloc_req),
        .tracker_dealloc_id(tracker_dealloc_id)
    );

    // Write Command FIFO CDC (pclk -> aclk)
    async_fifo #(.DATA_WIDTH(WR_CMD_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) u_wr_cmd_fifo (
        .wr_clk(pclk), .wr_rst_n(presetn_sync), .wr_en(wr_cmd_fifo_wr_en), .wr_data(wr_cmd_fifo_din), .full(wr_cmd_fifo_full),
        .rd_clk(aclk), .rd_rst_n(aresetn_sync), .rd_en(wr_cmd_fifo_rd_en), .rd_data(wr_cmd_fifo_dout), .empty(wr_cmd_fifo_empty)
    );

    // Read Command FIFO CDC (pclk -> aclk)
    async_fifo #(.DATA_WIDTH(RD_CMD_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) u_rd_cmd_fifo (
        .wr_clk(pclk), .wr_rst_n(presetn_sync), .wr_en(rd_cmd_fifo_wr_en), .wr_data(rd_cmd_fifo_din), .full(rd_cmd_fifo_full),
        .rd_clk(aclk), .rd_rst_n(aresetn_sync), .rd_en(rd_cmd_fifo_rd_en), .rd_data(rd_cmd_fifo_dout), .empty(rd_cmd_fifo_empty)
    );

    // Read Response FIFO CDC (aclk -> pclk)
    async_fifo #(.DATA_WIDTH(RD_RESP_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) u_rd_resp_fifo (
        .wr_clk(aclk), .wr_rst_n(aresetn_sync), .wr_en(rd_resp_fifo_wr_en), .wr_data(rd_resp_fifo_din), .full(rd_resp_fifo_full),
        .rd_clk(pclk), .rd_rst_n(presetn_sync), .rd_en(rd_resp_fifo_rd_en), .rd_data(rd_resp_fifo_dout), .empty(rd_resp_fifo_empty)
    );

    // Clock Domain Reset Synchronizer
    reset_sync u_reset_sync (
        .pclk(pclk), .aclk(aclk),
        .presetn(presetn), .aresetn(aresetn),
        .presetn_sync(presetn_sync), .aresetn_sync(aresetn_sync)
    );

    // Transaction ID and Watchdog Tracker Module
    transaction_tracker #(
        .ID_WIDTH(ID_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
    ) u_transaction_tracker (
        .aclk(aclk), .aresetn(aresetn_sync),
        .alloc_req(id_alloc_req), .dealloc_req(id_dealloc_req), .dealloc_id(tracker_dealloc_id),
        .alloc_id(alloc_id), .id_valid(id_valid)
    );

endmodule
