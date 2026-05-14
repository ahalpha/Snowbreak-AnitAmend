# Snowbreak-AnitAmend

[![build](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/ahalpha/Snowbreak-AnitAmend/releases/latest)

尘白禁区反和谐模组

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

**简体中文** | [English](/.docs/README.md)

## 信息

### 平台
依据文件命名：

- Universal - 全版本通用
- WindowsNoEditor - 仅期望 Windows 下使用

### 修补类型

#### Basic - 基本修补
内置一个必要的 [`.lua`](https://github.com/ahalpha/Snowbreak-AnitAmend/blob/master/Basic-Universal/ExtractedAssets/Game/Content/Script/Resource/ResourceAmend.lua) 文件，用于修补一些变量以启用基本的资源映射与限制解除。

- [x] 包含较新的皮肤修补
- [x] 包含大多数的立绘修补
- [x] 解除互动等界面限制
- [x] 解除臀部、乳摇限制

#### Model - 模型修补
在使用基础修补之上，该补丁在精简体积的同时，能几乎的让所有角色的 3D 模型复原。

- [x] 包含原皮、皮肤的模型修补
- [x] 包含宿舍、浴巾的模型修补
- [x] 包含角色技能、大招模型修补

#### 2D - 立绘修补
在使用基础修补之上，修补了剩余的静态图含教程图、插图等，与 Live2D 立绘。

- [x] 包含立绘、静态 CG 修补
- [x] 包含 Live2D 立绘修补
- [x] 包含教程图修补

#### Login - 登录界面修补
用于将静态登录界面改为动态。

- [x] 包含 3.6 登录界面修补

#### Plot - 剧情修补
用于修补剧情的相关内容。

- [x] 包含主线剧情修补
- [x] 包含角色剧情修补
- [x] 包含好感剧情修补
- [x] 支持多语言文本

#### Scene - 互动场景修补
用于修补互动场景的相关内容。

- [x] 包含但不限于 `某些不能转动视角的场景` 等修补

#### House - 宿舍修补
用于修补宿舍的相关内容。

- [x] 包含洗澡事件修补
- [x] 包含温泉中心的衣服修补
- [x] 包含薇蒂雅家具动画修补

*目前这里仅有以上 7 种修补类型*

## 自行构建

1. 安装任意版本的 [虚幻引擎](https://www.unrealengine.com/download)。  
   *你可以选择与游戏相同的 **4.26** 版本，也可以选择较新的 **5.5** 版本。*  
   *本项目构建过程只需要使用其中的 `UnrealPak.exe`。*
   
2. 克隆本项目。

``` bash
git clone https://github.com/ahalpha/Snowbreak-AnitAmend.git
```

3. 使用 `UnrealPak.exe` 打包资产为 `.pak` ，可参考以下示例脚本。

<details>
<summary>查看示例脚本</summary>

#### [!] 使用前请将 `$UnrealPakPath` 修改为你自己安装的 `UnrealPak.exe` 路径。

#### [!] 运行该脚本后，所有构建产物会输出至 `.dist/` 目录中。

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
