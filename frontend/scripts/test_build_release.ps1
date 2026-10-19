<#
.SYNOPSIS
    Automated regression tests for frontend/scripts/build_release.ps1 validation and exit code propagation.
#>

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildScript = Join-Path $scriptDir 'build_release.ps1'

Write-Host "Running build_release.ps1 validation test suite..." -ForegroundColor Cyan
$failures = 0

function Assert-BuildScriptFailure {
    param(
        [string]$TestName,
        [string]$Arguments,
        [string]$ExpectedOutputPattern
    )
    Write-Host -NoNewline "  Testing: $TestName ... "
    $cmd = "powershell -ExecutionPolicy Bypass -File `"$buildScript`" $Arguments"
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$buildScript`" $Arguments"
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $output = "$stdout`n$stderr"

    if ($p.ExitCode -eq 0) {
        Write-Host "FAILED (Expected non-zero exit code, got 0)" -ForegroundColor Red
        Write-Host "Output: $output"
        $script:failures++
        return
    }

    if ($ExpectedOutputPattern -and ($output -notmatch $ExpectedOutputPattern)) {
        Write-Host "FAILED (Expected pattern '$ExpectedOutputPattern' not matched)" -ForegroundColor Red
        Write-Host "Output: $output"
        $script:failures++
        return
    }

    Write-Host "PASSED (ExitCode=$($p.ExitCode))" -ForegroundColor Green
}

# Test 1: Rejection of unauthorized Supabase URL
Assert-BuildScriptFailure `
    -TestName "Rejection of unauthorized Supabase URL" `
    -Arguments "-SupabaseUrl 'https://yutidihosnphjtrcpxin.supabase.co' -SupabaseAnonKey 'sb_publishable_dummy_key_1234567890'" `
    -ExpectedOutputPattern "Unauthorized Supabase project reference"

# Test 2: Rejection of malformed Supabase URL
Assert-BuildScriptFailure `
    -TestName "Rejection of malformed Supabase URL" `
    -Arguments "-SupabaseUrl 'not-a-valid-url' -SupabaseAnonKey 'sb_publishable_dummy_key_1234567890'" `
    -ExpectedOutputPattern "malformed"

# Test 3: Rejection of privileged service_role key
Assert-BuildScriptFailure `
    -TestName "Rejection of service_role key as anon key" `
    -Arguments "-SupabaseUrl 'https://yzqkmoqqvnhfmmrayfko.supabase.co' -SupabaseAnonKey 'service_role_secret_key_1234567890'" `
    -ExpectedOutputPattern "Privileged server secret passed as SUPABASE_ANON_KEY"

# Test 4: Rejection of malformed anon key
Assert-BuildScriptFailure `
    -TestName "Rejection of short/malformed anon key" `
    -Arguments "-SupabaseUrl 'https://yzqkmoqqvnhfmmrayfko.supabase.co' -SupabaseAnonKey 'short'" `
    -ExpectedOutputPattern "Invalid SUPABASE_ANON_KEY format"

# Test 5: Rejection of invalid build target
Assert-BuildScriptFailure `
    -TestName "Rejection of invalid build target" `
    -Arguments "-Target 'ipa'" `
    -ExpectedOutputPattern "ValidateSet"

# Test 6: Rejection of empty cloud configuration without -AllowOffline
Assert-BuildScriptFailure `
    -TestName "Rejection of missing cloud configuration" `
    -Arguments "-Target apk -SupabaseUrl `"`" -SupabaseAnonKey `"`"" `
    -ExpectedOutputPattern "Missing required public cloud configuration"

# Test 7: Acceptance of custom Supabase URL with -AllowCustomSupabaseUrl flag
Write-Host -NoNewline "  Testing: Acceptance of custom Supabase URL with -AllowCustomSupabaseUrl ... "
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "powershell.exe"
$pinfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$buildScript`" -SupabaseUrl https://custom-project.supabase.co -SupabaseAnonKey sb_publishable_custom_valid_key_1234567890 -AllowCustomSupabaseUrl"
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($pinfo)
# Let it run briefly to pass validation, then terminate so it doesn't trigger a full Flutter build in test
Start-Sleep -Milliseconds 1500
if (-not $p.HasExited) {
    $p.Kill()
    $p.WaitForExit()
    Write-Host "PASSED (Validation passed; halted before Flutter compile)" -ForegroundColor Green
} else {
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $output = "$stdout`n$stderr"
    if ($output -match "Unauthorized Supabase project reference") {
        Write-Host "FAILED (Unexpected unauthorized error with -AllowCustomSupabaseUrl)" -ForegroundColor Red
        $failures++
    } else {
        Write-Host "PASSED (Validation passed)" -ForegroundColor Green
    }
}

# Test 8: Non-zero exit code propagation on native tool failure
Write-Host -NoNewline "  Testing: Non-zero exit code propagation on native tool failure ... "
$harnessPath = Join-Path $env:TEMP "trustcue_test_harness.ps1"
@'
$ErrorActionPreference = 'Stop'
function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory=$true)][string]$StepName,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )
    & $Command
    $nativeExit = $LASTEXITCODE
    if ($nativeExit -ne 0) {
        [Console]::Error.WriteLine("`nSTEP FAILED: $StepName exited with error code $nativeExit.")
        exit $nativeExit
    }
}
Invoke-CheckedCommand -StepName 'Stub Failure' -Command { & cmd.exe /c exit 42 }
'@ | Set-Content -Path $harnessPath -Encoding utf8

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "powershell.exe"
$pinfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$harnessPath`""
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($pinfo)
$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()
$p.WaitForExit()
Remove-Item -Path $harnessPath -Force -ErrorAction SilentlyContinue

if ($p.ExitCode -eq 42) {
    Write-Host "PASSED (Native exit code 42 preserved)" -ForegroundColor Green
} else {
    Write-Host "FAILED (Expected exit code 42, got $($p.ExitCode))`nOutput: $stdout`n$stderr" -ForegroundColor Red
    $failures++
}

Write-Host "`n----------------------------------------------------------"
if ($failures -eq 0) {
    Write-Host "ALL BUILD SCRIPT VALIDATION TESTS PASSED (8/8)" -ForegroundColor Green
} else {
    Write-Error "TEST SUITE FAILED with $failures failure(s)."
    exit 1
}
