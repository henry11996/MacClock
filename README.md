# MacClock

A minimal, elegant floating clock, timer, and screen-text capture tool for macOS.

![macOS](https://img.shields.io/badge/macOS-26.0%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
[![Release](https://img.shields.io/github/v/release/henry11996/MacClock)](https://github.com/henry11996/MacClock/releases/latest)

**English** | [繁體中文](README.zh-TW.md)

## Download

### [⬇️ Download the latest release](https://github.com/henry11996/MacClock/releases/latest)

1. Download `MacClock.dmg`
2. Open the DMG
3. Drag MacClock into the Applications folder
4. Launch MacClock from Applications or Launchpad

> MacClock is signed and notarized by Apple. If macOS still blocks it on first launch, go to **System Settings → Privacy & Security** and click **Open Anyway**.

## Features

- **Floating Clock** – An always-on-top clock widget with multiple display styles
- **Screen Text Capture (OCR)** – Select any region of the screen and copy its text instantly, like TextSniper or Capture2Text
- **Countdown Timers** – Run multiple countdowns at the same time
- **Pomodoro Timer** – Work/break cycles with an optional full-screen break reminder
- **Schedule** – Automatically run actions at a set time, daily, on weekdays, or at intervals
- **Notch Mode** – Show the clock and timers on either side of the MacBook notch
- **Liquid Glass Effect** – A polished glass look that matches macOS Tahoe
- **Shell Commands** – Run a command when a timer finishes
- **AI Integration** – A URL scheme that AI agents can use for automation
- **Siri & Shortcuts** – Full App Intents support

## Screen Text Capture (OCR)

Press **⇧⌘2**, drag over any text on screen, and the recognized text is copied to the clipboard.

- Uses Apple's built-in **Vision** framework. Everything runs **on-device**, and screenshots are never uploaded or saved
- Supports Traditional Chinese, Simplified Chinese, English, Japanese, and Korean, or automatic language detection
- Keeps reading order, joins CJK text without stray spaces, and merges words that were hyphenated across lines
- Works across multiple displays and Retina screens, and leaves MacClock's own windows out of the capture
- Customizable: hotkey, languages, accurate or fast mode, line breaks, overlay dimming, toast, and sound
- Can also be triggered with `macclock://ocr` or from Shortcuts/Siri

> The first time you use it, allow MacClock under **System Settings → Privacy & Security → Screen & System Audio Recording**, then relaunch the app.

## Installation

### Option 1: Download (recommended)

Get the latest DMG from [Releases](https://github.com/henry11996/MacClock/releases/latest).

### Option 2: Build from source

```bash
git clone https://github.com/henry11996/MacClock.git
cd MacClock
open MacClock.xcodeproj
# Press Cmd+R in Xcode to run
```

Run the tests:

```bash
swift test
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

# Capture text from a screen region
open "macclock://ocr"

# Schedule a daily pomodoro at 9:00 AM
open "macclock://schedule?action=add&time=09:00&do=pomodoro&repeat=daily&name=Focus"

# Schedule a weekday reminder at 6:00 PM
open "macclock://schedule?action=add&time=18:00&do=notify&title=Reminder&msg=Time%20to%20go%20home&repeat=weekday"
```

### AI Agent Skill

Install the [MacClock Agent Skill](https://github.com/henry11996/macclock) for Claude Code:

```bash
npx skills add henry11996/macclock
```

Then ask your AI: "Set a 5 minute timer" or "Start a pomodoro".

## Documentation

- [AI Integration Guide](docs/AI-Integration.md) – Full API documentation

## Requirements

- macOS 26.0+ (Tahoe)

## License

MIT License
