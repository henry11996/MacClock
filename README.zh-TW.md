# MacClock

簡潔優雅的 macOS 浮動時鐘、計時器與螢幕文字擷取工具。

![macOS](https://img.shields.io/badge/macOS-26.0%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
[![Release](https://img.shields.io/github/v/release/henry11996/MacClock)](https://github.com/henry11996/MacClock/releases/latest)

[English](README.md) | **繁體中文**

## 下載

### [⬇️ 下載最新版本](https://github.com/henry11996/MacClock/releases/latest)

1. 下載 `MacClock.dmg`
2. 打開 DMG 檔案
3. 將 MacClock 拖曳至 Applications 資料夾
4. 從 Applications 或 Launchpad 開啟 MacClock

> MacClock 已通過 Apple 簽署與公證。若首次開啟仍被阻擋，請至「系統設定 → 隱私權與安全性」點擊「強制打開」。

## 功能

- **浮動時鐘**：置頂顯示的時鐘小工具，支援多種顯示樣式
- **螢幕文字辨識（OCR）**：框選螢幕任意區域，立即複製其中文字（類似 TextSniper / Capture2Text）
- **截圖晾衣繩**：新截圖會掛在瀏海下方的繩子上，滑鼠停在瀏海就會降下
- **倒數計時器**：支援多個計時器同時運行
- **番茄鐘**：工作／休息循環，可選全螢幕休息提醒
- **排程**：在指定時間自動執行動作，支援每天、平日或間隔重複
- **瀏海模式**：在 MacBook 瀏海兩側顯示時鐘與計時器
- **Liquid Glass 效果**：搭配 macOS Tahoe 的玻璃質感外觀
- **Shell 指令**：計時結束時執行指令
- **AI 整合**：URL Scheme 支援 AI 代理自動化
- **Siri 與捷徑**：完整 App Intents 支援

## 螢幕文字辨識（OCR）

按下 **⇧⌘2**，框選畫面上的文字，辨識結果就會複製到剪貼簿。

- 使用 Apple 內建 **Vision** 框架，**完全在本機處理**，截圖不會上傳或儲存
- 支援繁體中文、簡體中文、英文、日文、韓文，或自動偵測語言
- 依閱讀順序排版，中文之間不多加空白，英文跨行斷字會自動合併
- 支援多螢幕與 Retina，擷取時自動排除 MacClock 自己的視窗
- 可自訂快捷鍵、語言、精準／快速模式、保留換行、遮罩深淺、提示與音效
- 也可用 `macclock://ocr` 或捷徑／Siri 觸發

> 首次使用需在「系統設定 → 隱私權與安全性 → 螢幕與系統錄音」允許 MacClock，並重新啟動 App。

## 截圖晾衣繩

靈感來自 [Tendedero](https://github.com/alejandrobujan/tendedero)（MIT）。

- 在「設定 → 晾衣繩」選一次截圖資料夾，選擇視窗會自動帶入系統截圖位置。
- 照常用 ⌘⇧3/4/5 截圖，新截圖就會掛在瀏海下方的繩子上。
- 滑鼠停在瀏海會降下繩子：**點一下**複製、**點兩下**用預覽程式打開、**拖曳**到任何 App 或資料夾，滑過後按 **✕** 從繩子拿下。拿下不會刪除你的檔案。
- 用 OCR 框選的畫面也可以掛上去。
- MacClock 只讀取你選的資料夾，維持沙盒保護。

## 安裝

### 方式一：下載安裝（推薦）

從 [Releases](https://github.com/henry11996/MacClock/releases/latest) 下載最新版本 DMG。

### 方式二：從原始碼建置

```bash
git clone https://github.com/henry11996/MacClock.git
cd MacClock
open MacClock.xcodeproj
# 在 Xcode 中按 Cmd+R 執行
```

執行測試：

```bash
swift test
```

## 快速開始

### URL Scheme

```bash
# 設定 5 分鐘計時器
open "macclock://timer?sec=300&label=Break"

# 開始番茄鐘
open "macclock://pomodoro?action=start"

# 計時結束時執行指令
open "macclock://timer?sec=60&command=say%20Done"

# 擷取螢幕區域文字
open "macclock://ocr"

# 每天早上 9:00 自動開始番茄鐘
open "macclock://schedule?action=add&time=09:00&do=pomodoro&repeat=daily&name=開始工作"

# 平日晚上 6:00 提醒
open "macclock://schedule?action=add&time=18:00&do=notify&title=下班提醒&msg=該下班了&repeat=weekday"
```

### AI Agent Skill

為 Claude Code 安裝 [MacClock Agent Skill](https://github.com/henry11996/macclock)：

```bash
npx skills add henry11996/macclock
```

接著對 AI 說：「設定 5 分鐘計時器」或「開始番茄鐘」。

## 文件

- [AI 整合指南](docs/AI-Integration.md)：完整 API 文件

## 系統需求

- macOS 26.0+（Tahoe）

## 授權

MIT License
