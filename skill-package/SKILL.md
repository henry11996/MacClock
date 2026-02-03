---
name: macclock
description: Control MacClock timers and Pomodoro on macOS. Set countdown timers with custom labels, run shell commands on completion, and manage Pomodoro sessions. Triggers on "timer", "計時器", "pomodoro", "番茄鐘", "倒數", "countdown".
compatibility: Requires macOS and MacClock app installed
metadata:
  author: henry11996
  version: "1.0"
  platform: macOS
---

# MacClock Control

Control MacClock app via URL Scheme.

## Commands

### Set Timer
```bash
open "macclock://timer?sec=<seconds>&label=<name>"
```

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| `sec` | Yes | Duration in seconds |
| `label` | No | Timer name (default: Quick Timer) |
| `command` | No | Shell command to run on completion (URL encoded) |
| `repeat` | No | `true` to auto-restart timer (loop mode) |

### Cancel Timer
```bash
open "macclock://timer?action=cancel"              # Cancel last timer
open "macclock://timer?action=cancel&label=<name>" # Cancel by name
open "macclock://timer?action=cancel&all=true"     # Cancel all timers
```

### Pomodoro Control
```bash
open "macclock://pomodoro?action=start"   # Start
open "macclock://pomodoro?action=pause"   # Pause
open "macclock://pomodoro?action=reset"   # Reset
```

### Check Status
```bash
open "macclock://status"
```

## Common Durations
- 1 minute = 60 seconds
- 5 minutes = 300 seconds
- 10 minutes = 600 seconds
- 15 minutes = 900 seconds
- 25 minutes = 1500 seconds (Pomodoro)
- 30 minutes = 1800 seconds
- 1 hour = 3600 seconds

## Examples

| Request | Command |
|---------|---------|
| Set 5 minute timer | `open "macclock://timer?sec=300&label=5分鐘"` |
| Set 25 min focus timer | `open "macclock://timer?sec=1500&label=Focus"` |
| Speak when timer ends | `open "macclock://timer?sec=60&command=say%20時間到"` |
| Open Safari when done | `open "macclock://timer?sec=60&command=open%20-a%20Safari"` |
| Loop timer (say ok every 5s) | `open "macclock://timer?sec=5&label=Loop&command=say%20ok&repeat=true"` |
| Start pomodoro | `open "macclock://pomodoro?action=start"` |
| Pause pomodoro | `open "macclock://pomodoro?action=pause"` |
| Cancel timer | `open "macclock://timer?action=cancel"` |
| Cancel all timers | `open "macclock://timer?action=cancel&all=true"` |

## Notes
- MacClock must be running
- Duration in seconds
- Chinese labels are supported
- Starting a timer will auto-show the countdown widget if hidden
- For `command` parameter: spaces must be encoded as `%20`
- Use `repeat=true` for infinite looping timers (cancel with `action=cancel`)

## Reference
See [references/AI-Integration.md](references/AI-Integration.md) for detailed API documentation including App Intents, Python integration, and tool definitions.
