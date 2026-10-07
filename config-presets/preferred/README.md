# 首选配置：安装后使用

这套配置来自 `D:\STools\TrafficMonitor`，是用户选定的安装后配置，包含任务栏布局、颜色、字体、显示项目和 Codex 插件的显示选择。

## 在本仓库编译后启用

编译 `Release | x64` 后，双击仓库根目录的 `ApplyPreferredSettings.cmd`，在管理员权限提示中选择“是”。脚本会正常退出正在运行的 TrafficMonitor，备份目标目录现有配置，将这里的两个 INI 文件复制到 `Bin\x64\Release`，然后启动该目录的宿主。

Codex 插件只在独立的 `TrafficMonitorPlugins` 仓库编译。若该仓库位于本仓库旁边，脚本会安装其 `bin\x64\Release\CodexUsage.dll`；否则需先手动将插件 DLL 放到宿主的 `plugins` 目录。

以后直接运行 `RestartTrafficMonitor.cmd`。普通重启不会再次覆盖配置，程序中后续调整的设置会继续保留。

## 安装到其他目录后启用

1. 从系统托盘正常退出 TrafficMonitor。
2. 备份安装目录中的 `config.ini` 和 `global_cfg.ini`。
3. 将本目录的 `config.ini` 和 `global_cfg.ini` 复制到安装目录，与 `TrafficMonitor.exe` 放在同一层。
4. 确保安装目录的 `plugins` 文件夹包含最新版 `CodexUsage.dll`，然后启动宿主。

`global_cfg.ini` 指定 `portable_mode = true`，因此宿主读取程序目录中的配置，而不是 AppData 中的配置。

这里只保存配置快照，不包含流量历史、日志、登录凭据或插件 DLL。配置保留原来的硬盘与网卡选择；其中网卡为自动选择模式。换电脑后可在设置中调整硬件选项。Codex 登录凭据仍由插件从当前用户的 Codex 目录读取。
