# MacClock AI Integration

Control MacClock timers and Pomodoro via URL Scheme and App Intents.

---

## Method 1: URL Scheme

Control the app via `macclock://` URL Scheme. Quick to call, no return value.

### Timer Commands

```bash
# Quick start timer (auto-start)
open "macclock://timer?sec=300"
open "macclock://timer?sec=300&label=Break"

# Add timer (no auto-start)
open "macclock://timer?action=add&sec=300&label=Work"

# Add and start timer
open "macclock://timer?action=add&sec=300&label=Work&start=true"

# Execute command when timer ends
open "macclock://timer?sec=60&label=Remind&command=say%20Time%20is%20up"
open "macclock://timer?sec=300&command=open%20-a%20Safari"

# Loop timer (auto-repeat)
open "macclock://timer?sec=5&label=Loop&command=say%20ok&repeat=true"
```

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| `sec` | Yes | Seconds (positive integer) |
| `label` | No | Timer name (default: Quick Timer / Timer) |
| `action` | No | `add` for add mode, `cancel` to cancel timer |
| `start` | No | `true` to auto-start after adding |
| `command` | No | Shell command to execute when timer ends (URL encoded, spaces use `%20`) |
| `repeat` | No | `true` to auto-restart after completion (loop mode) |

### Cancel Timer

```bash
# Cancel last timer
open "macclock://timer?action=cancel"

# Cancel timer by name
open "macclock://timer?action=cancel&label=Break"

# Cancel all timers
open "macclock://timer?action=cancel&all=true"
```

### Pomodoro Commands

```bash
# Start pomodoro
open "macclock://pomodoro?action=start"

# Pause pomodoro
open "macclock://pomodoro?action=pause"

# Reset pomodoro
open "macclock://pomodoro?action=reset"
```

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| `action` | Yes | `start`, `pause`, `reset` |

### Status Query

```bash
open "macclock://status"
```

Output example (view in Console.app or terminal):
```
[MacClock URL] MacClock Status:
- Timer count: 2
- Running timers: 1
- Pomodoro status: Running
```

---

## Method 2: App Intents (Shortcuts)

Control via macOS Shortcuts app. Supports return values, suitable for automation workflows.

### Start Timer

**Intent Name:** `Start Timer`

```bash
# Basic usage
shortcuts run "Start Timer" -i '{"seconds": 300, "label": "Break"}'

# Seconds only
shortcuts run "Start Timer" -i '{"seconds": 60}'
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `seconds` | Int | Yes | Timer duration in seconds |
| `label` | String | No | Timer name (default: Timer) |

**Return:** `Started 300 second timer "Break"`

### Control Pomodoro

**Intent Name:** `Control Pomodoro`

```bash
# Start
shortcuts run "Control Pomodoro" -i '{"action": "start"}'

# Pause
shortcuts run "Control Pomodoro" -i '{"action": "pause"}'

# Reset
shortcuts run "Control Pomodoro" -i '{"action": "reset"}'
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | Enum | Yes | `start`, `pause`, `reset` |

**Return:** `Pomodoro started` / `Pomodoro paused` / `Pomodoro reset`

### Siri Voice Commands

Registered Siri phrases:

**Timer:**
- "Start timer in MacClock"
- "Set a timer with MacClock"

**Pomodoro:**
- "Start pomodoro in MacClock"

---

## Python Integration

### Using URL Scheme

```python
import subprocess
from urllib.parse import quote

def start_timer(seconds: int, label: str = "Timer", command: str = None, repeat: bool = False):
    """Start a timer"""
    url = f'macclock://timer?sec={seconds}&label={quote(label)}'
    if command:
        url += f'&command={quote(command)}'
    if repeat:
        url += '&repeat=true'
    subprocess.run(['open', url])

def cancel_timer(label: str = None, cancel_all: bool = False):
    """Cancel timer"""
    if cancel_all:
        url = 'macclock://timer?action=cancel&all=true'
    elif label:
        url = f'macclock://timer?action=cancel&label={quote(label)}'
    else:
        url = 'macclock://timer?action=cancel'
    subprocess.run(['open', url])

def control_pomodoro(action: str):
    """Control pomodoro (start/pause/reset)"""
    url = f'macclock://pomodoro?action={action}'
    subprocess.run(['open', url])

# Usage examples
start_timer(300, "Break time")
start_timer(60, "Remind", command="say Time is up")  # Speak when done
start_timer(5, "Loop", command="say ok", repeat=True)  # Loop timer
cancel_timer(cancel_all=True)  # Cancel all
control_pomodoro("start")
```

### Using Shortcuts (with return value)

```python
import subprocess
import json

def run_shortcut(name: str, input_data: dict) -> str:
    """Run shortcut and get return value"""
    result = subprocess.run(
        ['shortcuts', 'run', name, '-i', json.dumps(input_data)],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()

def start_timer(seconds: int, label: str = "Timer") -> str:
    """Start timer"""
    return run_shortcut("Start Timer", {"seconds": seconds, "label": label})

def control_pomodoro(action: str) -> str:
    """Control pomodoro"""
    return run_shortcut("Control Pomodoro", {"action": action})

# Usage examples
print(start_timer(300, "Break"))  # Output: Started 300 second timer "Break"
print(control_pomodoro("start"))  # Output: Pomodoro started
```

---

## Claude/ChatGPT Tool Definitions

### OpenAI Function Calling Format

```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "start_timer",
        "description": "Start a countdown timer in MacClock",
        "parameters": {
          "type": "object",
          "properties": {
            "seconds": {
              "type": "integer",
              "description": "Timer duration in seconds"
            },
            "label": {
              "type": "string",
              "description": "Timer name"
            },
            "command": {
              "type": "string",
              "description": "Shell command to execute when timer ends"
            },
            "repeat": {
              "type": "boolean",
              "description": "Whether to loop (auto-restart)"
            }
          },
          "required": ["seconds"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "cancel_timer",
        "description": "Cancel MacClock timer",
        "parameters": {
          "type": "object",
          "properties": {
            "label": {
              "type": "string",
              "description": "Name of timer to cancel (cancels last if not specified)"
            },
            "all": {
              "type": "boolean",
              "description": "Whether to cancel all timers"
            }
          }
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "control_pomodoro",
        "description": "Control MacClock pomodoro",
        "parameters": {
          "type": "object",
          "properties": {
            "action": {
              "type": "string",
              "enum": ["start", "pause", "reset"],
              "description": "Action type"
            }
          },
          "required": ["action"]
        }
      }
    }
  ]
}
```

### Claude Tool Use Format

```json
{
  "tools": [
    {
      "name": "start_timer",
      "description": "Start a countdown timer in MacClock",
      "input_schema": {
        "type": "object",
        "properties": {
          "seconds": {
            "type": "integer",
            "description": "Timer duration in seconds"
          },
          "label": {
            "type": "string",
            "description": "Timer name"
          },
          "command": {
            "type": "string",
            "description": "Shell command to execute when timer ends"
          },
          "repeat": {
            "type": "boolean",
            "description": "Whether to loop (auto-restart)"
          }
        },
        "required": ["seconds"]
      }
    },
    {
      "name": "cancel_timer",
      "description": "Cancel MacClock timer",
      "input_schema": {
        "type": "object",
        "properties": {
          "label": {
            "type": "string",
            "description": "Name of timer to cancel (cancels last if not specified)"
          },
          "all": {
            "type": "boolean",
            "description": "Whether to cancel all timers"
          }
        }
      }
    },
    {
      "name": "control_pomodoro",
      "description": "Control MacClock pomodoro",
      "input_schema": {
        "type": "object",
        "properties": {
          "action": {
            "type": "string",
            "enum": ["start", "pause", "reset"],
            "description": "Action type"
          }
        },
        "required": ["action"]
      }
    }
  ]
}
```

---

## Notes

1. **App must be running**: Both URL Scheme and Shortcuts require MacClock to be running
2. **First time using shortcuts**: Need to confirm MacClock's App Shortcuts are recognized in the Shortcuts app
3. **URL encoding**: If label or command contains special characters, URL encode them (spaces use `%20`)
4. **Sandbox limitations**: MacClock runs in App Sandbox, some operations may be restricted
5. **Auto-show countdown**: When starting a timer via URL Scheme or Shortcuts, the countdown widget will auto-show if hidden
6. **command parameter**: Shell command to execute when timer ends, e.g., `say%20Done` will say "Done"
7. **repeat parameter**: Set to `true` for timer to auto-loop until manually cancelled

---

## Troubleshooting

### URL Scheme not working

1. Confirm app is installed and has been run at least once
2. Re-register URL Scheme:
   ```bash
   /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f /Applications/MacClock.app
   ```

### Shortcuts can't find Intent

1. Confirm MacClock version includes App Intents
2. Restart the Shortcuts app
3. Search for "MacClock" or "Timer" in the Shortcuts app
