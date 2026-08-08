<#
.SYNOPSIS
    备份当前 AI Dictionary 版本（源码 ZIP + 可运行程序 ZIP）。
.DESCRIPTION
    备份到项目同级目录 "AI词典备份"。
    源码通过 git archive 生成（仅包含受版本控制的文件，干净可靠）；
    程序直接压缩 build\windows\x64\runner\Release。
    建议每次完成一次稳定迭代后运行一次，保留多个时间点快照。
#>
$ErrorActionPreference = 'Stop'

$real = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path (Split-Path $real) 'AI词典备份'
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

Push-Location $real
try {
    $rev = git describe --tags --always 2>$null
    $label = if ($LASTEXITCODE -eq 0 -and $rev) { $rev } else { 'snapshot' }
    $sourceZip = Join-Path $backupRoot ("source-{0}-{1}.zip" -f $label, $stamp)
    git archive --format=zip -o $sourceZip HEAD
    Write-Output "源码备份: $sourceZip"
} finally {
    Pop-Location
}

$release = Join-Path $real 'build\windows\x64\runner\Release'
if (Test-Path $release) {
    $appZip = Join-Path $backupRoot ("app-{0}-{1}.zip" -f $label, $stamp)
    Compress-Archive -Path $release -DestinationPath $appZip -CompressionLevel Optimal
    Write-Output "程序备份: $appZip"
} else {
    Write-Warning '未找到 Release 目录，跳过程序备份（可先运行 tool\build_windows.ps1 生成）'
}

Write-Output "备份目录: $backupRoot"
