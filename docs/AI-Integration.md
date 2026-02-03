# MacClock AI 串接功能

讓外部 AI（如 Claude/ChatGPT 搭配 Python）能透過 URL Scheme 與 App Intents 控制 MacClock 的計時功能。

---

## 方法一：URL Scheme

透過 `macclock://` URL Scheme 控制 App，適合快速呼叫，無回傳值。

### 計時器指令

```bash
# 快速啟動計時器（自動開始）
open "macclock://timer?sec=300"
open "macclock://timer?sec=300&label=休息"

# 新增計時器（不自動開始）
open "macclock://timer?action=add&sec=300&label=工作"

# 新增並啟動計時器
open "macclock://timer?action=add&sec=300&label=工作&start=true"

# 計時結束執行指令
open "macclock://timer?sec=60&label=提醒&command=say%20時間到"
open "macclock://timer?sec=300&command=open%20-a%20Safari"

# 循環計時器（自動重複）
open "macclock://timer?sec=5&label=循環&command=say%20ok&repeat=true"
```

**參數說明：**
| 參數 | 必填 | 說明 |
|------|------|------|
| `sec` | ✅ | 秒數（正整數） |
| `label` | ❌ | 計時器名稱（預設：Quick Timer / Timer） |
| `action` | ❌ | `add` 表示新增模式，`cancel` 表示取消計時器 |
| `start` | ❌ | `true` 表示新增後自動啟動 |
| `command` | ❌ | 計時結束時執行的 shell 指令（需 URL 編碼，空格用 `%20`） |
| `repeat` | ❌ | `true` 表示計時結束後自動重新開始（循環模式） |

### 取消計時器

```bash
# 取消最後一個計時器
open "macclock://timer?action=cancel"

# 取消指定名稱的計時器
open "macclock://timer?action=cancel&label=休息"

# 取消全部計時器
open "macclock://timer?action=cancel&all=true"
```

### 番茄鐘指令

```bash
# 啟動番茄鐘
open "macclock://pomodoro?action=start"

# 暫停番茄鐘
open "macclock://pomodoro?action=pause"

# 重置番茄鐘
open "macclock://pomodoro?action=reset"
```

**參數說明：**
| 參數 | 必填 | 說明 |
|------|------|------|
| `action` | ✅ | `start`、`pause`、`reset` |

### 狀態查詢

```bash
open "macclock://status"
```

輸出範例（在 Console.app 或終端機查看）：
```
[MacClock URL] MacClock 狀態:
- 計時器數量: 2
- 執行中計時器: 1
- 番茄鐘狀態: 執行中
```

---

## 方法二：App Intents（捷徑）

透過 macOS 捷徑 App 控制，支援回傳值，適合自動化流程。

### 啟動計時器

**Intent 名稱：** `Start Timer`

```bash
# 基本用法
shortcuts run "Start Timer" -i '{"seconds": 300, "label": "休息"}'

# 僅指定秒數
shortcuts run "Start Timer" -i '{"seconds": 60}'
```

**參數：**
| 參數 | 類型 | 必填 | 說明 |
|------|------|------|------|
| `seconds` | Int | ✅ | 計時秒數 |
| `label` | String | ❌ | 計時器名稱（預設：Timer） |

**回傳：** `已啟動 300 秒計時器「休息」`

### 控制番茄鐘

**Intent 名稱：** `Control Pomodoro`

```bash
# 啟動
shortcuts run "Control Pomodoro" -i '{"action": "start"}'

# 暫停
shortcuts run "Control Pomodoro" -i '{"action": "pause"}'

# 重置
shortcuts run "Control Pomodoro" -i '{"action": "reset"}'
```

**參數：**
| 參數 | 類型 | 必填 | 說明 |
|------|------|------|------|
| `action` | Enum | ✅ | `start`、`pause`、`reset` |

**回傳：** `番茄鐘已啟動` / `番茄鐘已暫停` / `番茄鐘已重置`

### Siri 語音指令

已註冊的 Siri 短語：

**計時器：**
- "Start timer in MacClock"
- "Set a timer with MacClock"
- "用 MacClock 設定計時器"

**番茄鐘：**
- "Start pomodoro in MacClock"
- "用 MacClock 開始番茄鐘"

---

## Python 整合範例

### 使用 URL Scheme

```python
import subprocess
from urllib.parse import quote

def start_timer(seconds: int, label: str = "Timer", command: str = None, repeat: bool = False):
    """啟動計時器"""
    url = f'macclock://timer?sec={seconds}&label={quote(label)}'
    if command:
        url += f'&command={quote(command)}'
    if repeat:
        url += '&repeat=true'
    subprocess.run(['open', url])

def cancel_timer(label: str = None, cancel_all: bool = False):
    """取消計時器"""
    if cancel_all:
        url = 'macclock://timer?action=cancel&all=true'
    elif label:
        url = f'macclock://timer?action=cancel&label={quote(label)}'
    else:
        url = 'macclock://timer?action=cancel'
    subprocess.run(['open', url])

def control_pomodoro(action: str):
    """控制番茄鐘 (start/pause/reset)"""
    url = f'macclock://pomodoro?action={action}'
    subprocess.run(['open', url])

# 使用範例
start_timer(300, "休息時間")
start_timer(60, "提醒", command="say 時間到")  # 計時結束說話
start_timer(5, "循環", command="say ok", repeat=True)  # 循環計時器
cancel_timer(cancel_all=True)  # 取消全部
control_pomodoro("start")
```

### 使用 Shortcuts（有回傳值）

```python
import subprocess
import json

def run_shortcut(name: str, input_data: dict) -> str:
    """執行捷徑並取得回傳值"""
    result = subprocess.run(
        ['shortcuts', 'run', name, '-i', json.dumps(input_data)],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()

def start_timer(seconds: int, label: str = "Timer") -> str:
    """啟動計時器"""
    return run_shortcut("Start Timer", {"seconds": seconds, "label": label})

def control_pomodoro(action: str) -> str:
    """控制番茄鐘"""
    return run_shortcut("Control Pomodoro", {"action": action})

# 使用範例
print(start_timer(300, "休息"))  # 輸出: 已啟動 300 秒計時器「休息」
print(control_pomodoro("start"))  # 輸出: 番茄鐘已啟動
```

---

## Claude/ChatGPT 工具定義

### OpenAI Function Calling 格式

```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "start_timer",
        "description": "在 MacClock 中啟動倒數計時器",
        "parameters": {
          "type": "object",
          "properties": {
            "seconds": {
              "type": "integer",
              "description": "計時秒數"
            },
            "label": {
              "type": "string",
              "description": "計時器名稱"
            },
            "command": {
              "type": "string",
              "description": "計時結束時執行的 shell 指令"
            },
            "repeat": {
              "type": "boolean",
              "description": "是否循環（自動重新開始）"
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
        "description": "取消 MacClock 計時器",
        "parameters": {
          "type": "object",
          "properties": {
            "label": {
              "type": "string",
              "description": "要取消的計時器名稱（不指定則取消最後一個）"
            },
            "all": {
              "type": "boolean",
              "description": "是否取消全部計時器"
            }
          }
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "control_pomodoro",
        "description": "控制 MacClock 的番茄鐘",
        "parameters": {
          "type": "object",
          "properties": {
            "action": {
              "type": "string",
              "enum": ["start", "pause", "reset"],
              "description": "動作類型"
            }
          },
          "required": ["action"]
        }
      }
    }
  ]
}
```

### Claude Tool Use 格式

```json
{
  "tools": [
    {
      "name": "start_timer",
      "description": "在 MacClock 中啟動倒數計時器",
      "input_schema": {
        "type": "object",
        "properties": {
          "seconds": {
            "type": "integer",
            "description": "計時秒數"
          },
          "label": {
            "type": "string",
            "description": "計時器名稱"
          },
          "command": {
            "type": "string",
            "description": "計時結束時執行的 shell 指令"
          },
          "repeat": {
            "type": "boolean",
            "description": "是否循環（自動重新開始）"
          }
        },
        "required": ["seconds"]
      }
    },
    {
      "name": "cancel_timer",
      "description": "取消 MacClock 計時器",
      "input_schema": {
        "type": "object",
        "properties": {
          "label": {
            "type": "string",
            "description": "要取消的計時器名稱（不指定則取消最後一個）"
          },
          "all": {
            "type": "boolean",
            "description": "是否取消全部計時器"
          }
        }
      }
    },
    {
      "name": "control_pomodoro",
      "description": "控制 MacClock 的番茄鐘",
      "input_schema": {
        "type": "object",
        "properties": {
          "action": {
            "type": "string",
            "enum": ["start", "pause", "reset"],
            "description": "動作類型"
          }
        },
        "required": ["action"]
      }
    }
  ]
}
```

---

## 注意事項

1. **App 必須在執行中**：URL Scheme 和 Shortcuts 都需要 MacClock 正在運行
2. **首次使用捷徑**：需先在「捷徑」App 中確認 MacClock 的 App Shortcuts 已被識別
3. **URL 編碼**：如果 label 或 command 包含特殊字元，需進行 URL 編碼（空格用 `%20`）
4. **沙盒限制**：MacClock 運行在 App Sandbox 中，某些操作可能受限
5. **自動顯示倒數計時**：透過 URL Scheme 或 Shortcuts 啟動計時器時，如果倒數計時小工具原本是隱藏的，會自動顯示在時鐘下方
6. **command 參數**：計時結束時執行的 shell 指令，例如 `say%20完成` 會說「完成」
7. **repeat 參數**：設為 `true` 時計時器會自動循環，直到手動取消

---

## 疑難排解

### URL Scheme 無效

1. 確認 App 已安裝並至少執行過一次
2. 重新註冊 URL Scheme：
   ```bash
   /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f /Applications/MacClock.app
   ```

### Shortcuts 找不到 Intent

1. 確認 MacClock 版本包含 App Intents
2. 重新啟動「捷徑」App
3. 在「捷徑」App 中搜尋 "MacClock" 或 "Timer"
