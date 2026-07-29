// ============================================================================
// Reset Synchronizer Module
// ============================================================================

module reset_sync (
    input  wire pclk,
    input  wire aclk,
    input  wire presetn,
    input  wire aresetn,
    output wire presetn_sync,
    output wire aresetn_sync
);
    reg p_sync1, p_sync2;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin p_sync1 <= 0; p_sync2 <= 0; end
        else          begin p_sync1 <= 1; p_sync2 <= p_sync1; end
    end
    assign presetn_sync = p_sync2;

    reg a_sync1, a_sync2;
    always @(posedge aclk) begin
        if (!aresetn) begin a_sync1 <= 0; a_sync2 <= 0; end
        else          begin a_sync1 <= 1; a_sync2 <= a_sync1; end
    end
    assign aresetn_sync = a_sync2;
endmodule