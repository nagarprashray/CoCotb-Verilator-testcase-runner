# Verilator + cocotb testcase runner

This repository runs structured RTL testcase folders with Verilator. A testcase may
contain a SystemVerilog testbench, a cocotb Python test, or both. Testcase folders can
be inside or outside this repository.

## Required tools

Install these tools on the Windows host:

- Docker Desktop configured for Linux containers
- PowerShell 5.1 or newer
- WSL 2 and hardware virtualization support required by Docker Desktop
- Internet access for the first Docker image build

Verilator, Python, cocotb, GCC, and GNU Make are installed inside the Docker image;
they do not need to be installed directly on Windows.

## Testcase folder structure

Each testcase must follow this layout:

```text
TC-.../
  rtl/                 Required DUT .v and/or .sv files
  tb/                  SV testbench files and/or cocotb .py files
  sim/                 Optional testcase-specific scripts
  meta.json            Test metadata
```

All `.v` and `.sv` files directly under `rtl/` are compiled as DUT sources. Files
directly under `tb/` are treated as SV testbench sources. Python tests are discovered
recursively in the testcase folder, with `tb/`, `tests/`, and `python_tb/` added to
`PYTHONPATH`.

The DUT top module comes from `meta.json` field `target_module`. If that field is
absent, the runner uses the first module declared in the RTL. The first module
declared in the SV testbench files is used as the SV simulation top.

## Run a testcase

Start Docker Desktop, open PowerShell in this repository, and provide the testcase
folder path.

Testcase inside this repository:

```powershell
.\run.ps1 ".\TC-1.1.1_01-missing-apb-pclk"
```

Absolute external path:

```powershell
.\run.ps1 "D:\rtl-testcases\TC-1.1.1_01-missing-apb-pclk"
```

Relative external path:

```powershell
.\run.ps1 "..\rtl-testcases\TC-1.1.1_01-missing-apb-pclk"
```

If PowerShell blocks local scripts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1 `
  "D:\rtl-testcases\TC-1.1.1_01-missing-apb-pclk"
```

External testcase folders are mounted read-only at `/testcase`. The runner never
writes generated files into an external testcase folder.

## Testbench modes

The default `auto` mode selects a mode from the files present:

- SV and Python testbenches found: `both`
- Only Python found: `python`
- Only SV found: `sv`

You may select a mode explicitly:

```powershell
.\run.ps1 "D:\rtl-testcases\TC-example" both
.\run.ps1 "D:\rtl-testcases\TC-example" python
.\run.ps1 "D:\rtl-testcases\TC-example" sv
```

- `both` runs the SV testbench and cocotb together through Verilator VPI.
- `python` compiles the DUT only; cocotb must generate the required stimulus.
- `sv` uses Verilator's standalone `--binary` flow and does not require Python.

The runner reports a clear error when the selected mode requires a testbench that is
not present.

## Expected compile-failure testcases

Negative compile-time tests are supported. If `meta.json` contains a compile-failure
expectation such as:

```json
{
  "target_module": "apb_axi_bridge_top",
  "expected_symptom": "Compile Fail due to missing port",
  "detection_phase": "Compile-time"
}
```

a Verilator compilation failure is counted as a passing validation. The log marks it
with:

```text
EXPECTED_COMPILE_FAILURE_RESULT expected-failure
```

Unexpected compilation success makes the testcase fail.

## Results

Each testcase gets its own result directory based on the testcase folder name:

```text
results/<testcase-name>/
  results.xml       cocotb/JUnit results when Python runs
  simulation.log    complete Verilator and testbench output
  test_report.txt   readable Python, SV, and combined summary
```

Example report:

```text
Verification Report
===================
Example: TC-1.1.1_01-missing-apb-pclk
Mode: sv
Status: PASS

Python/cocotb: total=0 passed=0 failed=0 skipped=0
SystemVerilog: passed=1 failed=0
Combined: passed=1 failed=0
```

Generated `results/` and `sim_build/` directories are ignored by Git.

## How the runner works

1. Validates the testcase structure.
2. Discovers RTL, SV, and Python files.
3. Reads metadata and determines top modules.
4. Automatically chooses or validates the requested testbench mode.
5. Builds or reuses the local `cocotb-verilator-local` Docker image.
6. Mounts this repository at `/work` and an external testcase at `/testcase`.
7. Compiles and runs Verilator.
8. Writes the simulator log and consolidated report under `results/<testcase-name>/`.

## Troubleshooting

- **Cannot connect to Docker:** start Docker Desktop and wait for initialization.
- **No RTL files found:** ensure `.v` or `.sv` files are directly under `rtl/`.
- **No testbench found:** place SV or Python test files in the testcase structure.
- **Wrong top module:** set `target_module` correctly in `meta.json`.
- **PowerShell execution disabled:** use the `-ExecutionPolicy Bypass` command above.
- **First run is slow:** Docker must download and build the tool image; later runs use
  cached layers.
