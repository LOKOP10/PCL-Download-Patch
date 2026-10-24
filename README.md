# PCL 下载功能恢复补丁

给官方 PCL 2.99 exe 打一个最小 IL 补丁，恢复「下载 → 原版游戏」里被下架的 MC 版本列表。

## 背景

PCL 源码里 `RestrictMcDownload` 是编译期常量：

```vb
Public Const RestrictMcDownload As Boolean = True
```

官方 exe 编译时该常量被折叠，`PageDownloadInstall.LoaderInit` 里只保留了"关闭下载"的异常任务，
正常下载分支的代码根本没有被编译进程序集，所以没有可以翻转的开关。

## 做法

把 `LoaderInit` 里"构造关闭任务"的 13 条 IL 指令删除，替换成一条：

```
ldsfld PCL.ModDownload::DlClientListLoader
```

因为两者类型相同（`LoaderTask<String, DlClientListResult>`），其余 7 个参数（控件、
完成回调、AutoRun）完全复用，无需新建方法。

## 使用

1. 把官方 `Plain Craft Launcher 2.exe` 复制到本目录
2. 双击 `运行补丁.bat`
3. 生成 `Plain Craft Launcher 2.unlocked.exe`（原 exe 不动）
4. 运行新 exe，进入「下载 → 原版游戏」应能看到版本列表

前提：首次运行需联网下载 Mono.Cecil（约 1.6 MB）；`deps` 目录里的 dll 供 Cecil 解析程序集引用。

## 文件说明

| 文件 | 作用 |
|---|---|
| `运行补丁.bat` | 双击入口，调用 PowerShell |
| `patch_dl.ps1` | 实际补丁逻辑（自适应脚本所在目录） |
| `deps/*.dll` | PCL 的依赖程序集，供 Mono.Cecil 解析引用 |

## 注意

- 仅个人本机使用，请勿分发（该功能是官方因合规原因下架的）
- 官方更新 exe 后需重新打补丁；脚本按特征定位，结构变化会报错而非改坏文件
- 不要与未打补丁的 exe 同时运行（共用同一 `PCL\` 数据目录）
