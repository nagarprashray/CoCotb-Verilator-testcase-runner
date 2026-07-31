// ============================================================================
// Transaction Tracker Module
// ============================================================================

module transaction_tracker #(
    parameter ID_WIDTH       = 4,
    parameter ADDR_WIDTH     = 32,
    parameter TIMEOUT_CYCLES = 1024
)(
    input  wire                  aclk,
    input  wire                  aresetn,
    input  wire                  alloc_req,
    input  wire                  dealloc_req,
    input  wire [ID_WIDTH-1:0]   dealloc_id,
    output reg  [ID_WIDTH-1:0]   alloc_id,
    output reg                  id_valid
);

    localparam NUM_IDS = 1 << ID_WIDTH;
    reg [NUM_IDS-1:0] id_table;
    integer i;

    always @(*) begin
        alloc_id = 0; id_valid = 1'b0;
        for (i = 0; i < NUM_IDS; i = i + 1) begin
            if (!id_table[i] && !id_valid) begin
                alloc_id = i[ID_WIDTH-1:0];
                id_valid = 1'b1;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) id_table <= {NUM_IDS{1'b0}};
        else begin
            if (alloc_req && id_valid)   id_table[alloc_id]  <= 1'b1;
            if (dealloc_req)             id_table[dealloc_id] <= 1'b0;
        end
    end
endmodule