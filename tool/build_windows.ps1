<#
.SYNOPSIS
    构建 AI Dictionary Windows Release 版本。
.DESCRIPTION
    项目目录包含中文（AI词典），MSVC 构建管线无法正确处理非 ASCII 路径，
    因此本脚本自动创建 ASCII 名称的目录联接（junction）并从该路径构建，
    产物位于 build\windows\x64\runner\Release\ai_dictionary.exe。
#>
$ErrorActionPreference = 'Stop'

$real = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$junction = Join-Path (Split-Path $real) 'ai-dict-build'

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
} finally {
    Pop-Location
}
