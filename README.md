# Verilator + cocotb: SystemVerilog and Python testbenches

This repository demonstrates one Verilator simulation in which a SystemVerilog
testbench and a cocotb Python test run together against the same design.

## Prerequisites

Install the following on the Windows host:

- Docker Desktop, configured to use Linux containers
- PowerShell 5.1 or newer
- WSL 2/virtualization support required by Docker Desktop
- Internet access for the first image build

You do **not** need to install Verilator, cocotb, Python, GCC, or Make directly on
Windows. The `Dockerfile` supplies them inside the local container:

- Verilator (from the official `verilator/verilator` image)
- Python 3 and its development libraries
- cocotb 2.x
- GNU Make and the C++ compiler toolchain

## Repository layout

```text
input/
  counter/
    dut/counter.sv             Counter design under test
    sv_tb/tb_counter.sv        Counter SystemVerilog testbench
    python_tb/test_counter.py  Counter cocotb test
  fifo/
    dut/sync_fifo.sv               FIFO design under test
    sv_tb/tb_sync_fifo.sv          FIFO SystemVerilog testbench
    python_tb/test_sync_fifo.py    FIFO cocotb scoreboard
Makefile                Verilator/cocotb build configuration
requirements.txt        Python dependencies used by the image
Dockerfile              Reproducible simulator environment
run.ps1                 Windows build-and-test command
```

## Run the tests

1. Start Docker Desktop and wait until its engine reports that it is running.
2. Open PowerShell in this repository.
3. Run the default counter example:

```powershell
.\run.ps1
```

Run the more complex FIFO example with:

```powershell
.\run.ps1 fifo
```

## Select which testbench runs

The runner accepts an example followed by a testbench mode:

```powershell
.\run.ps1 counter both
.\run.ps1 counter python
.\run.ps1 counter sv

.\run.ps1 fifo both
.\run.ps1 fifo python
.\run.ps1 fifo sv
```

- `both` compiles the SV testbench as the top and runs cocotb alongside it. This
  is the default mode.
- `python` compiles only the DUT. The cocotb test generates all clock, reset, and
  transaction stimulus, so an SV testbench is not required.
- `sv` compiles the DUT and SV testbench with Verilator's standalone `--binary`
  flow. cocotb and a Python test are not required.

The defaults are `counter` and `both`, so `.\run.ps1` remains equivalent to
`.\run.ps1 counter both`.

If local PowerShell policy prevents scripts from running, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1
```

The first run downloads the Verilator base image and builds the local
`cocotb-verilator-local` image. Later runs reuse Docker's cached layers.

The command exits with code `0` when all checks pass and a nonzero code when the
build, an SV assertion, or the Python test fails. A successful result ends with a
cocotb summary similar to:

```text
TESTS=1 PASS=1 FAIL=0 SKIP=0
```

## Verification report

Every run prints a report and writes it under `results/<testcase>/test_report.txt`.
In combined mode it reports each testbench separately and then totals them, for example:

```text
Verification Report
===================
Example: fifo
Mode: both
Status: PASS

Python/cocotb: total=1 passed=1 failed=0 skipped=0
SystemVerilog: passed=48 failed=0
Combined: passed=49 failed=0
```

Each testcase gets an isolated result directory:

```text
results/
  fifo/
    results.xml       Detailed cocotb/JUnit results
    simulation.log    Complete Verilator output and SV summary
    test_report.txt   Readable combined pass/fail report
```

These files are replaced by each run and ignored by Git.

## How it works

`run.ps1` performs these operations:

1. Builds or refreshes the local Docker image.
2. Bind-mounts this repository into the container at `/work`.
3. Runs `make clean` to prevent stale host or simulator artifacts from being reused.
4. Runs `make`, which invokes Verilator and starts cocotb through VPI.

The `Makefile` selects the requested example, then compiles its DUT and SV testbench.
The counter is selected by default; `EXAMPLE=fifo` selects the synchronous FIFO.
Verilator timing support is enabled because the SV testbenches contain clock delays
and event controls.

During simulation:

- The SV testbench instantiates `counter`, generates its clock and reset, checks each
  value with SV assertions, and raises `sv_done` after ten increments.
- The Python test waits for reset release, independently checks the same ten counter
  values through cocotb, and confirms that `sv_done` was raised.
- A failure in either testbench makes the overall command fail.

Compiled simulator files are written to `sim_build/`, while verification outputs go
to `results/`. Both directories are ignored by Git and recreated as needed.

## Run the Docker commands manually

The wrapper is equivalent to:

```powershell
docker build -t cocotb-verilator-local .
docker run --rm --mount "type=bind,source=$PWD,target=/work" cocotb-verilator-local sh -lc "make clean && make EXAMPLE=fifo MODE=python"
```

## Using your own design

1. Create `input/<name>/dut/`, `input/<name>/sv_tb/`, and
   `input/<name>/python_tb/`.
2. Put each of the three input types in its corresponding directory.
3. Update `VERILOG_SOURCES` and `TOPLEVEL` in `Makefile`.
4. Update `COCOTB_TEST_MODULES` for the Python module name.
5. Add the example name to `ValidateSet` in `run.ps1`.
6. Run `.\run.ps1 <name>`.

## Running testcase folders

The runner also accepts repository folders that follow this testcase structure:

```text
TC-.../
  rtl/                 One or more .v or .sv DUT files
  tb/                  SV testbench files and/or cocotb .py files
  sim/                 Optional testcase-specific scripts
  meta.json            Test metadata
```

Run one directly by folder name:

```powershell
.\run.ps1 TC-1.1.1_01-missing-apb-pclk
```

The testcase may also be outside this repository. Pass an absolute path:

```powershell
.\run.ps1 "D:\rtl-testcases\TC-1.1.1_01-missing-apb-pclk"
```

Relative paths outside the repository are also accepted:

```powershell
.\run.ps1 "..\rtl-testcases\TC-1.1.1_01-missing-apb-pclk"
```

External testcase folders are mounted read-only at `/testcase` inside Docker. The
runner does not modify the external source folder; generated files are stored in this
repository under `results/<testcase-folder-name>/` and `sim_build/`.

`auto` mode is the default and selects the available testbench configuration:

- SV and Python files found: `both`
- Only Python found: `python`
- Only SV found: `sv`

All `.v` and `.sv` files directly under `rtl/` are compiled as DUT sources. All
`.v` and `.sv` files directly under `tb/` are compiled as SV testbench sources.
The DUT top comes from `meta.json` field `target_module`; when it is absent, the
first RTL module declaration is used. The first module declared under `tb/` is used
as the SV top. Python module names are taken from discovered `.py` filenames.

For negative compile-time tests, a `meta.json` value such as
`"expected_symptom": "Compile Fail ..."` or `"detection_phase": "Compile-time"`
causes an expected Verilator compilation failure to count as a passing validation.

Outputs for the example above are written to:

```text
results/TC-1.1.1_01-missing-apb-pclk/
```

## Troubleshooting

- **Cannot connect to the Docker daemon:** start Docker Desktop and wait for it to
  finish initializing.
- **PowerShell script execution is disabled:** use the explicit `-ExecutionPolicy
  Bypass` command shown above.
- **Old or incompatible generated files:** `run.ps1` already runs `make clean`; do
  not reuse `sim_build/` between native Windows/MSYS2 and Linux container builds.
- **First run is slow:** Docker must download the base image and Ubuntu/Python
  packages. Subsequent builds should be cached.
