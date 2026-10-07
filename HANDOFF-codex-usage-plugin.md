# Codex Usage TrafficMonitor 插件交接记录

## 当前目标

将 `codex-usage-monitor` 移植为 TrafficMonitor 插件，基于 fork 仓库开发，并安装到用户正在使用的便携版 TrafficMonitor。

## 仓库与安装位置

- 主程序源码：`D:\Projects\TrafficMonitor`
- 插件 fork：`D:\Projects\TrafficMonitorPlugins` (`https://github.com/wang-yichun/TrafficMonitor.git`)
- 插件源码：`D:\Projects\TrafficMonitorPlugins\Plugins\CodexUsage\`
- 当前安装目录：`D:\STools\TrafficMonitor`
- 插件安装文件：`D:\STools\TrafficMonitor\plugins\CodexUsage.dll`
- 已安装 API 9 宿主备份：`D:\STools\TrafficMonitor-backup-api9-20261007-231552552`
- 本次旧插件 DLL 备份：`D:\STools\TrafficMonitor-backup-codexusage-20261007-234844`
- 计划任务：`\TrafficMonitor\Autorun for Ethan`

## 当前故障与结论

- 用户报告：主程序启动后立即反复弹出“遇到不适当的参数。”，约每秒一次；可以趁弹窗间隔打开插件详情。
- 插件管理器显示加载成功，详情中可读到 CodexUsage 的名称、版本及一个显示项。
- 根因路径已定位：宿主每次 `OnMonitorInfoUpdated` 都更新鼠标提示；`GetMouseTipsInfo()` 调用 `GetPlauginTooltipInfo()`，每次都会读取插件 `GetTooltipInfo()`，即使插件显示项没有放到任务栏上。
- 原插件把完整多行 `account_details`（账号信息、JSON 字段和 Token 统计）返回给 `GetTooltipInfo()`，宿主每秒反复将其作为普通提示文本处理。用户的弹窗频率与该调用路径吻合。
- 修复已完成：普通 tooltip 改为简短状态和 5 小时/7 天额度余量摘要；完整内容继续由插件自己的详情弹窗显示。
- 当前配置恢复为 `plugin_disabled = CodexUsage.dll`，`plugin_display_item` 为空。用户主程序已关闭，计划任务为 `Ready`。保留此禁用设置，不要自动启用。

## 诊断与验证记录

- 插件详情页右键处理没有验证鼠标命中的行列，但这与“启动后每秒弹窗”不符，不是本次根因。
- `DataRequired()` 为空；后台 worker 首轮刷新后约每 60 秒刷新一次，不符合每秒弹窗频率。
- PluginTester 中选择 CodexUsage 并观察约 6 秒，没有出现同类模态错误。PluginTester 不会像宿主那样每秒更新插件 tooltip，所以这不能单独排除宿主集成问题。
- 宿主对照：CodexUsage 禁用时运行约 6 秒，没有弹窗。
- 旧 DLL 对照：临时启用旧 DLL、保持 `plugin_display_item` 为空时，约 8 秒内出现两次同一弹窗；证明问题不依赖任务栏自绘。
- 修复后对照：临时启用新 DLL、保持 `plugin_display_item` 为空时，运行约 9 秒没有同类弹窗。
- 临时测试前后 `config.ini` 的 SHA-256 均为 `03DD865702BEAF395587DFA6556749C99C40DABC961251B5D293BEF42C0A8045`，原禁用设置已恢复。
- 新 DLL 已重新构建并安装，构建产物和安装文件哈希已比对一致；SHA-256 前缀为 `B2DA1F33965EDBAD033B16547A01D82D97E0591A4EF54F56FD122…`。
- fork x64 Release solution 构建成功。完整 solution 有其他插件原有的类型转换及编码警告。
- 第一次测试器监控脚本曾误把测试器主对话框当成模态框并提前关闭；之后修正脚本完成约 6 秒观察。不要引用第一次结果。

## 后续步骤

1. 用户下次启动时可在插件管理器中启用 CodexUsage；如需任务栏卡片，再把 `CodexUsageQuota9` 加入任务栏显示项。
2. 当前短 tooltip 已通过“插件启用、任务栏显示项为空”的宿主对照验证；新 DLL 在真实任务栏显示卡片下的视觉表现尚未复核。
3. 用户要求每次源代码修改后都重新安装插件。后续改动需重新构建 fork 的 `CodexUsage` x64 Release、备份旧 DLL、复制新 DLL 并比对哈希。
4. 主程序及 PluginTester 均已关闭；如果还要在宿主中做视觉验证，应先告知用户即将启动程序，并在结束后关闭。

## 需要保留的工作区状态

主仓库和 fork 均有既存未提交改动；不要执行 reset、checkout 或清理操作。主要包括主仓库插件接口、插件管理和解决方案变更，以及 fork 的 PluginTester、接口头文件、解决方案和新增 CodexUsage 插件目录。

## 本次代码修改与安装

修改了 fork 插件及主项目镜像中的 `GetTooltipInfo()`，让宿主每秒获取的普通提示不再承载详细多行数据。构建和重新安装成功。临时启用对照测试结束后，原始配置已恢复；TrafficMonitor 与 PluginTester 均已关闭。

## 2026-10-08 气泡与任务栏显示修复

- 气泡增加外部位置定时检查、右上角关闭、Esc 和再次点击收起，覆盖鼠标从未进入气泡时的关闭路径。
- 详情改为左侧 Token / 账号 / 额度标签数值分组，右侧独立重置卡，日期采用北京时间，倒计时每秒更新。
- 任务栏重置卡读取可用卡 expires_at，按到期时间排序并显示剩余天数（不足一天显示小时/分钟），独立小号字体避免数字省略，紧跟倒计时排列；不再显示额度重置小时或月中日期。
- 两行主进度块下面加入深灰色剩余时间比例条（5 小时 / 7 天），绘制与宽度随宿主字体缩放。
- fork 与主项目镜像源文件同步。x64 Release 构建通过；临时 C++ 回归程序验证 ISO 到期时间解析、卡片文本、GDI 时间条像素及气泡关闭/收起/未进入时外部关闭通过。
- 新 DLL 安装到 D:\STools\TrafficMonitor\plugins\CodexUsage.dll，源文件与安装文件 SHA256 一致：5674D6590B0A9D8A412573E7FC596C9B183B3A10DE1429FA1DB309CD66B37473。
- 旧 DLL 和退出后配置备份：D:\STools\TrafficMonitor-backup-codexusage-20261008-000953276。配置不作修改，保留用户最新启用状态。
- 宿主已正常退出并尝试重新启动，启动时出现 Windows UAC 提权提示。真实宿主视觉、鼠标交互由用户继续验收；回归程序不等同于真实任务栏验收。

## 2026-10-08 最终任务栏排版与提交状态

- 进度改为 10 个窄竖向块，每格表示 10%，临界格按剩余比例保留底部绿色。
- 基准方块宽约 8、高约 13，随宿主字体缩放；方块和时间条整体下移 3 个物理像素。
- 时间条与自身方块相隔 1 个物理像素，为下一行保留独立空隙；重置卡缩为约 14 的方形尺寸，上下留白。
- 5h/7d 标签按实际宽度计算，并与方块保持同方块到“余”字相同的缩放间距。
- 自动语言为 0 时读取 Windows 界面语言，中文恢复“余”；百分比与倒计时合并为紧凑文本。
- 数据刷新间隔为每次刷新完成后等待 60 秒；任务栏和详情倒计时约每秒更新。
- 最新 DLL 已安装并重启宿主，源产物与安装文件哈希一致；当前安装 SHA256：85D1766CF4E9B79F7EB39990CE62D8071F82E376246F231B09034014F7352492。
- 用户已多轮截图对照任务栏并调整位置、尺寸和间距。详情气泡的最终外部关闭和布局仍需用户实际交互确认。
- 前述旧版“禁用并关闭”和 UAC 等待记录仅为历史状态，当前保留用户最新配置，宿主运行中。
