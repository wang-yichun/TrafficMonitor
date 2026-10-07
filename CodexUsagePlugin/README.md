# Codex Usage TrafficMonitor Plugin

This plugin adds a two-row, segmented 5-hour / 7-day Codex quota display to TrafficMonitor's taskbar window. It also reads today's cumulative token totals from local Codex session logs.

## Build and install

Build `CodexUsagePlugin` as x64 (or the same architecture as the TrafficMonitor executable). The solution places the DLL in `Bin/<Platform>/<Configuration>/plugins/CodexUsage.dll`. Copy that DLL into the `plugins` folder beside the TrafficMonitor executable, restart TrafficMonitor, then enable **Codex quota** in the taskbar display-item settings.

Click the item to open the detail panel, or right-click it for the details and manual-refresh commands. The host tooltip contains a short quota summary; account and token details stay in the plugin popup.

## Data and privacy

The plugin reads the access token and optional account ID from `%CODEX_HOME%\\auth.json`, or `%USERPROFILE%\\.codex\\auth.json` when `CODEX_HOME` is not set. It sends the token only in HTTPS authorization headers to the Codex usage and reset-credit endpoints. It does not write credentials or API responses to disk or logs.

For today's local token totals, it scans the current date's Codex session JSONL files and uses the latest cumulative token-count event per file. The summary contains input, cached input, output, reasoning, total, session count, and unreadable-log count.

The plugin currently displays Codex data only. It includes the custom detail panel, but its labels currently support Chinese and English rather than all languages offered by the standalone monitor.

## Display and refresh

The quota display has ten narrow vertical cells per row. Each cell represents 10%; partial quota fills the cell from the bottom. A thin gray line below each row shows its remaining time ratio. Reset cards show expiry days, switching to hours or minutes near expiry.

Click the item to open or close the grouped detail panel. The panel also closes with its close button, Escape, or when the pointer leaves the popup and its opening position. Account, quota and local token data refresh after a 60-second wait following each refresh; visible countdowns update every second. Manual refresh is available in the plugin commands.
