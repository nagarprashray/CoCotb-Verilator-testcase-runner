import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge


TRANSACTIONS = [
    (1, 0, 0x11), (1, 0, 0x22), (1, 0, 0x33), (1, 0, 0x44),
    (1, 0, 0xFF), (0, 1, 0x00), (0, 1, 0x00), (1, 0, 0x55),
    (1, 1, 0x66), (0, 1, 0x00), (0, 1, 0x00), (0, 1, 0x00),
    (0, 1, 0x00), (0, 1, 0x00),
]


async def check_outputs(dut, queue, expected_read, accepted_read):
    await ReadOnly()
    assert dut.count.value.to_unsigned() == len(queue)
    assert int(dut.empty.value) == (len(queue) == 0)
    assert int(dut.full.value) == (len(queue) == 4)
    if accepted_read:
        assert dut.rd_data.value.to_unsigned() == expected_read


async def python_only_test(dut):
    """Generate FIFO stimulus when no SystemVerilog testbench is present."""
    queue = []
    dut.rst_n.value = 0
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.wr_data.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1

    for write_request, read_request, write_data in TRANSACTIONS:
        await FallingEdge(dut.clk)
        dut.wr_en.value = write_request
        dut.rd_en.value = read_request
        dut.wr_data.value = write_data

        accepted_write = write_request and len(queue) < 4
        accepted_read = read_request and len(queue) > 0
        expected_read = queue.pop(0) if accepted_read else 0
        if accepted_write:
            queue.append(write_data)

        await RisingEdge(dut.clk)
        await check_outputs(dut, queue, expected_read, accepted_read)


@cocotb.test()
async def fifo_scoreboard(dut):
    """Model every accepted transaction independently of the SV scoreboard."""

    if not hasattr(dut, "sv_done"):
        await python_only_test(dut)
        return

    queue = []
    expected_read = 0
    await RisingEdge(dut.rst_n)

    while not dut.sv_done.value:
        await RisingEdge(dut.clk)
        write_request = int(dut.wr_en.value)
        read_request = int(dut.rd_en.value)
        write_data = dut.wr_data.value.to_unsigned()

        accept_write = write_request and len(queue) < 4
        accept_read = read_request and len(queue) > 0
        if accept_read:
            expected_read = queue.pop(0)
        if accept_write:
            queue.append(write_data)

        await check_outputs(dut, queue, expected_read, accept_read)
