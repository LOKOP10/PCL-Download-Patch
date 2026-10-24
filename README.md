# PCL 下载功能恢复补丁

给官方 PCL 2.99 exe 打一个最小 IL 补丁，恢复「下载 → 原版游戏」里被下架的 MC 版本列表。

## 背景

PCL 源码里 `RestrictMcDownload` 是编译期常量 `True`，官方 exe 编译时该常量被折叠，
`PageDownloadInstall.LoaderInit` 只保留了"关闭下载"的异常任务，正常下载分支未被编译进程序集。
所以这不是可以翻转的开关。

## 做法

把 `LoaderInit` 里"构造关闭任务"的 13 条 IL 指令删除，替换成一条：

```
ldsfld PCL.ModDownload::DlClientListLoader
```

两者类型相同（`LoaderTask<String, DlClientListResult>`），其余 7 个参数（控件、完成回调、AutoRun）直接复用。

## 用法（三种任选）

1. **把官方 exe 拖到 `运行补丁.bat` 上**（推荐，exe 可以放任何位置）
2. 把官方 `Plain Craft Launcher 2.exe` 放进本文件夹，双击 `运行补丁.bat`
3. 命令行：`powershell -ExecutionPolicy Bypass -File patch_dl.ps1 -Source "D:\某处\Plain Craft Launcher 2.exe"`

输出：在**目标 exe 所在目录**生成 `<源文件名>.unlocked.exe`（原 exe 不动）。

例：拖入 `Plain Craft Launcher 2.exe` → 生成 `Plain Craft Launcher 2.unlocked.exe`

## 前提

- 首次运行需联网下载 Mono.Cecil（约 1.6 MB）到 `%TEMP%\pclpatch`
- `deps/` 里的 dll 供 Mono.Cecil 解析程序集引用，请保持与本脚本同目录

## 文件说明

| 文件 | 作用 |
|---|---|
| `运行补丁.bat` | 双击入口，支持把 exe 拖放到它上面 |
| `patch_dl.ps1` | 补丁逻辑（支持 `-Source` 参数、自动查找 exe） |
| `deps/*.dll` | PCL 依赖程序集 |

## 注意

- 仅个人本机使用，请勿分发（该功能为官方因合规原因下架）
- 官方更新 exe 后需重新打补丁；脚本按特征定位，结构变化会报错而非改坏文件
- 本补丁只影响下载页，不改变主题锁定状态
