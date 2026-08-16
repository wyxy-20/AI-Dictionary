<#
.SYNOPSIS
    构建 AI Dictionary Windows Release 版本。
.DESCRIPTION
    项目目录包含中文（AI词典），MSVC 构建管线无法正确处理非 ASCII 路径，
    因此本脚本自动创建 ASCII 名称的目录联接（junction）并从该路径构建，
    产物位于 build\windows\x64\runner\Release\ai_dictionary.exe。
    若项目目录本身已是纯 ASCII 路径，可直接在真实目录构建，无需 junction。
#>
$ErrorActionPreference = 'Stop'

$real = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$junction = Join-Path (Split-Path $real) 'ai-dict-build'

# 路径包含非 ASCII 字符时使用 junction 构建（MSVC 无法处理中文路径）。
$hasNonAscii = $real.ToCharArray() | Where-Object { [int]$_ -gt 127 } | Select-Object -First 1
if (-not $hasNonAscii) {
    Write-Output "项目路径为纯 ASCII，直接在当前目录构建..."
    flutter pub get
    flutter build windows --release
    Write-Output ""
    Write-Output "构建完成: $real\build\windows\x64\runner\Release\ai_dictionary.exe"
    exit 0
}

if (Test-Path $junction) {
    $item = Get-Item $junction
    if ($item.LinkType -ne 'Junction') {
        throw "路径已存在但不是目录联接: $junction"
    }
} else {
    New-Item -ItemType Junction -Path $junction -Target $real | Out-Null
    Write-Output "已创建构建联接: $junction -> $real"
}

Push-Location $junction
try {
    flutter pub get
    flutter build windows --release
    Write-Output ""
    Write-Output "构建完成: $junction\build\windows\x64\runner\Release\ai_dictionary.exe"
    Write-Output "提示: 产物位于 junction 目录中，发布前请复制到真实项目目录，例如："
    Write-Output "  Copy-Item '$junction\build\windows\x64\runner\Release\*' '$real\dist\' -Recurse"
} finally {
    Pop-Location
}
