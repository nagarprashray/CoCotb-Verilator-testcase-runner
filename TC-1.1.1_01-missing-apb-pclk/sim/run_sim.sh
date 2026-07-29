#!/bin/bash
# ============================================================================
# Simulation Script for TC-1.1.1_01 - Missing APB Clock
# ============================================================================
# This script attempts to compile and simulate the faulty RTL design.
# Expected outcome: Compilation failure with `default_nettype none enabled.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"
RTL_DIR="$TEST_ROOT/rtl"
TB_DIR="$TEST_ROOT/tb"
SIM_DIR="$SCRIPT_DIR"

echo "=========================================="
echo "TC-1.1.1_01: Missing APB Clock Simulation"
echo "=========================================="
echo ""

# Create work directory
mkdir -p "$SIM_DIR/work"
cd "$SIM_DIR/work"

echo "[INFO] Compiling RTL files..."
echo ""

# Attempt compilation with iverilog (expects failure)
iverilog -g2012 \
    -o apb_axi_bridge.vvp \
    "$RTL_DIR/apb_slave_interface.v" \
    "$RTL_DIR/async_fifo.v" \
    "$RTL_DIR/axi_master_interface.v" \
    "$RTL_DIR/reset_sync.v" \
    "$RTL_DIR/transaction_tracker.v" \
    "$RTL_DIR/apb_axi_bridge_top.v" \
    "$TB_DIR/tb_apb_axi4.v" 2>&1 | tee compile.log

COMPILE_STATUS=$?

if [ $COMPILE_STATUS -ne 0 ]; then
    echo ""
    echo "[EXPECTED] Compilation failed as predicted for TC-1.1.1_01"
    echo "[RESULT] Test case validation: PASS (fault correctly prevents compilation)"
    echo ""
    echo "Compilation errors logged to: $SIM_DIR/work/compile.log"
    exit 0
else
    echo ""
    echo "[UNEXPECTED] Compilation succeeded - this indicates the fault was not injected correctly"
    echo "[RESULT] Test case validation: FAIL"
    echo ""
    
    # If compilation unexpectedly succeeds, try to run simulation
    echo "[INFO] Running simulation (unexpected path)..."
    vvp apb_axi_bridge.vvp
    exit 1
fi
