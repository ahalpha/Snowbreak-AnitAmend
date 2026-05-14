# Pack all patch directories into .dist as pak files using repak
# IOS patches (Model-IOS, 2D-IOS) must be generated first by convert_to_astc.ps1
# Usage: .\scripts\export_paks.ps1 [-OutDir ".dist"]

param(
    [string]$OutDir = "$PSScriptRoot\..\.dist"
)

$ErrorActionPreference = "Stop"

$DepsDir = "$PSScriptRoot\deps"
$Repak   = "$DepsDir\repak_cli-x86_64-pc-windows-msvc\repak.exe"

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

Ensure-Dep -Path $Repak -Url "https://github.com/trumank/repak/releases/download/v0.2.3/repak_cli-x86_64-pc-windows-msvc.zip" -ZipName "repak_cli-x86_64-pc-windows-msvc.zip"

if (-not (Test-Path $Repak)) { Write-Error "repak not found at: $Repak"; exit 1 }

$ProjectRoot = "$PSScriptRoot\.."

# Map: pak name -> pack root dir relative to project root
$patches = [ordered]@{
    "Basic-Universal"        = "Basic-Universal\RawAssets\Game\Content"
    "House-Universal"        = "House-Universal\RawAssets\Game\Content"
    "Login-Universal"        = "Login-Universal\RawAssets\Game\Content"
    "Model-WindowsNoEditor"  = "Model-WindowsNoEditor\RawAssets\Game\Content"
    "2D-WindowsNoEditor"     = "2D-WindowsNoEditor\RawAssets\Game\Content"
    "Plot-Universal"         = "Plot-Universal\RawAssets\Game\Content"
    "Riki-Universal"         = "Riki-Universal\RawAssets\Game\Content"
    "Scene-Universal"        = "Scene-Universal\RawAssets\Game\Content"
    "Model-IOS"              = "Model-IOS\Game\Content"
    "2D-IOS"                 = "2D-IOS\Game\Content"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$total = 0; $success = 0; $skip = 0; $fail = 0

foreach ($entry in $patches.GetEnumerator()) {
    $patchName = $entry.Key
    $srcDir    = Join-Path $ProjectRoot $entry.Value
    $pakFile   = Join-Path $OutDir "Patch_Xpand_AntiAmend_${patchName}_100_P.pak"
    $total++

    if (-not (Test-Path $srcDir)) {
        Write-Host "SKIP $patchName (source not found: $srcDir)" -ForegroundColor DarkGray
        $skip++
        continue
    }

    Write-Host "Packing $patchName ..." -ForegroundColor Cyan

    $srcDirFull = (Resolve-Path $srcDir).Path
    if (Test-Path $pakFile) { Remove-Item $pakFile -Force }

    & $Repak pack --version V11 --compression Oodle --mount-point "../../../Game/Content/" $srcDirFull $pakFile

    if ($LASTEXITCODE -eq 0) {
        $size = [math]::Round((Get-Item $pakFile).Length / 1MB, 1)
        Write-Host "OK -> Patch_Xpand_AntiAmend_${patchName}_100_P.pak ($size MB)" -ForegroundColor Green
        $success++
    } else {
        Write-Host "FAIL $patchName" -ForegroundColor Red
        $fail++
    }
}

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "Total:   $total"
Write-Host "Success: $success" -ForegroundColor Green
Write-Host "Skipped: $skip"    -ForegroundColor DarkGray
Write-Host "Failed:  $fail"    -ForegroundColor Red
Write-Host "Output:  $OutDir"
