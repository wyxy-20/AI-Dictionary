<#
.SYNOPSIS
    同步远程词库到内置种子数据（assets/data/terms/*.json）。
.DESCRIPTION
    词库每周由 AI 更新到 AI-Terms-Database 仓库。发版前运行本脚本，
    把最新远程词库下载并拆分为字母文件，随安装包内置：
      - 新装用户启动即有完整词库（无需联网等待下载）
      - 本地词库版本与远程一致 -> 启动跳过下载，仅当远程更新时才增量同步
    用法：
      .\tool\sync_seed.ps1
    完成后请更新 lib/core/config/app_config.dart 的
    seedDictionaryVersion 为远程 version.json 中的版本号。
#>
$ErrorActionPreference = 'Stop'

$real = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$target = Join-Path $real 'assets\data\terms'
$tmp = Join-Path $env:TEMP 'ai_dict_remote_terms.json'

$baseUrl = 'https://cdn.jsdelivr.net/gh/wyxy-20/AI-Terms-Database@main'

Write-Output '下载远程词库版本信息...'
$version = Invoke-RestMethod -Uri "$baseUrl/version.json" -TimeoutSec 60
Write-Output "远程词库版本: $($version.version)（$($version.terms_count) 条）"

Write-Output '下载远程词条...'
Invoke-RestMethod -Uri "$baseUrl/terms.json" -OutFile $tmp -TimeoutSec 180

$terms = Get-Content $tmp -Raw | ConvertFrom-Json
Write-Output "下载完成: $($terms.Count) 条"

# 合并写入单个 JSON 文件（数组格式）
$json = @($terms | Sort-Object { $_.english_name }) | ConvertTo-Json -AsArray -Depth 6
Set-Content (Join-Path $target 'terms.json') $json -Encoding UTF8

# 校验
$check = Get-Content (Join-Path $target 'terms.json') -Raw | ConvertFrom-Json
$total = if ($check -is [System.Array]) { $check.Count } else { 1 }
Write-Output "校验通过: 内置词库共 $total 条"

Remove-Item $tmp -Force -ErrorAction SilentlyContinue
Write-Output ''
Write-Output '下一步：把 lib/core/config/app_config.dart 的'
Write-Output "  seedDictionaryVersion 更新为 '$($version.version)'"
