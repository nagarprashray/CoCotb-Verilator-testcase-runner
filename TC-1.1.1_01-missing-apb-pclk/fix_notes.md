# TC-1.1.1_01: Missing APB Clock Connection - Analysis & Remediation

## Root Cause Analysis

### Fault Description
The `pclk` port connection is completely omitted from the `u_apb_slave` module instantiation in the top-level bridge wrapper. This represents a critical structural connectivity fault where the APB clock domain's primary clock signal is not propagated to the slave interface logic.

### Technical Details
- **Location**: `apb_axi_bridge_top.v`, line 99 (u_apb_slave instantiation)
- **Missing Connection**: `.pclk(pclk)`
- **Fault Classification**: Named port connection omission
- **Detection Method**: Compile-time error when using `default_nettype none

### Why This Fails
In Verilog, when `default_nettype none is specified, all nets must be explicitly declared. An unconnected input port on a module instantiation causes the compiler to look for an implicit net declaration, which is prohibited under this directive. This design practice is critical for catching connectivity errors early.

## System Impact

### Immediate Consequences
1. **Compilation Failure**: Design cannot pass elaboration phase
2. **Clock Domain Isolation**: APB domain completely disconnected from timing source
3. **Protocol Violation**: APB slave cannot sample control signals (psel, penable, pwrite)
4. **State Machine Lockup**: Internal FSM in apb_slave_interface cannot advance

### Downstream Effects
- Write command FIFO (u_wr_cmd_fifo) would never receive valid write-side clock
- Read command FIFO (u_rd_cmd_fifo) would never receive valid write-side clock
- APB transactions would timeout indefinitely
- pready signal would remain deasserted permanently

## Remediation Steps

### Fix Implementation
```verilog
// BEFORE (Faulty):
) u_apb_slave (
    // .pclk(pclk),  // FAULT INJECTION: TC-1.1.1_01 - Missing clock connection
    .presetn(presetn_sync),

// AFTER (Corrected):
) u_apb_slave (
    .pclk(pclk),
    .presetn(presetn_sync),
```

### Verification Checklist
- [ ] Compilation passes with `default_nettype none enabled
- [ ] APB slave interface receives clock edges in simulation
- [ ] APB write transactions complete successfully
- [ ] APB read transactions return valid data
- [ ] Clock domain crossing FIFOs operate correctly
- [ ] No timing violations in static timing analysis

### Prevention Strategies
1. Enable `default_nettype none in all RTL files
2. Use linting tools to detect unconnected ports
3. Implement port connection checkers in verification environment
4. Require explicit connection of all clock and reset signals
5. Use SystemVerilog interfaces to enforce complete connectivity

## Related Test Cases
- TC-1.1.1_02: Empty pclk connection `.pclk()`
- TC-1.1.1_03: Positional parameter shift causing pclk misalignment
- TC-1.1.1_04-06: Similar faults on AXI master aclk port
