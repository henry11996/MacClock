---
name: macclock
description: Control MacClock timers, Pomodoro, and schedules on macOS. Set countdown timers, manage Pomodoro sessions, and create scheduled tasks. Triggers on "timer", "計時器", "pomodoro", "番茄鐘", "倒數", "countdown", "schedule", "排程".
compatibility: Requires macOS and MacClock app installed
metadata:
  author: henry11996
  version: "1.1"
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
| `color` | No | Timer color (see colors below, default: blue) |
| `command` | No | Shell command to run on completion (URL encoded) |
| `repeat` | No | `true` to auto-restart timer (loop mode) |

**Available Colors:**
| Name | Hex | Chinese |
|------|-----|---------|
| `blue` | `3B82F6` | 藍色 |
| `red` | `EF4444` | 紅色 |
| `green` | `22C55E` | 綠色 |
| `purple` | `8B5CF6` | 紫色 |
| `orange` | `F97316` | 橙色 |
| `pink` | `EC4899` | 粉色 |
| `cyan` | `06B6D4` | 青色 |
| `yellow` | `EAB308` | 黃色 |

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

### Schedule Control
```bash
# Add a schedule
open "macclock://schedule?action=add&time=<HH:MM>&do=<action>&repeat=<rule>&name=<label>"

# List all schedules
open "macclock://schedule?action=list"

# Toggle schedule on/off
open "macclock://schedule?action=toggle&label=<name>"

# Remove a schedule
open "macclock://schedule?action=remove&label=<name>"
```

**Schedule Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| `time` | Yes | Time in HH:MM format (24-hour) |
| `do` | Yes | Action: `pomodoro`, `timer`, `command`, `notify` |
| `name` | No | Schedule label |
| `repeat` | No | `daily`, `weekday`, `weekend`, or hours interval (e.g., `2`) |

**For `do=timer`:**
| Parameter | Description |
|-----------|-------------|
| `sec` | Duration in seconds (default: 300) |
| `label` | Timer label |

**For `do=notify`:**
| Parameter | Description |
|-----------|-------------|
| `title` | Notification title |
| `msg` | Notification message |

**For `do=command`:**
| Parameter | Description |
|-----------|-------------|
| `cmd` | Shell command to execute (URL encoded) |

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
| Red timer for urgent task | `open "macclock://timer?sec=300&label=緊急&color=red"` |
| Green timer for break | `open "macclock://timer?sec=600&label=休息&color=green"` |
| Timer with custom hex color | `open "macclock://timer?sec=300&color=FF6B6B"` |
| Speak when timer ends | `open "macclock://timer?sec=60&command=say%20時間到"` |
| Open Safari when done | `open "macclock://timer?sec=60&command=open%20-a%20Safari"` |
| Loop timer (say ok every 5s) | `open "macclock://timer?sec=5&label=Loop&command=say%20ok&repeat=true"` |
| Start pomodoro | `open "macclock://pomodoro?action=start"` |
| Pause pomodoro | `open "macclock://pomodoro?action=pause"` |
| Cancel timer | `open "macclock://timer?action=cancel"` |
| Cancel all timers | `open "macclock://timer?action=cancel&all=true"` |
| Daily pomodoro at 9:00 | `open "macclock://schedule?action=add&time=09:00&do=pomodoro&repeat=daily&name=Morning"` |
| Weekday reminder at 18:00 | `open "macclock://schedule?action=add&time=18:00&do=notify&title=Reminder&msg=Time%20to%20go&repeat=weekday"` |
| Every 2 hours break | `open "macclock://schedule?action=add&time=10:00&do=timer&sec=300&label=Break&repeat=2"` |
| Run command at noon | `open "macclock://schedule?action=add&time=12:00&do=command&cmd=say%20Lunch%20time"` |
| List schedules | `open "macclock://schedule?action=list"` |
| Toggle schedule | `open "macclock://schedule?action=toggle&label=Morning"` |
| Remove schedule | `open "macclock://schedule?action=remove&label=Morning"` |

## Notes
- MacClock must be running
- Duration in seconds
- Chinese labels are supported
- Starting a timer will auto-show the countdown widget if hidden
- For `command` parameter: spaces must be encoded as `%20`
- Use `repeat=true` for infinite looping timers (cancel with `action=cancel`)
- Color accepts English names, Chinese names, or hex values (e.g., `red`, `紅色`, `EF4444`)
- Maximum 20 schedules allowed
- Schedules are checked every minute
- Adding a schedule will auto-show the schedule widget if hidden

## Reference
See [references/AI-Integration.md](references/AI-Integration.md) for detailed API documentation including App Intents, Python integration, and tool definitions.
