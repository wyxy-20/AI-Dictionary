<#
.SYNOPSIS
    构建 AI Dictionary Windows Release 版本并生成安装包。
.DESCRIPTION
    - 若项目目录包含非 ASCII 路径，自动创建 ASCII 目录联接（junction）构建；
    - 构建完成后自动生成：
        1) 便携版 zip（AI-Dictionary-vX.Y.Z-windows.zip）
        2) 安装版 Setup.exe（AI-Dictionary-vX.Y.Z-setup.exe，Inno Setup）
    - 版本号自动从 pubspec.yaml 读取，无需手动指定。
    前置要求：
      - Flutter SDK（或 FVM）
      - Inno Setup 6（ISCC.exe，可通过环境变量 ISCC 指定路径，
        否则自动检测常见安装位置）
#>
$ErrorActionPreference = 'Stop'

# ---- 自动定位 Flutter SDK（支持 FVM 与常见安装位置）----
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Get-Command fvm -ErrorAction SilentlyContinue) {
        function flutter { fvm flutter @args }
    } else {
        $flutterCandidates = @(
            "$env:LOCALAPPDATA\flutter\bin",
            "$env:USERPROFILE\flutter\bin",
            'C:\flutter\bin',
            'C:\src\flutter\bin'
        )
        $flutterBin = $flutterCandidates |
            Where-Object { Test-Path (Join-Path $_ 'flutter.bat') } |
            Select-Object -First 1
        if ($flutterBin) {
            $env:Path = "$flutterBin;$env:Path"
        } else {
            throw "未找到 Flutter SDK。请将其加入 PATH，或设置环境变量 FLUTTER_ROOT。"
        }
    }
}

$real = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$junction = Join-Path (Split-Path $real) 'ai-dict-build'

# 从 pubspec.yaml 读取版本号（如 1.9.0+1 -> 1.9.0）
$pubspec = Get-Content (Join-Path $real 'pubspec.yaml') -Raw
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)')
if (-not $versionMatch.Success) {
    throw "无法从 pubspec.yaml 解析版本号"
}
$appVersion = $versionMatch.Groups[1].Value
Write-Output "应用版本: v$appVersion"

# 路径包含非 ASCII 字符时使用 junction 构建（MSVC 无法处理中文路径）。
$hasNonAscii = $real.ToCharArray() | Where-Object { [int]$_ -gt 127 } | Select-Object -First 1
$buildRoot = $real
if ($hasNonAscii) {
    if (Test-Path $junction) {
        $item = Get-Item $junction
        if ($item.LinkType -ne 'Junction') {
            throw "路径已存在但不是目录联接: $junction"
        }
    } else {
        New-Item -ItemType Junction -Path $junction -Target $real | Out-Null
        Write-Output "已创建构建联接: $junction -> $real"
    }
    $buildRoot = $junction
}

Push-Location $buildRoot
try {
    flutter pub get
    flutter build windows --release
} finally {
    Pop-Location
}

$releaseDir = Join-Path $buildRoot 'build\windows\x64\runner\Release'
$exe = Join-Path $releaseDir 'ai_dictionary.exe'
if (-not (Test-Path $exe)) {
    throw "构建失败：未找到 $exe"
}
Write-Output "构建完成: $exe"

# ---- 1. 便携版 zip ----
$distDir = Join-Path $real 'dist'
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$zip = Join-Path $distDir "AI-Dictionary-v$appVersion-windows.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$releaseDir\*" -DestinationPath $zip
Write-Output "便携版: $zip"

# ---- 2. 安装版 Setup.exe（Inno Setup）----
$iscc = $null
if ($env:ISCC -and (Test-Path $env:ISCC)) { $iscc = $env:ISCC }
if (-not $iscc) {
    $candidates = @(
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe',
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\InnoSetup6\ISCC.exe"
    )
    $iscc = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $iscc) {
    Write-Warning "未找到 Inno Setup（ISCC.exe），跳过安装包生成。安装包需单独编译："
    Write-Warning "  ISCC.exe tool\setup.iss /DMyAppVersion=$appVersion"
} else {
    & $iscc (Join-Path $real 'tool\setup.iss') "/DMyAppVersion=$appVersion"
    $setup = Join-Path $distDir "AI-Dictionary-v$appVersion-setup.exe"
    if (Test-Path $setup) {
        Write-Output "安装版: $setup"
    } else {
        Write-Warning "安装包编译可能失败，请检查 setup.iss 输出。"
    }
}
