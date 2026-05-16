# Convert WindowsNoEditor uasset textures to ASTC for iOS
# Pipeline: uasset (BC7/DXT) -> export TGA -> astcenc -> ASTC DDS -> inject -> uasset (ASTC)
# Usage: .\scripts\convert_to_astc.ps1 [-AstcBlockSize 4x4] [-AstcQuality medium] [-OutBaseDir ".."] [-Only "Model-WindowsNoEditor"]

param(
    [string]$AstcBlockSize = "4x4",
    [string]$AstcQuality   = "medium",
    [string]$OutBaseDir    = "$PSScriptRoot\..",
    [string]$Only          = ""
)

$ErrorActionPreference = "Stop"

$DepsDir    = "$PSScriptRoot\deps"
$ToolDir    = "$DepsDir\UE4-DDS-Tools-v0.6.1-Batch"
$AstcencExe = "$DepsDir\astcenc-5.4.0-windows-x64\bin\astcenc-avx2.exe"
$Python     = "$ToolDir\python\python.exe"
$MainPy     = "$ToolDir\src\main.py"
$TempDir    = "$PSScriptRoot\..\.temp\tga"

# --- dependency bootstrap ---------------------------------------------------

function Ensure-Dep {
    param([string]$Path, [string]$Url, [string]$ZipName)
    if (Test-Path $Path) { return }
    Write-Host "Dependency not found: $ZipName" -ForegroundColor Yellow
    Write-Host "Downloading from $Url ..." -ForegroundColor Cyan
    if (-not (Test-Path $DepsDir)) { New-Item -ItemType Directory -Path $DepsDir -Force | Out-Null }
    $zipPath   = Join-Path $DepsDir $ZipName
    $targetDir = Join-Path $DepsDir ([System.IO.Path]::GetFileNameWithoutExtension($ZipName))
    Invoke-WebRequest -Uri $Url -OutFile $zipPath
    Write-Host "Extracting $ZipName ..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force
    Remove-Item $zipPath -Force
}

Ensure-Dep -Path $ToolDir    -Url "https://github.com/matyalatte/UE4-DDS-Tools/releases/download/v0.6.1/UE4-DDS-Tools-v0.6.1-Batch.zip"     -ZipName "UE4-DDS-Tools-v0.6.1-Batch.zip"
Ensure-Dep -Path $AstcencExe -Url "https://github.com/ARM-software/astc-encoder/releases/download/5.4.0/astcenc-5.4.0-windows-x64.zip"       -ZipName "astcenc-5.4.0-windows-x64.zip"

if (-not (Test-Path $Python))     { Write-Error "UE4-DDS-Tools not found at: $ToolDir"; exit 1 }
if (-not (Test-Path $AstcencExe)) { Write-Error "astcenc not found at: $AstcencExe"; exit 1 }

# ---------------------------------------------------------------------------

$ProjectRoot = "$PSScriptRoot\.."

$sources = @{
    "Model-WindowsNoEditor\RawAssets" = "Model-IOS"
    "2D-WindowsNoEditor\RawAssets"    = "2D-IOS"
    "Login-Universal\RawAssets"       = "Login-IOS"
    "House-Universal\RawAssets"       = "House-IOS"
    "Plot-Universal\RawAssets"        = "Plot-IOS"
    "Scene-Universal\RawAssets"       = "Scene-IOS"
}

# Clean output dirs before starting (only for folders being processed)
foreach ($srcKey in $sources.Keys) {
    if ($Only -ne "" -and ($srcKey -split '\\')[0] -ne $Only) { continue }
    $dir = "$OutBaseDir\$($sources[$srcKey])"
    if (Test-Path $dir) {
        Remove-Item $dir -Recurse -Force
        Write-Host "Deleted existing: $dir" -ForegroundColor DarkGray
    }
}

$total = 0; $success = 0; $skip = 0; $fail = 0
$generatedDirs = @()

foreach ($srcKey in $sources.Keys) {
    if ($Only -ne "" -and ($srcKey -split '\\')[0] -ne $Only) { continue }

    $srcPath = "$ProjectRoot\$srcKey"
    if (-not (Test-Path $srcPath)) { continue }

    # Derive the sibling ExtractedAssets dir (RawAssets -> ExtractedAssets)
    $extractedDir = $srcPath -replace '\\RawAssets$', '\ExtractedAssets'
    $hasTexture = $false
    if (Test-Path $extractedDir) {
        $hasTexture = [bool](Get-ChildItem -Path $extractedDir -Filter "*.json" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match '"PF_DXT|"PF_BC' })
    }
    if (-not $hasTexture) {
        Write-Host "SKIP $srcKey (no DXT/BC textures found in ExtractedAssets)" -ForegroundColor DarkGray
        continue
    }

    $srcDir  = (Resolve-Path $srcPath).Path
    $outName = $sources[$srcKey]
    $OutDir  = "$OutBaseDir\$outName"
    $generatedDirs += $OutDir

    $uassets = Get-ChildItem -Path $srcDir -Filter "*.uasset" -Recurse
    Write-Host "`n=== $outName ($($uassets.Count) files) ===" -ForegroundColor Cyan

    foreach ($file in $uassets) {
        $total++

        if ($file.Name -match "_skm\.uasset$") {
            Write-Host "  SKIP  $($file.Name)" -ForegroundColor DarkGray
            $skip++
            continue
        }

        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $rel      = $file.FullName.Substring($srcDir.Length).TrimStart('\')
        $destDir  = Join-Path $OutDir (Split-Path $rel)
        $tgaDir   = Join-Path $TempDir (Split-Path $rel)

        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        if (-not (Test-Path $tgaDir))  { New-Item -ItemType Directory -Path $tgaDir  -Force | Out-Null }

        Write-Host "  $($file.Name) ..." -NoNewline

        # Step 1: export uasset -> TGA
        $r1 = & $Python -E $MainPy $file.FullName `
            --mode=export --export_as=tga `
            --save_folder=$tgaDir `
            --skip_non_texture --version=4.26 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host " FAIL (export)" -ForegroundColor Red
            Write-Host "    $r1" -ForegroundColor DarkRed
            $fail++; continue
        }

        $tgaFile = Get-ChildItem $tgaDir -Filter "$baseName*.tga" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $tgaFile) {
            # No texture exported (e.g. SpineAtlasAsset) - copy as-is, no conversion needed
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            foreach ($ext in @("uasset", "uexp", "ubulk")) {
                $src = [System.IO.Path]::ChangeExtension($file.FullName, $ext)
                if (Test-Path $src) {
                    Copy-Item $src (Join-Path $destDir ([System.IO.Path]::ChangeExtension($file.Name, $ext))) -Force
                }
            }
            Write-Host " COPY (non-texture)" -ForegroundColor DarkCyan
            $skip++; continue
        }

        # Step 2: TGA -> mipmapped ASTC DDS
        $ddsFile = Join-Path $tgaDir "$baseName.dds"
        $r2b = & $Python "$PSScriptRoot\build_astc_mip_dds.py" $tgaFile.FullName $ddsFile `
            --astcenc $AstcencExe `
            --tool-src "$ToolDir\src" `
            --block-size $AstcBlockSize `
            --quality $AstcQuality 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host " FAIL (build_astc_mip_dds)" -ForegroundColor Red
            Write-Host "    $r2b" -ForegroundColor DarkRed
            $fail++; continue
        }

        # Step 3: copy uasset + companions, then inject ASTC DDS
        $destUasset = Join-Path $destDir $file.Name
        Copy-Item $file.FullName $destUasset -Force
        foreach ($ext in @("uexp", "ubulk")) {
            $companion = [System.IO.Path]::ChangeExtension($file.FullName, $ext)
            if (Test-Path $companion) {
                Copy-Item $companion (Join-Path $destDir ([System.IO.Path]::ChangeExtension($file.Name, $ext))) -Force
            }
        }

        $r3 = & $Python "$PSScriptRoot\inject_astc.py" $destUasset $ddsFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host " FAIL (inject)" -ForegroundColor Red
            Write-Host "    $r3" -ForegroundColor DarkRed
            $fail++; continue
        }

        Write-Host " OK" -ForegroundColor Green
        $success++
    }
}

# Cleanup temp TGA files
if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "Total:   $total"
Write-Host "Success: $success" -ForegroundColor Green
Write-Host "Skipped: $skip"    -ForegroundColor DarkGray
Write-Host "Failed:  $fail"    -ForegroundColor Red
Write-Host "Output:`n$($generatedDirs -join "`n")"
