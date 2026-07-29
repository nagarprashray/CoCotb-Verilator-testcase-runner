import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge


@cocotb.test()
async def counter_counts(dut):
    """Independently verify the values checked by the SV testbench."""

    if not hasattr(dut, "sv_done"):
        # Python-only mode: cocotb owns clock and reset generation.
        dut.rst_n.value = 0
        cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        dut.rst_n.value = 1
    else:
        # Combined mode: the SV testbench owns clock and reset generation.
        await RisingEdge(dut.rst_n)

    # Sample on falling edges, after the DUT updates count on each rising edge.
    for expected in range(1, 11):
        await FallingEdge(dut.clk)
        assert dut.count.value.to_unsigned() == expected

    if hasattr(dut, "sv_done"):
        # Confirm that the SystemVerilog testbench also completed all ten checks.
        await RisingEdge(dut.sv_done)
        assert dut.sv_done.value == 1, "SystemVerilog testbench did not complete"
