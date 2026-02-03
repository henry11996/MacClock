---
name: macclock
description: Control MacClock timers and Pomodoro. Use for setting timers, starting/pausing/resetting Pomodoro, or checking status. Triggers on "timer", "計時器", "pomodoro", "番茄鐘", "倒數".
user_invocable: true
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
| `sec` | ✅ | Duration in seconds |
| `label` | ❌ | Timer name (default: Quick Timer) |
| `command` | ❌ | Shell command to run on completion (URL encoded) |
| `repeat` | ❌ | `true` to auto-restart timer (loop mode) |

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
| 設定 5 分鐘計時器 | `open "macclock://timer?sec=300&label=5分鐘"` |
| Set 25 min focus timer | `open "macclock://timer?sec=1500&label=Focus"` |
| 計時結束時說話 | `open "macclock://timer?sec=60&command=say%20時間到"` |
| 計時結束開啟 Safari | `open "macclock://timer?sec=60&command=open%20-a%20Safari"` |
| 循環計時器（每5秒說ok） | `open "macclock://timer?sec=5&label=循環&command=say%20ok&repeat=true"` |
| 開始番茄鐘 | `open "macclock://pomodoro?action=start"` |
| Pause pomodoro | `open "macclock://pomodoro?action=pause"` |
| 取消計時器 | `open "macclock://timer?action=cancel"` |
| Cancel all timers | `open "macclock://timer?action=cancel&all=true"` |

## Notes
- MacClock must be running
- Duration in seconds
- Chinese labels are supported
- Starting a timer will auto-show the countdown widget if hidden
- For `command` parameter: spaces must be encoded as `%20`
- Use `repeat=true` for infinite looping timers (cancel with `action=cancel`)
