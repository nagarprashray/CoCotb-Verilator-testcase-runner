`timescale 1ns / 1ps
// ============================================================================
// Functional smoke testbench for the golden APB-to-AXI4 bridge
// ============================================================================
// Confirms that the corrected design elaborates, clocks, resets, and simulates.
// ============================================================================

module tb_apb_axi4;

    // Parameters
    parameter DATA_WIDTH     = 32;
    parameter ADDR_WIDTH     = 32;
    parameter ID_WIDTH       = 4;
    parameter FIFO_DEPTH     = 4;
    parameter TIMEOUT_CYCLES = 1024;
    
    parameter CLK_PERIOD_APB = 10;  // 100 MHz
    parameter CLK_PERIOD_AXI = 8;   // 125 MHz
    
    // Clock and Reset
    reg pclk;
    reg aclk;
    reg presetn;
    reg aresetn;
    
    // APB Interface
    reg  [ADDR_WIDTH-1:0] paddr;
    reg                   psel;
    reg                   penable;
    reg                   pwrite;
    reg  [DATA_WIDTH-1:0] pwdata;
    reg  [2:0]            pprot;
    wire [DATA_WIDTH-1:0] prdata;
    wire                  pready;
    wire                  pslverr;
    
    // AXI Write Address Channel
    wire [ID_WIDTH-1:0]   awid;
    wire [ADDR_WIDTH-1:0] awaddr;
    wire [7:0]            awlen;
    wire [2:0]            awsize;
    wire [1:0]            awburst;
    wire                  awlock;
    wire [3:0]            awcache;
    wire [2:0]            awprot;
    wire                  awvalid;
    reg                   awready;
    
    // AXI Write Data Channel
    wire [DATA_WIDTH-1:0]   wdata;
    wire [DATA_WIDTH/8-1:0] wstrb;
    wire                    wlast;
    wire                    wvalid;
    reg                     wready;
    
    // AXI Write Response Channel
    reg  [ID_WIDTH-1:0] bid;
    reg  [1:0]          bresp;
    reg                 bvalid;
    wire                bready;
    
    // AXI Read Address Channel
    wire [ID_WIDTH-1:0]   arid;
    wire [ADDR_WIDTH-1:0] araddr;
    wire [7:0]            arlen;
    wire [2:0]            arsize;
    wire [1:0]            arburst;
    wire                  arlock;
    wire [3:0]            arcache;
    wire [2:0]            arprot;
    wire                  arvalid;
    reg                   arready;
    
    // AXI Read Data Channel
    reg  [ID_WIDTH-1:0]   rid;
    reg  [DATA_WIDTH-1:0] rdata;
    reg  [1:0]            rresp;
    reg                   rlast;
    reg                   rvalid;
    wire                  rready;
    
    // DUT Instantiation
    apb_axi_bridge_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
    ) dut (
        .pclk(pclk), .presetn(presetn),
        .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite),
        .pwdata(pwdata), .pprot(pprot),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .aclk(aclk), .aresetn(aresetn),
        .awid(awid), .awaddr(awaddr), .awlen(awlen), .awsize(awsize),
        .awburst(awburst), .awlock(awlock), .awcache(awcache), .awprot(awprot),
        .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wlast(wlast), .wvalid(wvalid), .wready(wready),
        .bid(bid), .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .arid(arid), .araddr(araddr), .arlen(arlen), .arsize(arsize),
        .arburst(arburst), .arlock(arlock), .arcache(arcache), .arprot(arprot),
        .arvalid(arvalid), .arready(arready),
        .rid(rid), .rdata(rdata), .rresp(rresp), .rlast(rlast),
        .rvalid(rvalid), .rready(rready)
    );
    
    // Clock Generation
    initial begin
        pclk = 0;
        forever #(CLK_PERIOD_APB/2) pclk = ~pclk;
    end
    
    initial begin
        aclk = 0;
        forever #(CLK_PERIOD_AXI/2) aclk = ~aclk;
    end
    
    // Test Sequence
    initial begin
        $display("========================================");
        $display("TC-1.1.1_02: Golden Functional Smoke Test");
        $display("========================================");
        $display("Expected: corrected design reaches simulation");
        $display("");
        
        // Initialize signals
        presetn = 0;
        aresetn = 0;
        paddr   = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        pwdata  = 0;
        pprot   = 0;
        
        awready = 0;
        wready  = 0;
        bid     = 0;
        bresp   = 0;
        bvalid  = 0;
        arready = 0;
        rid     = 0;
        rdata   = 0;
        rresp   = 0;
        rlast   = 0;
        rvalid  = 0;
        
        // Release reset
        #100;
        presetn = 1;
        aresetn = 1;
        #100;
        
        $display("[PASS] Golden design compiled and completed reset smoke test");
        $display("SV_TEST_SUMMARY passed=1 failed=0");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("[TIMEOUT] Testbench timeout reached");
        $finish;
    end

endmodule
