<#
.SYNOPSIS
    Reproducible release build script for TrustCue Android release artifacts (APK / AAB).

.DESCRIPTION
    Builds production signed release artifacts with verified public client configuration.
    Enforces a strict fail-safe contract:
    - Intended cloud releases MUST target the authorized Supabase project reference
      (https://yzqkmoqqvnhfmmrayfko.supabase.co) unless explicitly overridden with -AllowCustomSupabaseUrl.
    - Intended cloud releases MUST have valid public SUPABASE_URL and SUPABASE_ANON_KEY.
    - Intentional offline-only builds MUST explicitly specify the -AllowOffline switch.
    - Never accepts or embeds privileged server secrets (SUPABASE_SERVICE_ROLE_KEY, GROQ_API_KEY).
    - Strict failure propagation: any native build, signing, or installation failure halts
      the pipeline immediately and returns the native non-zero exit code.
    - Preserves guest functionality and offline fallback paths.

.PARAMETER Target
    Build target: 'apk' (default) or 'bundle' (for AAB).

.PARAMETER AllowOffline
    Explicit switch to compile an intentional offline-only build with cloud services disabled.

.PARAMETER SupabaseUrl
    Public Supabase project URL (e.g. https://<project>.supabase.co).
    Defaults to reading SUPABASE_URL from environment or backend .env.

.PARAMETER SupabaseAnonKey
    Public publishable anonymous client key.
    Defaults to reading SUPABASE_ANON_KEY from environment or backend .env.

.PARAMETER BackendBaseUrl
    Public backend URL. Defaults to 'https://trustcue-backend.onrender.com'.

.PARAMETER AllowCustomSupabaseUrl
    Explicit switch allowing an alternate or non-standard Supabase URL to prevent accidental
    misconfiguration against unintended projects.

.PARAMETER Install
    Automatically streams the built release APK to a connected Android device via adb install -r.
#>

[CmdletBinding()]
param(
    [ValidateSet('apk', 'bundle')]
    [string]$Target = 'apk',

    [switch]$AllowOffline,

    [string]$SupabaseUrl,

    [string]$SupabaseAnonKey,

    [string]$BackendBaseUrl = 'https://trustcue-backend.onrender.com',

    [switch]$AllowCustomSupabaseUrl,

    [switch]$Install
)

$ErrorActionPreference = 'Stop'

trap {
    Write-Host "`nCRITICAL BUILD PIPELINE FAILURE: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$AUTHORIZED_SUPABASE_URL = 'https://yzqkmoqqvnhfmmrayfko.supabase.co'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$frontendDir = Split-Path -Parent $scriptDir
$mobileDir = Split-Path -Parent $frontendDir
$projectRootDir = Split-Path -Parent $mobileDir
$backendEnv = Join-Path (Join-Path $projectRootDir 'trustcue-backend') '.env'

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory=$true)][string]$StepName,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )
    Write-Host "`n--> [RUNNING] $StepName..." -ForegroundColor Cyan
    & $Command
    $nativeExit = $LASTEXITCODE
    if ($nativeExit -ne 0) {
        [Console]::Error.WriteLine("`nSTEP FAILED: $StepName exited with error code $nativeExit.")
        exit $nativeExit
    }
    Write-Host "--> [PASSED] $StepName" -ForegroundColor Green
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  TrustCue Release Build Pipeline - Target: $Target" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Resolve configuration parameters
if ($PSBoundParameters.ContainsKey('SupabaseUrl')) {
    $SupabaseUrl = $SupabaseUrl.Trim().Trim('"').Trim("'")
} elseif ($env:SUPABASE_URL) {
    $SupabaseUrl = $env:SUPABASE_URL.Trim().Trim('"').Trim("'")
} elseif (Test-Path $backendEnv) {
    $match = Select-String -Path $backendEnv -Pattern '^\s*SUPABASE_URL\s*=\s*(.+)$'
    if ($match) { $SupabaseUrl = $match.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'") }
}

if ($PSBoundParameters.ContainsKey('SupabaseAnonKey')) {
    $SupabaseAnonKey = $SupabaseAnonKey.Trim().Trim('"').Trim("'")
} elseif ($env:SUPABASE_ANON_KEY) {
    $SupabaseAnonKey = $env:SUPABASE_ANON_KEY.Trim().Trim('"').Trim("'")
} elseif (Test-Path $backendEnv) {
    $match = Select-String -Path $backendEnv -Pattern '^\s*SUPABASE_ANON_KEY\s*=\s*(.+)$'
    if ($match) { $SupabaseAnonKey = $match.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'") }
}

# 2. Enforce fail-safe release contract
$isCloudConfigured = (-not [string]::IsNullOrWhiteSpace($SupabaseUrl)) -and (-not [string]::IsNullOrWhiteSpace($SupabaseAnonKey))

if (-not $isCloudConfigured -and -not $AllowOffline) {
    Write-Error @"
ERROR: Release build halted! Missing required public cloud configuration.
An intended cloud-enabled release requires both SUPABASE_URL and SUPABASE_ANON_KEY.
Provide them via:
  1. Script parameters: -SupabaseUrl <url> -SupabaseAnonKey <key>
  2. Environment variables: `$env:SUPABASE_URL, `$env:SUPABASE_ANON_KEY
  3. Authorized local backend: trustcue-backend/.env
If you intend to build an offline-only release without cloud features, run with:
  .\scripts\build_release.ps1 -Target $Target -AllowOffline
"@
    exit 1
}

# 3. Validate Supabase project reference and format
if (-not $AllowOffline) {
    if (-not [System.Uri]::IsWellFormedUriString($SupabaseUrl, [System.UriKind]::Absolute) -or ($SupabaseUrl -notmatch '^https://')) {
        Write-Error "CONFIGURATION ERROR: Supabase URL '$SupabaseUrl' is malformed. Must be an absolute https:// URI."
        exit 1
    }

    if ((-not $AllowCustomSupabaseUrl) -and ($SupabaseUrl -ne $AUTHORIZED_SUPABASE_URL)) {
        Write-Error @"
CONFIGURATION ERROR: Unauthorized Supabase project reference '$SupabaseUrl'.
The verified and authorized Supabase project reference for TrustCue is:
  $AUTHORIZED_SUPABASE_URL
If you intentionally need to build against a custom or alternate Supabase project,
you must explicitly pass the -AllowCustomSupabaseUrl switch.
"@
        exit 1
    }

    # Security sanity checks: NEVER accept privileged secrets or malformed keys in client build
    if ($SupabaseAnonKey -match 'service_role' -or $SupabaseAnonKey -match 'sbp_' -or $SupabaseAnonKey -match 'gsk_' -or $SupabaseAnonKey -match 'secret') {
        Write-Error "SECURITY VIOLATION: Privileged server secret passed as SUPABASE_ANON_KEY! Aborting build."
        exit 1
    }

    if ($SupabaseAnonKey.Length -lt 20 -or ($SupabaseAnonKey -notmatch '^sb_publishable_' -and $SupabaseAnonKey -notmatch '^eyJ')) {
        Write-Error "CONFIGURATION ERROR: Invalid SUPABASE_ANON_KEY format. Must be a valid public anon key or JWT."
        exit 1
    }

    if (-not [System.Uri]::IsWellFormedUriString($BackendBaseUrl, [System.UriKind]::Absolute) -or ($BackendBaseUrl -notmatch '^https://')) {
        Write-Error "CONFIGURATION ERROR: BackendBaseUrl '$BackendBaseUrl' is malformed. Must be an absolute https:// URI."
        exit 1
    }
}

# 4. Verify release signing configuration
$keyPropsPath = Join-Path (Join-Path $frontendDir 'android') 'key.properties'
if (-not (Test-Path $keyPropsPath)) {
    Write-Error "Release signing configuration missing at $keyPropsPath. Cannot build release artifacts."
    exit 1
}

# 5. Assemble build command
$buildArgs = @()
if ($Target -eq 'apk') {
    $buildArgs += @('build', 'apk', '--release')
} else {
    $buildArgs += @('build', 'appbundle', '--release')
}

if ($AllowOffline) {
    Write-Host "Mode: INTENTIONAL OFFLINE-ONLY BUILD" -ForegroundColor Yellow
    $buildArgs += '--dart-define=ALLOW_OFFLINE_BUILD=true'
} else {
    Write-Host "Mode: CLOUD-ENABLED RELEASE BUILD" -ForegroundColor Green
    Write-Host "  Supabase URL:    $($SupabaseUrl.Substring(0, [Math]::Min(25, $SupabaseUrl.Length)))..." -ForegroundColor Gray
    Write-Host "  Supabase Anon:   [REDACTED public anon key, length $($SupabaseAnonKey.Length)]" -ForegroundColor Gray
    Write-Host "  Backend Base:    $BackendBaseUrl" -ForegroundColor Gray

    $buildArgs += "--dart-define=SUPABASE_URL=$SupabaseUrl"
    $buildArgs += "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
    $buildArgs += "--dart-define=BACKEND_BASE_URL=$BackendBaseUrl"
    $buildArgs += "--dart-define=AUTH_CALLBACK_SCHEME=trustcue"
    $buildArgs += "--dart-define=AUTH_CALLBACK_HOST=auth-callback"
}

# 6. Execute build from frontend directory
Push-Location $frontendDir
try {
    Invoke-CheckedCommand "Executing Flutter Release Build (Target: $Target)" {
        & flutter $buildArgs
    }
} finally {
    Pop-Location
}

# 7. Locate and verify output artifact
$artifactPath = $null
if ($Target -eq 'apk') {
    $artifactPath = Join-Path $frontendDir 'build\app\outputs\flutter-apk\app-release.apk'
} else {
    $artifactPath = Join-Path $frontendDir 'build\app\outputs\bundle\release\app-release.aab'
}

if (-not (Test-Path $artifactPath)) {
    Write-Error "Expected build artifact was not found at $artifactPath"
    exit 1
}

$fileItem = Get-Item $artifactPath
$hash = (Get-FileHash -Path $artifactPath -Algorithm SHA256).Hash

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  Build Succeeded!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Artifact: $artifactPath"
Write-Host "  Size:     $($fileItem.Length) bytes ($([Math]::Round($fileItem.Length / 1MB, 2)) MB)"
Write-Host "  SHA-256:  $hash"

if ($Target -eq 'apk') {
    $androidSdk = $env:ANDROID_HOME
    if (-not $androidSdk) { $androidSdk = $env:LOCALAPPDATA + '\Android\Sdk' }
    $apksigner = $null
    $buildToolsDir = Join-Path $androidSdk 'build-tools'
    if (Test-Path $buildToolsDir) {
        $tools = Get-ChildItem -Path $buildToolsDir -Filter 'apksigner.bat' -Recurse | Select-Object -ExpandProperty FullName
        if ($tools) {
            $apksigner = $tools | Sort-Object -Descending | Select-Object -First 1
        }
    }
    if (-not $apksigner -or -not (Test-Path $apksigner)) {
        Write-Error "apksigner.bat not found in $buildToolsDir. Release APK signature verification required."
        exit 1
    }

    Invoke-CheckedCommand "Verifying APK Signature with apksigner" {
        & $apksigner verify --verbose $artifactPath
    }

    if ($Install) {
        $adbExe = 'adb'
        $adbPath = Join-Path $androidSdk 'platform-tools\adb.exe'
        if (Test-Path $adbPath) { $adbExe = $adbPath }
        Invoke-CheckedCommand "Installing APK to Connected Device via $adbExe install -r" {
            & $adbExe install -r $artifactPath
        }
        Write-Host "Device installation succeeded!" -ForegroundColor Green
    }
}
