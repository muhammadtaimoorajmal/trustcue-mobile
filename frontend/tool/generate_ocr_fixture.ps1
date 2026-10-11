Add-Type -AssemblyName System.Drawing
$appRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $appRoot "assets\fixtures"
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$outPath = Join-Path $outDir "ocr_test_card.png"

$bmp = New-Object System.Drawing.Bitmap 800, 400
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear([System.Drawing.Color]::White)

$font = New-Object System.Drawing.Font("Arial", 36, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
$text = "TrustCue OCR test`r`nVerify before you act."
$graphics.DrawString($text, $font, $brush, 50, 80)

$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$brush.Dispose()
$font.Dispose()
$graphics.Dispose()
$bmp.Dispose()

Write-Output "Generated OCR test card at $outPath ($((Get-Item $outPath).Length) bytes)"
