<# : batch
@ECHO off
SETLOCAL EnableDelayedExpansion
TITLE Initializing Script...
CD /d %~dp0
<NUL SET /p="Checking PowerShell ... "
WHERE /q PowerShell 
IF !ERRORLEVEL! NEQ 0 ( ECHO PowerShell is not installed. & PAUSE & EXIT )
ECHO OK
<NUL SET /p="Checking PowerShell version ... "
PowerShell -C "if ($PSVersionTable.PSVersion.Major -lt 3) { exit 1 }"
IF !ERRORLEVEL! NEQ 0 ( ECHO Requires PowerShell 3 or later. & PAUSE & EXIT )
ECHO OK
<NUL SET /p="Checking execute permissions ... "
PowerShell -C "if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 1 }"
IF !ERRORLEVEL! NEQ 0 (
    ECHO Fail
    ECHO Restart with administrator privileges ... 
    SET args=%*
    IF DEFINED args (
        SET args=!args:'=''!
        SET args=!args:"=\"!
    )
    PowerShell -NoP -C "Start-Process 'cmd.exe' -Verb RunAs -WorkingDirectory '%~dp0' -ArgumentList '/d /s /k \"\"%~f0\" !args!\"'"
    EXIT
)
ECHO OK
<NUL SET /p="Extract embedded script ... "
powershell -NoP -C "$c=gc '%~f0' -Raw -En UTF8;if(($s=$c.IndexOf('<'+'# : batch'))-ge 0 -and ($e=$c.IndexOf(':: #'+'>',$s))-ge 0){$c.Substring($e+6)|sc '%~n0.ps1' -En UTF8}else{exit 1}"
IF !ERRORLEVEL! NEQ 0 ( ECHO Embedded script section not found. & PAUSE & EXIT )
ECHO OK
PowerShell -NoP -EP Bypass -File "%~n0.ps1" %*
EXIT
:: #>
param(
    [Parameter(Mandatory = $false)]
    [Alias("ughp")]
    [switch]$UseGitHubProxy = $false,
    [Parameter(Mandatory = $false)]
    [Alias("ghp")]
    [string]$GitHubProxy = "https://gh-proxy.org",
    [Parameter(Mandatory = $false)]
    [Alias("up")]
    [switch]$UseProxy = $false,
    [Parameter(Mandatory = $false)]
    [Alias("p")]
    [string]$Proxy = "http://127.0.0.1:7890"
)
$Global:RepoOwner = "ahalpha"
$Global:RepoName = "Snowbreak-AnitAmend"
$Global:ApiBase = "https://api.github.com/repos/$RepoOwner/$RepoName"
$Global:ModsSubPath = "game\Game\Content\Paks\mods"
$Global:RegPath = "HKCU:\Software\SnowbreakAnitAmend"
$Global:RegName = "GameInstallDir"
$I18N = @{
    "zh-CN" = @{
        Title                  = "Snowbreak-AnitAmend 安装/更新工具"
        GameDirHelp            = @'
如何找到游戏安装位置？
西山居启动器：点击 开始游戏 旁边的齿轮 -> 点击 侧边栏的游戏 -> 点击 游戏安装目录边上的查看按钮
尘白禁区启动器：点击 开始游戏 旁边的三个横线 -> 点击 安装位置
若操作正确，当前打开的位置就是游戏安装位置！
'@
        InputGameDir           = "请输入游戏安装位置"
        GameDirNotFound        = "目录不存在：{0}"
        NoPaksDir              = "未找到 {0} 目录，正在创建..."
        PaksDirCreated         = "目录已创建：{0}"
        FetchingLatest         = "正在从 GitHub 获取最新版本信息..."
        FetchLatestFail        = "获取最新版本失败！{0}"
        ParsedReleaseInfo      = "最新版本：{0}（{1}）"
        CheckingLocalMods      = "正在检查本地模组文件..."
        ModNotInstalled        = "检测到模组尚未安装，准备下载..."
        ModFilesFound          = "发现 {0} 个本地模组文件，正在校验..."
        Sha256Verify           = "校验：{0} ..."
        Sha256Match            = "  ✓ SHA256 匹配"
        Sha256Mismatch         = "  ✗ SHA256 不匹配，需要更新"
        LocalFileMissing       = "  - 本地文件缺失"
        AllUpToDate            = "所有模组文件均为最新版本，无需更新。"
        Sha256Corrupted        = "  SHA256 校验失败，删除损坏文件..."
        DownloadResultSummary  = "成功：{0} / {1}，失败：{2}"
        Downloading            = "正在下载：{0}（{1}）..."
        DownloadProgress       = "  进度：{0}/{1} 个文件"
        DownloadComplete       = "下载完成：{0}"
        DownloadError          = "下载失败：{0}"
        AlreadyLatest          = "所有模组已是最新版本（{0}）！"
        InstallSuccess         = "模组安装/更新完成！"
        PressAnyKey            = "按任意键退出..."
        GameDirDetected        = "检测到游戏。"
        DirConfirm             = "请确认该目录是否正确？"
        YesLabel               = "是(&Y)"
        NoLabel                = "否(&N)"
        YesHelp                = "确认"
        NoHelp                 = "取消"
        WillDownloadCount      = "将下载 {0} 个文件..."
        GameExeNotFound        = "未找到 Game.exe（{0}），请确认输入的游戏安装位置是否正确"
        DownloadStart          = "开始下载..."
        FileSizeBytes          = "文件大小：{0}"
        ProxyTitle             = ""
        ProxyPrompt            = "请选择下载方式："
        ProxyChoiceLabelNo     = "&No proxy"
        ProxyChoiceHelpNo      = "不使用任何代理，直连 GitHub"
        ProxyChoiceLabelGHP    = "&GitHub proxy"
        ProxyChoiceHelpGHP     = "通过 gh-proxy 镜像加速下载"
        ProxyChoiceLabelCustom = "&Custom proxy"
        ProxyChoiceHelpCustom  = "使用自定义的 HTTP/HTTPS 代理服务器"
        ProxyChangeConfirm     = "是否使用自定义GitHubProxy？"
        ProxyInputUrl          = "请输入 GitHub 代理镜像 URL（默认 https://gh-proxy.org）"
        ProxyInputCustom       = "请输入自定义 HTTP 代理地址（默认 http://127.0.0.1:7890）"
        ProxyConflictDetailed  = "UseProxy 和 UseGitHubProxy 参数不能同时使用，请选择其中一种代理方式。"
        CompatibleWebReqErr    = "[兼容模式] Invoke-WebRequest 失败：{0}"
        RetryFetch             = "拉取失败，正在进行第{0} 次重试..."
        SavedDirFound          = "找到上次保存的游戏安装位置：{0}"
        SavedDirInvalid        = "上次保存的游戏安装位置无效，请重新输入。"
    }
    "en-US" = @{
        Title                  = "Snowbreak-AnitAmend Install / Update Tool"
        GameDirHelp            = @'
How to find the game installation directory?
Xishanju Launcher: Click the gear icon next to Start Game -> Click Game in the sidebar -> Click the View button next to Game Install Directory
Snowbreak Launcher: Click the three lines next to Start Game -> Click Installation Location
If done correctly, the current location shown is the game installation directory!
'@
        InputGameDir           = "Enter the game installation directory"
        GameDirNotFound        = "Directory not found: {0}"
        NoPaksDir              = "Directory {0} not found, creating..."
        PaksDirCreated         = "Directory created: {0}"
        FetchingLatest         = "Fetching latest release info from GitHub..."
        FetchLatestFail        = "Failed to fetch latest release!{0}"
        ParsedReleaseInfo      = "Latest version: {0} ({1})"
        CheckingLocalMods      = "Checking local mod files..."
        ModNotInstalled        = "Mod not installed, preparing to download..."
        ModFilesFound          = "Found {0} local mod files, verifying..."
        Sha256Verify           = "Verifying: {0} ..."
        Sha256Match            = "  ✓ SHA256 matches"
        Sha256Mismatch         = "  ✗ SHA256 mismatch, update needed"
        LocalFileMissing       = "  - Local file missing"
        AllUpToDate            = "All mod files are up to date."
        Sha256Corrupted        = "  SHA256 verification failed, deleting corrupted file..."
        DownloadResultSummary  = "Success: {0} / {1}, Failed: {2}"
        Downloading            = "Downloading: {0} ({1})..."
        DownloadProgress       = "  Progress: {0} / {1} files"
        DownloadComplete       = "Download complete: {0}"
        DownloadError          = "Download failed: {0}"
        AlreadyLatest          = "All mods are up to date ({0})!"
        InstallSuccess         = "Mod installation / update complete!"
        PressAnyKey            = "Press any key to exit..."
        GameDirDetected        = "Detected game."
        DirConfirm             = "Is this directory correct?"
        YesLabel               = "&Yes"
        NoLabel                = "&No"
        YesHelp                = "Confirm"
        NoHelp                 = "Cancel"
        WillDownloadCount      = "Will download {0} files..."
        GameExeNotFound        = "Game.exe not found ({0}). Please verify the game installation directory"
        DownloadStart          = "Starting download..."
        FileSizeBytes          = "File size: {0}"
        ProxyTitle             = ""
        ProxyPrompt            = "Please choose download method:"
        ProxyChoiceLabelNo     = "&No proxy"
        ProxyChoiceHelpNo      = "Connect directly without proxy"
        ProxyChoiceLabelGHP    = "&GitHub proxy"
        ProxyChoiceHelpGHP     = "Accelerate download via gh-proxy mirror"
        ProxyChoiceLabelCustom = "&Custom proxy"
        ProxyChoiceHelpCustom  = "Use a custom HTTP / HTTPS proxy server"
        ProxyInputUrl          = "Enter GitHub proxy mirror URL (default https://gh-proxy.org)"
        ProxyInputCustom       = "Enter custom HTTP proxy address (default http://127.0.0.1:7890)"
        ProxyConflictDetailed  = "UseProxy and UseGitHubProxy cannot be used together. Choose one proxy method."
        CompatibleWebReqErr    = "[Compatible] Invoke-WebRequest failed: {0}"
        RetryFetch             = "Fetch failed, retry {0}..."
        SavedDirFound          = "Found previously saved game installation directory: {0}"
        SavedDirInvalid        = "Previously saved game installation directory is invalid. Please enter again."
    }
}
$culture = [System.Globalization.CultureInfo]::CurrentCulture
[System.Threading.Thread]::CurrentThread.CurrentCulture = $culture
[System.Threading.Thread]::CurrentThread.CurrentUICulture = $culture
$script:Lang = (Get-UICulture).Name
if (-not $I18N.ContainsKey($Lang)) { $script:Lang = "en-US" }
function T {
    param($Key, [Parameter(ValueFromRemainingArguments = $true)]$Args)
    $text = $I18N[$script:Lang][$Key]
    if (-not $text) { $text = $I18N["en-US"][$Key] }
    if ($Args) {
        return $text -f $Args.ToArray()
    }
    return $text
}
function Show-Pause {
    param([string]$Text = (T "PressAnyKey"))
    Write-Host "$Text" -ForegroundColor Cyan
    [System.Console]::ReadKey($true) > $null
}
function Show-YesNoPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        [string]$Title = "",
        [ValidateRange(0, 1)]
        [int]$DefaultIndex = 0,
        [string[]]$Labels = @((T "YesLabel"), (T "NoLabel")),
        [string[]]$Helps = @((T "YesHelp"), (T "NoHelp"))
    )
    if ($Labels.Count -ne $Helps.Count) {
        throw (T "LabelsHelpsCountMismatch")
    }
    $choices = for ($i = 0; $i -lt $Labels.Count; $i++) {
        [System.Management.Automation.Host.ChoiceDescription]::new($Labels[$i], $Helps[$i])
    }
    return $Host.UI.PromptForChoice($Title, $Message, $choices, $DefaultIndex) -eq 0
}
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    function Invoke-WebRequestCompatible {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Uri,
            [Parameter(Mandatory = $false)]
            [string]$OutFile
        )
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            try {
                $client = New-Object System.Net.WebClient
                if ($UseProxy) {
                    $client.Proxy = New-Object System.Net.WebProxy($Proxy)
                }
                if ($OutFile) {
                    $client.DownloadFile($Uri, $OutFile)
                    return $null
                }
                else {
                    $response = $client.DownloadString($Uri)
                    return $response
                }
            }
            catch {
                throw (T "CompatibleWebReqErr" $_)
            }
        }
        else {
            $params = @{
                Uri             = $Uri
                UseBasicParsing = $true
            }
            if ($UseProxy) {
                $params.Proxy = $Proxy
            }
            if ($OutFile) {
                $params.OutFile = $OutFile
                Invoke-WebRequest @params
            }
            else {
                return Invoke-WebRequest @params
            }
        }
    }
    function Invoke-RestMethodCompatible {
        param([string]$Uri)
        $maxRetries = 2
        $lastError = $null
        for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
            try {
                if ($PSVersionTable.PSVersion.Major -lt 5) {
                    $rawJson = Invoke-WebRequestCompatible -Uri $Uri
                    $result = $rawJson | ConvertFrom-Json
                    return $result
                }
                else {
                    $params = @{
                        Uri             = $Uri
                        UseBasicParsing = $true
                        ErrorAction     = "Stop"
                    }
                    if ($UseProxy) {
                        $params.Proxy = $Proxy
                    }
                    return Invoke-RestMethod @params
                }
            }
            catch {
                $lastError = $_
                if ($attempt -lt $maxRetries) {
                    Write-Host (T "RetryFetch" $attempt) -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
            }
        }
        throw $lastError
    }
    function Get-DownloadUrl {
        param([string]$OriginalUrl)
        if ($UseGitHubProxy) {
            $githubProxy = $GitHubProxy.TrimEnd('/')
            return "$githubProxy/$OriginalUrl"
        }
        return $OriginalUrl
    }
    function Get-FileSha256 {
        param([string]$FilePath)
        try {
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $stream = [System.IO.File]::OpenRead($FilePath)
            try {
                $hashBytes = $sha256.ComputeHash($stream)
                return ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
            }
            finally {
                $stream.Close()
            }
        }
        catch {
            return $null
        }
    }
    function Format-FileSize {
        param([long]$Bytes)
        if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
        if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
        if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
        return "$Bytes B"
    }
    function Select-ProxyMode {
        $proxyChoices = @(
            [System.Management.Automation.Host.ChoiceDescription]::new((T "ProxyChoiceLabelNo"), (T "ProxyChoiceHelpNo")),
            [System.Management.Automation.Host.ChoiceDescription]::new((T "ProxyChoiceLabelGHP"), (T "ProxyChoiceHelpGHP")),
            [System.Management.Automation.Host.ChoiceDescription]::new((T "ProxyChoiceLabelCustom"), (T "ProxyChoiceHelpCustom"))
        )
        $selected = $Host.UI.PromptForChoice((T "ProxyTitle"), (T "ProxyPrompt") , $proxyChoices, 1)
        switch ($selected) {
            1 {
                if (Show-YesNoPrompt -Message (T "ProxyChangeConfirm") -DefaultIndex 1) {
                    $url = Read-Host (T "ProxyInputUrl")
                    if ([string]::IsNullOrWhiteSpace($url)) { $url = $GitHubProxy }
                    $url = $url.TrimEnd('/')
                    $Global:UseGitHubProxy = $true
                    $Global:GitHubProxy = $url
                }
            }
            2 {
                $addr = Read-Host (T "ProxyInputCustom")
                if ([string]::IsNullOrWhiteSpace($addr)) { $addr = $Proxy }
                $Global:UseProxy = $true
                $Global:Proxy = $addr
            }
        }
    }
    function Get-SavedGameDir {
        try {
            $regValue = Get-ItemProperty -Path $Global:RegPath -Name $Global:RegName -ErrorAction Stop
            return $regValue.$Global:RegName
        }
        catch {
            return $null
        }
    }
    function Save-GameDir {
        param([string]$Path)
        try {
            if (-not (Test-Path $Global:RegPath)) {
                New-Item -Path $Global:RegPath -Force -ErrorAction Stop | Out-Null
            }
            Set-ItemProperty -Path $Global:RegPath -Name $Global:RegName -Value $Path -ErrorAction Stop
        }
        catch {
            # silently fail - registry save is non-critical
        }
    }
    if ($UseGitHubProxy -and $UseProxy) {
        throw (T "ProxyConflictDetailed")
    }
    Clear-Host
    $host.UI.RawUI.WindowTitle = T "Title"
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  " (T "Title") -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host (T "GameDirHelp") -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    
    $gameRoot = ""
    $savedDir = Get-SavedGameDir
    if ($savedDir) {
        Write-Host (T "SavedDirFound" $savedDir) -ForegroundColor Cyan
        $exePath = Join-Path $savedDir "game\Game\Binaries\Win64\Game.exe"
        if ((Test-Path $savedDir) -and (Test-Path $exePath)) {
            $gameRoot = $savedDir
            Write-Host (T "GameDirDetected") -ForegroundColor Green
        }
    }
    if ($savedDir -and [string]::IsNullOrEmpty($gameRoot)) {
        Write-Host (T "SavedDirInvalid") -ForegroundColor Yellow
    }
    while ([string]::IsNullOrEmpty($gameRoot)) {
        $inputDir = Read-Host (T "InputGameDir")
        $inputDir = $inputDir.Trim()
        if ([string]::IsNullOrWhiteSpace($inputDir)) {
            continue
        }
        $inputDir = $inputDir.Trim('"', "'")
        if (-not (Test-Path $inputDir)) {
            Write-Host (T "GameDirNotFound" $inputDir) -ForegroundColor Red
            continue
        }
        $exePath = Join-Path $inputDir "game\Game\Binaries\Win64\Game.exe"
        if (-not (Test-Path $exePath)) {
            Write-Host (T "GameExeNotFound" $inputDir) -ForegroundColor Red
        }
        else {
            $gameRoot = $inputDir
            Write-Host (T "GameDirDetected") -ForegroundColor Green
            break
        }
        if (Show-YesNoPrompt -Message (T "DirConfirm") -DefaultIndex 1) {
            $gameRoot = $inputDir
            break
        }
    }
    # Save the valid directory to registry
    Save-GameDir -Path $gameRoot
    $modsDir = Join-Path $gameRoot $ModsSubPath
    Write-Host (T "FetchingLatest") -ForegroundColor Green
    try {
        "localization=1" | Out-File (Join-Path $gameRoot "localization.txt") -Encoding utf8
        $latestRelease = Invoke-RestMethodCompatible -Uri "$ApiBase/releases/latest"
        $tagName = $latestRelease.tag_name
        $releaseName = $latestRelease.name
        $releaseAssets = $latestRelease.assets
        Write-Host (T "ParsedReleaseInfo" $releaseName $tagName) -ForegroundColor Cyan
        $assetMap = @{}
        foreach ($asset in $releaseAssets) {
            $name = $asset.name
            $sha256Hex = ""
            if ($asset.digest -match "^sha256:([a-f0-9]+)$") {
                $sha256Hex = $Matches[1]
            }
            $assetMap[$name] = @{
                Sha256 = $sha256Hex
                Url    = $asset.browser_download_url
                Size   = $asset.size
            }
        }
    }
    catch {
        throw (T "FetchLatestFail" $_.Exception.Message)
    }
    Write-Host (T "CheckingLocalMods") -ForegroundColor Green
    if (-not (Test-Path $modsDir)) {
        Write-Host (T "NoPaksDir" $ModsSubPath) -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
        Write-Host (T "PaksDirCreated" $modsDir) -ForegroundColor Cyan
        Write-Host (T "ModNotInstalled") -ForegroundColor Yellow
        Write-Host (T "WillDownloadCount" $assetMap.Count) -ForegroundColor Cyan
        $installMode = "install"
    }
    else {
        $existingPaks = @()
        foreach ($assetName in $assetMap.Keys) {
            $localPath = Join-Path $modsDir $assetName
            if (Test-Path $localPath) {
                $existingPaks += $assetName
            }
        }
        if ($existingPaks.Count -eq 0) {
            Write-Host (T "ModNotInstalled") -ForegroundColor Yellow
            Write-Host (T "WillDownloadCount" $assetMap.Count) -ForegroundColor Cyan
            $installMode = "install"
        }
        else {
            Write-Host (T "ModFilesFound" $existingPaks.Count) -ForegroundColor Cyan
            $needUpdate = $false
            $needDownload = @{}
            foreach ($assetName in $assetMap.Keys) {
                $localPath = Join-Path $modsDir $assetName
                $assetInfo = $assetMap[$assetName]
                if (Test-Path $localPath) {
                    Write-Host (T "Sha256Verify" $assetName) -ForegroundColor Gray
                    $localHash = Get-FileSha256 -FilePath $localPath
                    if ($localHash -and $assetInfo.Sha256 -and ($localHash -eq $assetInfo.Sha256)) {
                        Write-Host (T "Sha256Match") -ForegroundColor Green
                    }
                    else {
                        Write-Host (T "Sha256Mismatch") -ForegroundColor Yellow
                        $needUpdate = $true
                        $needDownload[$assetName] = $assetInfo
                    }
                }
                else {
                    $needUpdate = $true
                    $needDownload[$assetName] = $assetInfo
                    Write-Host (T "Sha256Verify" $assetName) -ForegroundColor Gray
                    Write-Host (T "LocalFileMissing") -ForegroundColor Yellow
                }
            }
            if (-not $needUpdate) {
                Write-Host (T "AllUpToDate") -ForegroundColor Green
                Write-Host (T "AlreadyLatest" $releaseName) -ForegroundColor Cyan
                Show-Pause
                exit 0
            }
            Write-Host (T "WillDownloadCount" $needDownload.Count) -ForegroundColor Yellow
            $installMode = "update"
            $downloadTargets = $needDownload
        }
    }
    Write-Host (T "DownloadStart") -ForegroundColor Green
    if (-not $UseGitHubProxy -and -not $UseProxy) {
        Select-ProxyMode
    }
    if ($installMode -eq "install") {
        $downloadTargets = $assetMap
    }
    $totalFiles = $downloadTargets.Count
    $currentFile = 0
    $successCount = 0
    $failCount = 0
    foreach ($entry in $downloadTargets.GetEnumerator()) {
        $fileName = $entry.Key
        $assetInfo = $entry.Value
        $currentFile++
        $localPath = Join-Path $modsDir $fileName
        $downloadUrl = Get-DownloadUrl -OriginalUrl $assetInfo.Url
        Write-Host (T "Downloading" $fileName (Format-FileSize $assetInfo.Size)) -ForegroundColor Cyan
        Write-Host (T "DownloadProgress" $currentFile $totalFiles) -ForegroundColor Gray
        try {
            Invoke-WebRequestCompatible -Uri $downloadUrl -OutFile $localPath
            if ($assetInfo.Sha256) {
                $downloadedHash = Get-FileSha256 -FilePath $localPath
                if ($downloadedHash -ne $assetInfo.Sha256) {
                    Write-Host (T "Sha256Corrupted") -ForegroundColor Red
                    Remove-Item $localPath -Force -ErrorAction SilentlyContinue
                    throw "SHA256 mismatch"
                }
            }
            Write-Host (T "DownloadComplete" $fileName) -ForegroundColor Green
            Write-Host (T "FileSizeBytes" (Format-FileSize $assetInfo.Size)) -ForegroundColor Gray
            $successCount++
        }
        catch {
            Write-Host (T "DownloadError" $_.Exception.Message) -ForegroundColor Red
            $failCount++
        }
    }
    if ($failCount -eq 0) {
        Write-Host (T "InstallSuccess") -ForegroundColor Green
        Write-Host (T "AlreadyLatest" $releaseName) -ForegroundColor Cyan
    }
    else {
        Write-Host (T "DownloadResultSummary" $successCount $totalFiles $failCount) -ForegroundColor Yellow
    }
    Show-Pause
}
catch {
    Write-Host $_ -ForegroundColor Red
    Show-Pause
}
finally {
    $scriptPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "$([System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)).ps1"
    if (Test-Path $scriptPath) { Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue }
}