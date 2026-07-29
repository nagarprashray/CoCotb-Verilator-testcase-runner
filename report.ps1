param(
    [string]$Example,
    [ValidateSet("both", "python", "sv")][string]$Mode,
    [string]$ResultDirectory,
    [int]$SimulationExitCode
)

$pythonTotal = 0
$pythonPassed = 0
$pythonFailed = 0
$pythonSkipped = 0
$svPassed = 0
$svFailed = 0

$resultPath = Join-Path "." $ResultDirectory
$xmlPath = Join-Path $resultPath "results.xml"
$logPath = Join-Path $resultPath "simulation.log"
$reportPath = Join-Path $resultPath "test_report.txt"

if ($Mode -ne "sv" -and (Test-Path -LiteralPath $xmlPath)) {
    [xml]$results = Get-Content -LiteralPath $xmlPath
    $testcases = @($results.testsuites.testsuite.testcase)
    $pythonTotal = $testcases.Count
    foreach ($testcase in $testcases) {
        if ($null -ne $testcase.failure -or $null -ne $testcase.error) {
            $pythonFailed++
        } elseif ($null -ne $testcase.skipped) {
            $pythonSkipped++
        } else {
            $pythonPassed++
        }
    }
}

if ($Mode -ne "python" -and (Test-Path -LiteralPath $logPath)) {
    $summary = Select-String -LiteralPath $logPath `
        -Pattern 'SV_TEST_SUMMARY passed=(\d+) failed=(\d+)' | Select-Object -Last 1
    if ($summary) {
        $svPassed = [int]$summary.Matches[0].Groups[1].Value
        $svFailed = [int]$summary.Matches[0].Groups[2].Value
    }
    $expectedFailure = Select-String -LiteralPath $logPath `
        -Pattern 'EXPECTED_COMPILE_FAILURE_RESULT expected-failure' | Select-Object -Last 1
    if ($expectedFailure -and $svPassed -eq 0 -and $svFailed -eq 0) {
        $svPassed = 1
    }
}

$totalPassed = $pythonPassed + $svPassed
$totalFailed = $pythonFailed + $svFailed
$status = if ($SimulationExitCode -eq 0 -and $totalFailed -eq 0) { "PASS" } else { "FAIL" }

$report = @"
Verification Report
===================
Example: $Example
Mode: $Mode
Status: $status

Python/cocotb: total=$pythonTotal passed=$pythonPassed failed=$pythonFailed skipped=$pythonSkipped
SystemVerilog: passed=$svPassed failed=$svFailed
Combined: passed=$totalPassed failed=$totalFailed
"@

New-Item -ItemType Directory -Path $resultPath -Force | Out-Null
$report | Set-Content -LiteralPath $reportPath
Write-Host "`n$report"
