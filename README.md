# MacClock

A minimal, elegant floating clock and timer app for macOS.

![macOS](https://img.shields.io/badge/macOS-26.0%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
[![Release](https://img.shields.io/github/v/release/henry11996/MacClock)](https://github.com/henry11996/MacClock/releases/latest)

## Download

### [⬇️ 下載最新版本](https://github.com/henry11996/MacClock/releases/latest)

1. 下載 `MacClock.dmg`
2. 打開 DMG 檔案
3. 將 MacClock 拖曳至 Applications 資料夾
4. 從 Applications 或 Launchpad 開啟 MacClock

> 首次開啟時，若出現「無法打開」提示，請至「系統設定 → 隱私權與安全性」點擊「強制打開」。

## Features

- **Floating Clock** - 浮動時鐘小工具，支援多種顯示樣式
- **Countdown Timers** - 倒數計時器，支援多個同時運行
- **Pomodoro Timer** - 番茄鐘計時器，支援工作/休息循環
- **Schedule** - 排程功能，在指定時間自動執行動作
- **Liquid Glass Effect** - 精美的玻璃視覺效果
- **Shell Commands** - 計時結束時執行指令
- **AI Integration** - URL Scheme 支援 AI 代理自動化
- **Siri & Shortcuts** - 完整 App Intents 支援

## Installation

### 方式一：下載安裝 (推薦)

從 [Releases](https://github.com/henry11996/MacClock/releases/latest) 下載最新版本 DMG。

### 方式二：從原始碼建置

```bash
git clone https://github.com/henry11996/MacClock.git
cd MacClock
open MacClock.xcodeproj
# 在 Xcode 中按 Cmd+R 執行
```

## Quick Start

### URL Scheme

```bash
# Set a 5-minute timer
open "macclock://timer?sec=300&label=Break"

# Start pomodoro
open "macclock://pomodoro?action=start"

# Timer with completion command
open "macclock://timer?sec=60&command=say%20Done"

# Schedule daily pomodoro at 9:00 AM
open "macclock://schedule?action=add&time=09:00&do=pomodoro&repeat=daily&name=開始工作"

# Schedule weekday reminder at 6:00 PM
open "macclock://schedule?action=add&time=18:00&do=notify&title=下班提醒&msg=該下班了&repeat=weekday"
```

### AI Agent Skill

Install the [MacClock Agent Skill](https://github.com/henry11996/macclock) for Claude Code:

```bash
npx skills add henry11996/macclock
```

Then ask your AI: "Set a 5 minute timer" or "開始番茄鐘"

## Documentation

- [AI Integration Guide](docs/AI-Integration.md) - Full API documentation

## Requirements

- macOS 26.0+ (Tahoe)

## License

MIT License
