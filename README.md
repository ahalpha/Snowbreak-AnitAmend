# Snowbreak-AnitAmend

[![build](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/ahalpha/Snowbreak-AnitAmend/releases/latest)

Snowbreak: Containment Zone Anti Amend / Censorship Mod

> [!IMPORTANT]
> Please assess and assume any potential risk of account suspension yourself.
>
> 请自行评估并承担可能的封号风险。
> 
> To avoid unnecessary impact, it is not recommended to promote or advertise any mods on official public platforms.
>
> 为避免不必要的影响，不建议在正式的公开平台进行宣传或推广模组。
>
> This mod is fan-made unofficial content and is not directly affiliated with the game’s official developers/publisher.
>
> 此模组为玩家自制的非官方内容，与游戏官方无直接关联。

---

**English** | [简体中文](/.docs/README.zh-CN.md)

## Info

### Platform
Please refer to the mod file name:

- **Universal** — Compatible with all platforms
- **WindowsNoEditor** — Intended for use on Windows only

### Patch Types

#### Basic — Basic Patch
Includes a necessary [`.lua`](https://github.com/ahalpha/Snowbreak-AnitAmend/blob/master/Basic-Universal/ExtractedAssets/Game/Content/Script/Resource/ResourceAmend.lua) file used to patch certain variables in order to enable basic resource mapping and remove restrictions.

- [x] Includes newer skin patches
- [x] Includes most portrait/illustration patches
- [x] Includes buttock and breasts physics effect patches
- [x] Removes restrictions in interaction and other interfaces

#### Model — Model Patch
Used on top of the Basic Patch. This patch keeps the file size reduced while restoring almost all character 3D models.

- [x] Includes model patches for default outfits and skins
- [x] Includes model patches for dormitory and bath towel outfits
- [x] Includes model patches for character skill and ultimate models

#### 2D — Illustration Patch
Used on top of the Basic Patch. Patches necessary static images, including tutorial images, illustrations, and Live2D portraits.

- [x] Includes CG & illustration patches
- [x] Includes Live2D portrait patches
- [x] Includes tutorial image patches

#### Login — Login Screen Patch
Used to change the static login screen into a dynamic one.

- [x] Includes the 3.6 login screen patch

#### Plot — Story Patch
Used to patch story-related content.

- [x] Includes patches for some main story content
- [x] Includes patches for some character stories
- [x] Includes patches for some affection stories
- [x] Supports multilingual text

#### Scene — Interactive Scene Patch
Used to patch content related to interactive scenes.

- [x] Includes patches for, but not limited to, `certain scenes where the camera cannot be rotated`

#### House — Dormitory Patch
Used to patch dormitory-related content.

- [x] Includes bath event patches
- [x] Includes spa model patches
- [x] Includes Vidya furniture animation patches

#### Riki — Gallery Patch
Used to patch riki-related content.

- [x] Includes patches for some static skin portraits
- [x] Includes patches for some story CGs, illustrations, and Live2D
- [!] This patch may encounter issues with future version updates

*Currently, only the above 8 patch types are available here.*

## Build

1. Install [Unreal Engine](https://www.unrealengine.com/download).  
   *You can choose the same **4.26** version as the game, or a newer **5.5** version.*  
   *This project only requires `UnrealPak.exe` during the build process.*

2. Clone this repository.

```bash
git clone https://github.com/ahalpha/Snowbreak-AnitAmend.git
```

3. Use `UnrealPak.exe` to package the assets into `.pak` files. You may refer to the example script below.

<details>
<summary>View example script</summary>

#### [!] Before using it, please change `$UnrealPakPath` to the path of your own installed `UnrealPak.exe`.

#### [!] After running this script, all build outputs will be generated in the `.dist/` directory.

``` powershell
$UnrealPakPath = "C:\Program Files\Epic Games\UE_4.26\Engine\Binaries\Win64\UnrealPak.exe"

$ErrorActionPreference = "Stop"

$patchNames = @(
    "Basic-Universal",
    "House-Universal",
    "Login-Universal",
    "Model-WindowsNoEditor",
    "Plot-Universal",
    "Scene-Universal"
)

$rootDir = $PSScriptRoot
$distDir = Join-Path $rootDir ".dist"
$listDir = Join-Path $distDir "_paklists"

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
New-Item -ItemType Directory -Force -Path $listDir | Out-Null

foreach ($patchName in $patchNames) {
    Write-Host "Packing patch: $patchName"

    $sourceGameDir = Join-Path $rootDir "$patchName/RawAssets/Game"

    $pakFile = Join-Path $distDir "Patch_Xpand_AntiAmend_${patchName}_100_P.pak"
    $responseFile = Join-Path $listDir "${patchName}.txt"

    $sourceRootFull = (Resolve-Path $sourceGameDir).Path

    $lines = New-Object System.Collections.Generic.List[string]

    Get-ChildItem -Path $sourceRootFull -Recurse -File | ForEach-Object {
        $fileFullPath = $_.FullName

        $relativePath = $fileFullPath.Substring($sourceRootFull.Length).TrimStart('\', '/')
        $relativePath = $relativePath -replace '\\', '/'

        $pakPath = "../../../Game/$relativePath"

        $src = $fileFullPath -replace '\\', '/'
        $line = "`"$src`" `"$pakPath`""

        $lines.Add($line)
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($responseFile, $lines, $utf8NoBom)

    if (Test-Path $pakFile) {
        Remove-Item $pakFile -Force
    }

    & $UnrealPakPath $pakFile "-Create=$responseFile" -compress "-compressionformat=Oodle"

    if ($LASTEXITCODE -ne 0) {
        throw "UnrealPak failed: $patchName"
    }

    Write-Host "Done: $pakFile"
    Write-Host ""
}

Write-Host "All patches finished."
```

</details>