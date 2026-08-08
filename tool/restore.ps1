<#
.SYNOPSIS
    从备份目录恢复 AI Dictionary 源码与可运行程序。
.DESCRIPTION
    默认列出 "AI词典备份" 目录中的备份供选择；
    也可通过 -SourceZip 直接指定源码备份。
    源码解压会覆盖当前项目文件（保留 .git 历史）；
    可选恢复 app 备份到 build\windows\x64\runner\Release。
    恢复后如开发请先执行 flutter pub get。
#>
param(
    [string]$SourceZip
)

$ErrorActionPreference = 'Stop'

$real = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$backupRoot = Join-Path (Split-Path $real) 'AI词典备份'

if (-not $SourceZip -or -not (Test-Path -LiteralPath $SourceZip)) {
    $sourceZips = Get-ChildItem $backupRoot -Filter 'source-*.zip' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    if (-not $sourceZips) {
        throw "备份目录中没有找到源码备份: $backupRoot"
    }
    Write-Output '可用的源码备份：'
    for ($i = 0; $i -lt $sourceZips.Count; $i++) {
        Write-Output ('  {0,3}. {1}' -f ($i + 1), $sourceZips[$i].Name)
    }
    $selection = Read-Host '选择序号（回车默认 1）'
    if ($selection -eq '') { $selection = '1' }
    $index = [int]$selection - 1
    if ($index -lt 0 -or $index -ge $sourceZips.Count) { throw '无效序号' }
    $SourceZip = $sourceZips[$index].FullName
}

Write-Warning "将使用 $SourceZip 覆盖项目源码（保留 .git 历史），确定继续？(Y/N)"
$answer = Read-Host
if ($answer -notin @('Y', 'y')) {
    Write-Output '已取消。'
    return
}

Expand-Archive -Path $SourceZip -DestinationPath $real -Force
Write-Output '源码已恢复。'

# 恢复配套的程序备份（相同标签-时间戳）
$stem = [System.IO.Path]::GetFileNameWithoutExtension($SourceZip)
$stem = $stem.Substring('source-'.Length)
$appZip = Join-Path (Split-Path $SourceZip) ('app-' + $stem + '.zip')
if (Test-Path -LiteralPath $appZip) {
    Write-Warning "检测到程序备份 $appZip ，恢复它覆盖 build\windows\x64\runner\Release？(Y/N)"
    $answer2 = Read-Host
    if ($answer2 -in @('Y', 'y')) {
        $runner = Join-Path $real 'build\windows\x64\runner'
        New-Item -ItemType Directory -Path $runner -Force | Out-Null
        Expand-Archive -Path $appZip -DestinationPath $runner -Force
        Write-Output '程序已恢复。'
    }
}

Write-Output ''
Write-Output '恢复完成。开发时请执行 flutter pub get；需要重新打包请运行 tool\build_windows.ps1。'
