<#
PCL 下载功能恢复补丁
用法（三种都行）：
  1. 把官方 exe 拖到「运行补丁.bat」上        ← 推荐
  2. 把官方 exe 放进本文件夹，双击「运行补丁.bat」
  3. 命令行：powershell -File patch_dl.ps1 -Source "D:\某处\Plain Craft Launcher 2.exe"
输出：在目标 exe 所在目录生成 Plain Craft Launcher 2.unlocked.exe（原 exe 不变）
说明：仅个人本机使用，请勿分发。
#>
param(
    [string]$Source = ""
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot

function Resolve-SourceExe {
    $candidates = @()
    if ($Source -ne "") { $candidates += $Source }
    $candidates += (Join-Path $here "Plain Craft Launcher 2.exe")
    $candidates += (Join-Path (Split-Path $here -Parent) "Plain Craft Launcher 2.exe")
    $candidates += (Join-Path ([Environment]::GetFolderPath("Desktop")) "Plain Craft Launcher 2.exe")
    $candidates += "F:\PCL\Plain Craft Launcher 2.exe"
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path }
    }
    return $null
}

$exe = Resolve-SourceExe
if (-not $exe) {
    Write-Host "[错误] 没找到 Plain Craft Launcher 2.exe" -ForegroundColor Red
    Write-Host "       已查找：拖入的路径、本文件夹、上级文件夹、桌面、F:\PCL" -ForegroundColor Yellow
    Write-Host "       请把官方 exe 拖到本 bat 上，或放进本文件夹。" -ForegroundColor Yellow
    exit 1
}

$exeDir = Split-Path $exe -Parent
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($exe)
$target = Join-Path $exeDir ($baseName + ".unlocked.exe")
Write-Host ("[信息] 源文件：" + $exe) -ForegroundColor Cyan
Write-Host ("[信息] 输出到：" + $target) -ForegroundColor Cyan

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
$resolver.AddSearchDirectory($exeDir)
$resolver.AddSearchDirectory($deps)
$resolver.AddSearchDirectory($here)
$rp.AssemblyResolver = $resolver

$asm  = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($exe, $rp)
$mod  = $asm.MainModule
$type = $mod.GetType("PCL.PageDownloadInstall")
if ($null -eq $type) { throw "这不是 PCL 主程序（未找到 PCL.PageDownloadInstall）" }

$m = $null
foreach ($x in $type.Methods) { if ($x.Name -eq "LoaderInit") { $m = $x } }
if ($null -eq $m) { throw "未找到 LoaderInit 方法" }

$dlField = $null
foreach ($f in $mod.GetType("PCL.ModDownload").Fields) {
    if ($f.Name -eq "DlClientListLoader") { $dlField = $f }
}
if ($null -eq $dlField) { throw "未找到 DlClientListLoader 字段" }

$il = $m.Body.GetILProcessor()
$instrs = $m.Body.Instructions

$start = $null
foreach ($i in $instrs) { if ($i.OpCode -eq [Mono.Cecil.Cil.OpCodes]::Ldstr) { $start = $i; break } }
if ($null -eq $start) {
    Write-Host "[提示] 这个 exe 里已经没有“关闭下载”任务，可能已经打过补丁。" -ForegroundColor Yellow
    exit 0
}

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

Write-Host ("   删除 " + $toRemove.Count + " 条指令，插入 ldsfld DlClientListLoader")
$ld = $il.Create([Mono.Cecil.Cil.OpCodes]::Ldsfld, $dlField)
$il.InsertBefore($start, $ld)
foreach ($i in $toRemove) { $il.Remove($i) }
$m.Body.MaxStackSize = 9

Write-Host "== 4/4 写出文件"
$asm.Write($target)
$asm.Dispose()
Write-Host ""
Write-Host ("[完成] " + $target) -ForegroundColor Green
Write-Host "       打开它，进入「下载 → 原版游戏」应能看到版本列表。"
