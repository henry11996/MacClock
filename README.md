# MacClock

A minimal, elegant menu bar clock and timer app for macOS.

## Features

- **Menu Bar Clock**: Clean, customizable clock display in your menu bar
- **Countdown Timers**: Set multiple timers with custom labels
- **Pomodoro Timer**: Built-in Pomodoro technique support with work/break cycles
- **Shell Commands**: Execute commands when timers complete
- **AI Integration**: Control via URL Scheme for AI agent automation
- **Siri & Shortcuts**: Full App Intents support

## Installation

Download from [Releases](https://github.com/henry11996/MacClock/releases) or build from source.

## Quick Start

### URL Scheme

```bash
# Set a 5-minute timer
open "macclock://timer?sec=300&label=Break"

# Start pomodoro
open "macclock://pomodoro?action=start"

# Timer with completion command
open "macclock://timer?sec=60&command=say%20Done"
```

### AI Agent Skill

Install the [MacClock Agent Skill](https://github.com/henry11996/macclock-skill) for Claude Code:

```bash
npx skills add henry11996/macclock-skill
```

Then ask your AI: "Set a 5 minute timer" or "開始番茄鐘"

## Documentation

- [AI Integration Guide](docs/AI-Integration.md) - Full API documentation

## Requirements

- macOS 13.0+

## License

MIT License
