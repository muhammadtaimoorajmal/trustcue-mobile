<#
.SYNOPSIS
    Reproducible release build script for TrustCue Android release artifacts (APK / AAB).

.DESCRIPTION
    Builds production signed release artifacts with verified public client configuration.
    Enforces a strict fail-safe contract:
    - Intended cloud releases MUST have valid public SUPABASE_URL and SUPABASE_ANON_KEY.
    - Intentional offline-only builds MUST explicitly specify the -AllowOffline switch.
    - Never accepts or embeds privileged server secrets (SUPABASE_SERVICE_ROLE_KEY, GROQ_API_KEY).
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

    [switch]$Install
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$frontendDir = Split-Path -Parent $scriptDir
$mobileDir = Split-Path -Parent $frontendDir
$projectRootDir = Split-Path -Parent $mobileDir
$backendEnv = Join-Path (Join-Path $projectRootDir 'trustcue-backend') '.env'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  TrustCue Release Build Pipeline - Target: $Target" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Resolve configuration parameters
if (-not $SupabaseUrl) {
    if ($env:SUPABASE_URL) {
        $SupabaseUrl = $env:SUPABASE_URL.Trim()
    } elseif (Test-Path $backendEnv) {
        $match = Select-String -Path $backendEnv -Pattern '^\s*SUPABASE_URL\s*=\s*(.+)$'
        if ($match) { $SupabaseUrl = $match.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'") }
    }
}

if (-not $SupabaseAnonKey) {
    if ($env:SUPABASE_ANON_KEY) {
        $SupabaseAnonKey = $env:SUPABASE_ANON_KEY.Trim()
    } elseif (Test-Path $backendEnv) {
        $match = Select-String -Path $backendEnv -Pattern '^\s*SUPABASE_ANON_KEY\s*=\s*(.+)$'
        if ($match) { $SupabaseAnonKey = $match.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'") }
    }
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

# 3. Security sanity checks: NEVER accept privileged secrets in client build
if ($SupabaseAnonKey) {
    if ($SupabaseAnonKey -match 'service_role' -or $SupabaseAnonKey -match 'sbp_' -or $SupabaseAnonKey -match 'gsk_') {
        Write-Error "SECURITY VIOLATION: Privileged server key passed as SUPABASE_ANON_KEY! Aborting build."
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
    Write-Host "`nExecuting: flutter $($buildArgs -join ' ')" -ForegroundColor Cyan
    & flutter $buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter build failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
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
    $apksigner = Join-Path $androidSdk 'build-tools\34.0.0\apksigner.bat'
    if (-not (Test-Path $apksigner)) {
        $apksigner = Get-ChildItem -Path (Join-Path $androidSdk 'build-tools') -Filter 'apksigner.bat' -Recurse | Select-Object -First 1 -ExpandProperty FullName
    }
    if ($apksigner -and (Test-Path $apksigner)) {
        Write-Host "`nVerifying signature with apksigner..." -ForegroundColor Cyan
        & $apksigner verify --verbose $artifactPath
    }

    if ($Install) {
        Write-Host "`nStreaming in-place install via adb install -r..." -ForegroundColor Cyan
        & adb install -r $artifactPath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Device installation succeeded!" -ForegroundColor Green
        } else {
            Write-Warning "adb install -r returned code $LASTEXITCODE."
        }
    }
}

