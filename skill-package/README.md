# MacClock Agent Skill

Control MacClock timers and Pomodoro sessions on macOS through AI agents like Claude Code.

## Installation

```bash
npx skills add henry11996/macclock-skill
```

## Requirements

- macOS
- [MacClock app](https://github.com/henry11996/MacClock) installed and running

## Features

- **Countdown Timers**: Set timers with custom labels and durations
- **Shell Commands**: Execute commands when timer completes
- **Loop Mode**: Auto-restart timers for recurring reminders
- **Pomodoro**: Start, pause, and reset Pomodoro sessions
- **Chinese Support**: Full support for Chinese labels and commands

## Quick Examples

After installation, you can ask your AI agent:

- "Set a 5 minute timer"
- "設定 25 分鐘專注計時器"
- "Start pomodoro"
- "開始番茄鐘"
- "Cancel all timers"

## URL Scheme

The skill uses MacClock's URL scheme:

```bash
# Timer
open "macclock://timer?sec=300&label=Focus"

# Pomodoro
open "macclock://pomodoro?action=start"

# Cancel
open "macclock://timer?action=cancel&all=true"
```

## Documentation

- [SKILL.md](SKILL.md) - Skill definition and commands
- [references/AI-Integration.md](references/AI-Integration.md) - Full API documentation

## License

MIT License - See [LICENSE](LICENSE)
