param(
    [ValidateSet('navigation', 'all', 'device')]
    [string]$Suite = 'navigation',
    [ValidatePattern('^[a-zA-Z0-9:._-]+$')]
    [string]$DeviceId,
    [ValidateRange(30, 900)]
    [int]$TimeoutSeconds = 180
)

# Run from any directory. Logs live in the ignored Flutter build directory.
$ErrorActionPreference = 'Stop'
$appRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $appRoot 'build/test-runner'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$runId = [Guid]::NewGuid().ToString('N')
$stdout = Join-Path $logDirectory "$runId.out.log"
$stderr = Join-Path $logDirectory "$runId.err.log"
$flutterPath = (Get-Command flutter -ErrorAction Stop).Source
$testArguments = 'test --no-pub --reporter expanded'
if ($Suite -eq 'navigation') {
    $testArguments += ' test/app/navigation_test.dart'
} elseif ($Suite -eq 'device') {
    if (!$DeviceId) { throw 'DeviceId is required for device tests.' }
    $testArguments += " integration_test/app_smoke_test.dart -d $DeviceId"
}

$command = '/d /s /c ""' + $flutterPath + '" ' + $testArguments + '"'
$runner = Start-Process -FilePath $env:ComSpec -ArgumentList $command `
    -WorkingDirectory $appRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $runner.Handle
$finished = $runner.WaitForExit($TimeoutSeconds * 1000)
if (!$finished) {
    # Only this invocation and its descendants; never kill by executable name.
    & taskkill.exe /PID $runner.Id /T /F | Out-Null
    $runner.WaitForExit()
}
Get-Content -LiteralPath $stdout
Get-Content -LiteralPath $stderr
Write-Output "Runner logs: $stdout ; $stderr"
if (!$finished) {
    Write-Error "Test run exceeded $TimeoutSeconds seconds and was stopped."
    exit 124
}
if ($null -eq $runner.ExitCode) { throw 'Unable to obtain the test exit code.' }
exit $runner.ExitCode
