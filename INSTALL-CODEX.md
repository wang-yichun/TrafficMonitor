# 给 Codex 的安装说明：TrafficMonitor + 独立 Codex 插件

这是在其他 Windows 电脑上安装这两个 fork 的执行说明。默认目标是 x64 标准版宿主、独立 Codex 插件，以及本仓库的首选配置。请实际执行安装和检查；不要只向用户复述步骤。

## 仓库和职责

两个仓库都使用 `codex/codex-usage-plugin` 分支，不要使用上游默认分支代替。

- 宿主：`https://github.com/wang-yichun/TrafficMonitor.git`
- 插件：`https://github.com/wang-yichun/TrafficMonitorPlugins.git`
- 插件唯一源码：插件仓库的 `Plugins/CodexUsage`。不要在宿主仓库恢复一份插件镜像。
- 宿主的 `config-presets/preferred` 是用户选定的安装后配置，包含便携模式和 `CodexUsageQuota9` 显示项。
- 宿主的 `InstallFromRepos.ps1` 会分别构建宿主和插件，自动把独立插件 DLL 安装到宿主安装目录的 `plugins` 下。

默认克隆到同一父目录，优先使用 `D:\Projects`。没有 D 盘时使用用户目录下的 `Projects`。安装目录独立于源码仓库；优先 `D:\STools\TrafficMonitor`，没有 D 盘则用 `%LOCALAPPDATA%\Programs\TrafficMonitor`。脚本自身默认使用后者，可通过参数指定前者。

## 安装前检查

1. 确认 Windows x64、Git、Windows PowerShell 5.1 可用。此脚本暂不处理 x86/ARM64 原生安装。
2. 检查 Visual Studio 2022 或 Build Tools：C++ 桌面开发、MSVC v143 x86/x64、对应 MFC/ATL、Windows SDK。标准版还需要 .NET Framework 4.7.2 targeting pack（项目的 `TargetFrameworkVersion` 是 `v4.7.2`）。用 Visual Studio Installer 补齐缺失组件；不要因缺 SDK 随意修改项目工具集或目标框架。
3. 安装/修复与 x64 对应的 Visual C++ 运行库；宿主使用动态 MFC。标准版运行需要管理员权限和 .NET Framework 4.7.2 或兼容的新版本。Lite 可通过 `-Edition Lite` 安装，不提供温度监控。
4. 如果已有 TrafficMonitor，检查当前进程、安装目录、便携模式、AppData 配置和开机启动项。优先在原安装目录更新，保留历史数据和无关插件。不要另建一份默认配置让用户误以为原配置丢失。
5. 检查两个 Git 工作区。已有目录先确认远程 URL 和分支，保留未提交修改，正常 fetch 后按实际状态更新；不要 reset、强制 checkout、clean 或强制推送。

## 首次获取源码

下面以 D 盘为例；运行前替换为该电脑实际选定的目录。已有仓库不要重复 clone。

```powershell
New-Item -ItemType Directory -Path D:\Projects -Force | Out-Null
git clone --branch codex/codex-usage-plugin https://github.com/wang-yichun/TrafficMonitor.git D:\Projects\TrafficMonitor
git clone --branch codex/codex-usage-plugin https://github.com/wang-yichun/TrafficMonitorPlugins.git D:\Projects\TrafficMonitorPlugins
```

## 自动构建和安装

先只检查路径和构建工具：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\Projects\TrafficMonitor\InstallFromRepos.ps1 -PluginRepository D:\Projects\TrafficMonitorPlugins -InstallDirectory D:\STools\TrafficMonitor -ValidateOnly
```

首次安装并明确应用用户的首选配置：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\Projects\TrafficMonitor\InstallFromRepos.ps1 -PluginRepository D:\Projects\TrafficMonitorPlugins -InstallDirectory D:\STools\TrafficMonitor -ApplyPreferredSettings
```

参数说明：

- `-Edition Standard`：默认；构建宿主 `Release | x64`。
- `-Edition Lite`：构建宿主 `Release (lite) | x64`。
- 插件始终独立构建 `Release | x64`。
- `-ApplyPreferredSettings`：备份后覆盖安装目录的两个 INI 文件，应用仓库配置。
- 升级时通常省略 `-ApplyPreferredSettings`，保留安装目录的现有配置。新安装目录没有两个 INI 时自动采用首选配置。若旧配置使用 AppData，继续保留该模式，未经用户要求不要强行切换。
- `-SkipBuild`：只在确认本机两个对应构建产物已存在且最新时使用，不要把其他架构或其他电脑的产物混入。
- `-SkipStart`：安装后暂不启动，便于静态检查。
- `-ValidateOnly`：检查前置条件，不构建、不复制、不关闭进程、不启动宿主。

脚本先构建两个仓库，成功后向当前 TrafficMonitor 主窗口发送 `WM_CLOSE`，等待正常保存配置并退出。若宿主已提权，安装脚本也要在管理员 PowerShell 中运行；遇到拒绝访问时不要强杀，以免丢失设置和历史。若源码目录的旧构建宿主正在运行导致链接器锁文件，先正常退出它再构建。

已有安装目录会完整备份到 `%LOCALAPPDATA%\TrafficMonitor-install-backups\时间戳`。更新采用合并复制，不删除目标目录独有的文件，不覆盖流量历史，不删除其他插件。独立插件会自动复制，并核对 SHA256。语言和内置皮肤来自宿主仓库；标准版同时复制硬件监控依赖 DLL。新安装使用便携模式后，`config.ini`、`global_cfg.ini` 与 EXE 同目录。

## 必须完成的验收

1. 检查构建退出码，并运行两个仓库的 `git diff --check`。不要把预先存在的修改当成本次安装改动。
2. 核对插件仓库 `bin\x64\Release\CodexUsage.dll` 与安装目录 `plugins\CodexUsage.dll` 的 SHA256 完全一致。
3. 启动后确认只运行一份 TrafficMonitor，实际进程路径是选定安装目录。管理员进程查不到路径时，用管理员终端确认，不要只根据进程名宣布成功。
4. 在插件管理器确认 Codex 插件加载成功，任务栏显示 `CodexUsageQuota9`，点击可查看详情。“合计”应含原始数值和“亿”换算。
5. 用当前电脑登录 Codex。插件读取该用户 `%CODEX_HOME%\auth.json`，未设置时读取 `%USERPROFILE%\.codex\auth.json`。不要复制另一台电脑的登录凭据，不要打印、提交或保存访问令牌。
6. 没有当天 Token 事件时为 0 是合理结果；执行一次真实 Codex 任务、等待插件刷新后再核验。配额网络请求失败与本地 Token 读取是不同问题，应分别检查。
7. 字体、网卡、硬盘和屏幕尺寸可能不同；保留首选样式，按新电脑情况调整硬件/位置。首选配置中的网卡是自动选择模式。
8. 不自动改开机启动。用户需要时再把启动任务或快捷方式指向新安装路径，避免旧版本仍从 STools 或其他目录启动。

构建和哈希检查不等同于真实任务栏、弹窗或新电脑干净安装验收。最后报告已完成项和仍需用户交互的项目，不要声称未做过的 UI 检查已通过。

## 后续更新与回滚

更新两个仓库后，再运行同一安装命令，通常不带 `-ApplyPreferredSettings`。在宿主源码目录内体验时可用 `RestartTrafficMonitor.cmd`，它会安装相邻插件仓库最新编译的 DLL；这个快捷脚本默认重启 `Bin\x64\Release`，不是任意安装目录。独立安装目录的更新使用 `InstallFromRepos.ps1`。

回滚前正常退出宿主，把相应备份中的旧 EXE、依赖 DLL、Codex 插件和配置恢复到安装目录，再启动。保留更新期间产生的流量历史，除非用户明确要求回滚历史数据。

## 下次可以直接交给 Codex 的提示

“请读取 TrafficMonitor 仓库的 INSTALL-CODEX.md，在这台 Windows 电脑上从两个 fork 的 codex/codex-usage-plugin 分支安装宿主和独立 Codex 插件，使用首选配置。保留已有配置和流量历史的备份，自动构建、安装插件并验收实际进程路径与 DLL 哈希。”
