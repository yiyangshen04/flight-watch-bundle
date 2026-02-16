# Flight Watch Bundle

当前默认自动频率：每 3 小时一次。

## macOS（双击）

推荐顺序：

1. `run_once.command`
   - 立刻抓取一轮（带重试）。
2. `start_auto_3h.command`
   - 启用每 3 小时自动刷新（launchd）。
3. `start_public_site.command`
   - 启动本地站点 + Cloudflare 临时公网域名。

兼容入口（已改为 3 小时逻辑）：

- `start_auto_2h.command`
- `start_auto_2h_clean.command`
- `stop_auto_2h.command`

可选工具：

- `open_dashboard.command`
- `stop_auto_3h.command`
- `stop_public_site.command`
- `start_public_site_alt.command` / `stop_public_site_alt.command`
- `view_cycle_log.command`
- `view_launchd_logs.command`
- `view_public_site_log.command`
- `open_logs_folder.command`

## Windows

- `run_once_windows.cmd`
- `start_auto_3h_windows.cmd`（推荐）
- `stop_auto_3h_windows.cmd`（推荐）
- `start_auto_2h_windows.cmd` / `stop_auto_2h_windows.cmd`（兼容，内部同样按 3 小时）
- `start_public_site_windows.cmd`
- `stop_public_site_windows.cmd`

依赖：

- Node.js（`node` 可用）
- Python 3（`python` / `python3` / `py -3` 任一可用）
- cloudflared（建议：`winget install Cloudflare.cloudflared`）

## Linux（云端）

可直接在 Linux 主机运行：

- `./run_once_linux.sh`
- `./start_auto_3h_linux.sh`（安装 cron：每 3 小时）
- `./status_auto_3h_linux.sh`
- `./stop_auto_3h_linux.sh`

内部脚本位于：

- `scripts/linux/run_cycle.sh`
- `scripts/linux/install_cron_3h.sh`
- `scripts/linux/status_cron.sh`
- `scripts/linux/uninstall_cron.sh`

## GitHub Cloud（Ubuntu 定时）

已内置 GitHub Actions：

- `.github/workflows/flight-watch-3h.yml`
- 触发方式：手动 + 定时 `每 3 小时`
- Runner：`ubuntu-latest`
- 自动更新并提交：
  - `flight_watch_latest_round.json`
  - `flight_watch_latest_round.csv`
  - `flight_watch_price_history.json`
  - `flight_watch_overlay_chart.html`

## 输出文件

- `flight_watch_latest_round.json`
- `flight_watch_latest_round.csv`
- `flight_watch_price_history.json`
- `flight_watch_overlay_chart.html`

## 日志

- `logs/flight_watch_cycle.log`
- `logs/http_server.log`
- `logs/http_server.err.log`
- `logs/cloudflared.log`
- `logs/cloudflared.err.log`
- `logs/localhostrun.log`
- `~/.flight_watch_bundle_runtime/logs/launchd.out.log`
- `~/.flight_watch_bundle_runtime/logs/launchd.err.log`
