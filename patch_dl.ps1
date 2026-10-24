<#
PCL 下载功能恢复补丁（自适应版）
用法：把官方 exe（Plain Craft Launcher 2.exe）放进本文件夹，双击「运行补丁.bat」。
输出：同目录下生成 Plain Craft Launcher 2.unlocked.exe（原 exe 不变）
说明：仅个人本机使用，请勿分发。
#>
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot

$Source = Join-Path $here "Plain Craft Launcher 2.exe"
$Target = Join-Path $here "Plain Craft Launcher 2.unlocked.exe"

if (-not (Test-Path $Source)) {
    Write-Host "[错误] 本文件夹里没有 Plain Craft Launcher 2.exe" -ForegroundColor Red
    Write-Host "       请把官方 exe 复制进来再运行。" -ForegroundColor Yellow
    exit 1
}

$work = Join-Path $env:TEMP "pclpatch"
Write-Host "== 1/4 准备 Mono.Cecil"
$cecilDll = Join-Path $work "cecil\lib\net40\Mono.Cecil.dll"
if (-not (Test-Path $cecilDll)) {
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $zip = Join-Path $work "cecil.zip"
    Write-Host "   下载 Mono.Cecil 0.11.5 ..."
    Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Mono.Cecil/0.11.5" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath (Join-Path $work "cecil") -Force
}
Add-Type -Path $cecilDll

Write-Host "== 2/4 准备依赖"
$deps = Join-Path $here "deps"
if (-not (Test-Path $deps)) { New-Item -ItemType Directory -Force -Path $deps | Out-Null }

Write-Host "== 3/4 修改 IL"
$rp = New-Object Mono.Cecil.ReaderParameters
$resolver = New-Object Mono.Cecil.DefaultAssemblyResolver
$resolver.AddSearchDirectory($here)
$resolver.AddSearchDirectory($deps)
$rp.AssemblyResolver = $resolver

$asm  = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($Source, $rp)
$mod  = $asm.MainModule
$type = $mod.GetType("PCL.PageDownloadInstall")
if ($null -eq $type) { throw "未找到 PCL.PageDownloadInstall" }

$m = $null
foreach ($x in $type.Methods) { if ($x.Name -eq "LoaderInit") { $m = $x } }
if ($null -eq $m) { throw "未找到 LoaderInit" }

$dlField = $null
foreach ($f in $mod.GetType("PCL.ModDownload").Fields) {
    if ($f.Name -eq "DlClientListLoader") { $dlField = $f }
}
if ($null -eq $dlField) { throw "未找到 DlClientListLoader" }

$il = $m.Body.GetILProcessor()
$instrs = $m.Body.Instructions

$start = $null
foreach ($i in $instrs) { if ($i.OpCode -eq [Mono.Cecil.Cil.OpCodes]::Ldstr) { $start = $i; break } }
if ($null -eq $start) { throw "未找到 ldstr" }

$toRemove = New-Object System.Collections.ArrayList
$hit = $false; $done = $false
foreach ($i in $instrs) {
    if ($i -eq $start) { $hit = $true }
    if ($hit) { [void]$toRemove.Add($i) }
    if ($hit -and $i.OpCode -eq [Mono.Cecil.Cil.OpCodes]::Newobj -and
        $i.Operand -is [Mono.Cecil.MethodReference] -and
        $i.Operand.DeclaringType.Name.StartsWith("LoaderTask")) { $done = $true; break }
}
if (-not $done) { throw "未找到 newobj LoaderTask" }

Write-Host ("   删除 " + $toRemove.Count + " 条指令")
$ld = $il.Create([Mono.Cecil.Cil.OpCodes]::Ldsfld, $dlField)
$il.InsertBefore($start, $ld)
foreach ($i in $toRemove) { $il.Remove($i) }
$m.Body.MaxStackSize = 9

Write-Host "== 4/4 写出文件"
$asm.Write($Target)
$asm.Dispose()
Write-Host ""
Write-Host ("[完成] " + $Target) -ForegroundColor Green
Write-Host "       打开它，进入「下载 → 原版游戏」应能看到版本列表。"
