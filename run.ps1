param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TestcasePath,
    [Parameter(Position = 1)]
    [ValidateSet("auto", "both", "python", "sv")][string]$Mode = "auto"
)
$ErrorActionPreference = "Stop"

$workspace = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$candidate = if ([IO.Path]::IsPathRooted($TestcasePath)) {
    $TestcasePath
} else {
    Join-Path $workspace $TestcasePath
}
if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
    throw "Testcase folder does not exist: $TestcasePath"
}
$makeVariables = @()
$expectCompileFailure = $false
$externalCasePath = $null
$caseDisplayName = $TestcasePath

$casePath = (Resolve-Path -LiteralPath $candidate).Path
    $caseDisplayName = Split-Path -Leaf $casePath
    $isInternalCase = $casePath.StartsWith($workspace + [IO.Path]::DirectorySeparatorChar)
    if ($isInternalCase) {
        $relativeCase = $casePath.Substring($workspace.Length).TrimStart([char[]]"\/").Replace('\', '/')
        $containerCasePath = "/work/$relativeCase"
    } else {
        $externalCasePath = $casePath
        $containerCasePath = "/testcase"
    }
    $rtlFiles = @(Get-ChildItem -LiteralPath (Join-Path $casePath 'rtl') -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.v', '.sv' })
    $svFiles = @(Get-ChildItem -LiteralPath (Join-Path $casePath 'tb') -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.v', '.sv' })
    $pythonFiles = @(Get-ChildItem -LiteralPath $casePath -Recurse -File -Filter '*.py' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne '__init__.py' })

    if ($rtlFiles.Count -eq 0) { throw "No .v or .sv DUT files found in $TestcasePath/rtl" }
    if ($Mode -eq 'auto') {
        if ($svFiles.Count -gt 0 -and $pythonFiles.Count -gt 0) { $Mode = 'both' }
        elseif ($pythonFiles.Count -gt 0) { $Mode = 'python' }
        elseif ($svFiles.Count -gt 0) { $Mode = 'sv' }
        else { throw "No testbench found under $TestcasePath" }
    }
    if ($Mode -in 'both', 'sv' -and $svFiles.Count -eq 0) {
        throw "Mode '$Mode' requires a SystemVerilog testbench in $TestcasePath/tb"
    }
    if ($Mode -in 'both', 'python' -and $pythonFiles.Count -eq 0) {
        throw "Mode '$Mode' requires a Python test under $TestcasePath"
    }

    $metaPath = Join-Path $casePath 'meta.json'
    $meta = if (Test-Path -LiteralPath $metaPath) {
        Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
    } else { $null }

    $dutTop = if ($meta -and $meta.target_module) { [string]$meta.target_module } else { '' }
    if (-not $dutTop) {
        $rtlText = ($rtlFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
        $match = [regex]::Match($rtlText, '(?m)^\s*module\s+([A-Za-z_][A-Za-z0-9_$]*)')
        if ($match.Success) { $dutTop = $match.Groups[1].Value }
    }

    $svTop = ''
    if ($svFiles.Count -gt 0) {
        $svText = ($svFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
        $match = [regex]::Match($svText, '(?m)^\s*module\s+([A-Za-z_][A-Za-z0-9_$]*)')
        if ($match.Success) { $svTop = $match.Groups[1].Value }
    }
    $pythonModules = ($pythonFiles | ForEach-Object { $_.BaseName }) -join ','

    if ($Mode -eq 'python' -and -not $dutTop) { throw "Could not discover DUT top module" }
    if ($Mode -in 'both', 'sv' -and -not $svTop) { throw "Could not discover SV top module" }

    if ($meta) {
        $expectCompileFailure = ([string]$meta.expected_symptom -match '(?i)compil\w*\s+fail') -or
            ([string]$meta.detection_phase -match '(?i)compile')
    }

    $makeVariables += "CASE_DIR=$containerCasePath"
    $makeVariables += "CASE_DUT_TOP=$dutTop"
    $makeVariables += "CASE_SV_TOP=$svTop"
    $makeVariables += "CASE_PY_MODULES=$pythonModules"

$resultKey = ($caseDisplayName -replace '[^A-Za-z0-9_.-]', '_')
$resultDirectory = "results/$resultKey"
$makeVariables += "MODE=$Mode"
$makeVariables += "RESULT_DIR=$resultDirectory"
$makeArgs = $makeVariables -join ' '

if ($Mode -eq 'sv') {
    if ($expectCompileFailure) {
        $makeCommand = "make clean $makeArgs; if make sv-only $makeArgs; then echo 'EXPECTED_COMPILE_FAILURE_RESULT unexpected-success'; exit 1; else echo 'EXPECTED_COMPILE_FAILURE_RESULT expected-failure'; exit 0; fi"
    } else {
        $makeCommand = "make clean $makeArgs && make sv-only $makeArgs"
    }
} else {
    $makeCommand = "make clean $makeArgs && make $makeArgs"
}

docker build -t cocotb-verilator-local .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$dockerArguments = @(
    "run", "--rm",
    "--mount", "type=bind,source=$workspace,target=/work"
)
if ($externalCasePath) {
    $dockerArguments += @(
        "--mount", "type=bind,source=$externalCasePath,target=/testcase,readonly"
    )
}
$dockerArguments += @(
    "cocotb-verilator-local",
    "bash", "-lc",
    "set -o pipefail; mkdir -p '$resultDirectory'; ($makeCommand) 2>&1 | tee '$resultDirectory/simulation.log'"
)

& docker @dockerArguments
$simulationExitCode = $LASTEXITCODE

& "$PSScriptRoot\report.ps1" -Example $caseDisplayName -Mode $Mode `
    -ResultDirectory $resultDirectory -SimulationExitCode $simulationExitCode
exit $simulationExitCode
