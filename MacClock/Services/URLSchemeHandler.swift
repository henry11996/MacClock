//
//  URLSchemeHandler.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import Foundation

@MainActor
struct URLSchemeHandler {

    /// 處理傳入的 URL
    /// - Returns: 執行結果訊息
    static func handle(_ url: URL) -> String {
        guard url.scheme == "macclock" else {
            return "錯誤：不支援的 scheme"
        }

        guard let host = url.host else {
            return "錯誤：缺少指令"
        }

        let params = parseQueryParams(url)

        switch host {
        case "timer":
            return handleTimer(params: params)
        case "pomodoro":
            return handlePomodoro(params: params)
        case "schedule":
            return handleSchedule(params: params)
        case "status":
            return handleStatus()
        default:
            return "錯誤：未知指令 '\(host)'"
        }
    }

    // MARK: - Timer Commands

    private static func handleTimer(params: [String: String]) -> String {
        let manager = CountdownManager.shared

        // 新增計時器: macclock://timer?action=add&sec=300&label=休息
        if params["action"] == "add" {
            guard let secStr = params["sec"], let seconds = TimeInterval(secStr), seconds > 0 else {
                return "錯誤：需要有效的 sec 參數"
            }

            // 檢查計時器上限
            guard manager.timers.count < CountdownManager.maxTimerCount else {
                return "錯誤：已達計時器上限 (\(CountdownManager.maxTimerCount))"
            }

            let label = params["label"] ?? "Timer"
            let autoStart = params["start"] == "true"
            let command = params["command"]
            let repeatEnabled = params["repeat"] == "true"
            let colorHex = parseColor(params["color"])

            manager.addTimer(label: label, duration: seconds, colorHex: colorHex, completionCommand: command, repeatEnabled: repeatEnabled)

            if autoStart, let timer = manager.timers.last {
                manager.start(id: timer.id)
                showCountdownIfHidden(manager)
                return "已新增並啟動計時器「\(label)」\(Int(seconds)) 秒"
            }
            return "已新增計時器「\(label)」\(Int(seconds)) 秒"
        }

        // 取消計時器: macclock://timer?action=cancel 或 &label=xxx 或 &all=true
        if params["action"] == "cancel" {
            if params["all"] == "true" {
                let count = manager.timers.count
                let ids = manager.timers.map { $0.id }
                for id in ids {
                    manager.removeTimer(id: id)
                }
                return count > 0 ? "已取消全部 \(count) 個計時器" : "沒有計時器可取消"
            }

            if let label = params["label"],
               let timer = manager.timers.first(where: { $0.label == label }) {
                manager.removeTimer(id: timer.id)
                return "已取消計時器「\(label)」"
            }

            // 預設取消最後一個
            if let timer = manager.timers.last {
                let label = timer.label
                manager.removeTimer(id: timer.id)
                return "已取消計時器「\(label)」"
            }

            return "沒有計時器可取消"
        }

        // 快速啟動: macclock://timer?sec=300
        if let secStr = params["sec"], let seconds = TimeInterval(secStr), seconds > 0 {
            // 檢查計時器上限
            guard manager.timers.count < CountdownManager.maxTimerCount else {
                return "錯誤：已達計時器上限 (\(CountdownManager.maxTimerCount))"
            }

            let label = params["label"] ?? "Quick Timer"
            let command = params["command"]
            let repeatEnabled = params["repeat"] == "true"
            let colorHex = parseColor(params["color"])
            manager.addTimer(label: label, duration: seconds, colorHex: colorHex, completionCommand: command, repeatEnabled: repeatEnabled)
            if let timer = manager.timers.last {
                manager.start(id: timer.id)
            }
            showCountdownIfHidden(manager)
            return "已啟動 \(Int(seconds)) 秒計時器"
        }

        return "錯誤：無效的 timer 指令"
    }

    /// 如果倒數計時目前是隱藏的，自動顯示在時鐘下方
    private static func showCountdownIfHidden(_ manager: CountdownManager) {
        if manager.settings.position == .hidden {
            manager.settings.position = .below
        }
    }

    // MARK: - Pomodoro Commands

    private static func handlePomodoro(params: [String: String]) -> String {
        let pomodoro = PomodoroTimer.shared

        guard let action = params["action"] else {
            return "錯誤：需要 action 參數 (start/pause/reset)"
        }

        switch action {
        case "start":
            pomodoro.start()
            return "番茄鐘已啟動"
        case "pause":
            pomodoro.pause()
            return "番茄鐘已暫停"
        case "reset":
            pomodoro.reset()
            return "番茄鐘已重置"
        default:
            return "錯誤：未知動作 '\(action)'"
        }
    }

    // MARK: - Schedule Commands

    private static func handleSchedule(params: [String: String]) -> String {
        let manager = ScheduleManager.shared

        guard let action = params["action"] else {
            return "錯誤：需要 action 參數 (add/list/toggle/remove)"
        }

        switch action {
        case "add":
            return addSchedule(params: params)

        case "list":
            if manager.schedules.isEmpty {
                return "目前沒有排程"
            }
            var result = "排程列表 (\(manager.schedules.count)):\n"
            for schedule in manager.schedules {
                let status = schedule.isEnabled ? "✓" : "✗"
                result += "[\(status)] \(schedule.formattedTime) \(schedule.label) (\(schedule.recurrence.displayName)) - ID: \(schedule.id.uuidString.prefix(8))\n"
            }
            return result

        case "toggle":
            if let idStr = params["id"],
               let id = UUID(uuidString: String(idStr.prefix(36))) ?? manager.schedules.first(where: { $0.id.uuidString.hasPrefix(idStr) })?.id {
                let wasEnabled = manager.schedules.first(where: { $0.id == id })?.isEnabled ?? false
                manager.toggleEnabled(id: id)
                return wasEnabled ? "已停用排程" : "已啟用排程"
            }
            // 如果沒有 ID，嘗試用 label 查找
            if let label = params["label"],
               let schedule = manager.schedules.first(where: { $0.label == label }) {
                let wasEnabled = schedule.isEnabled
                manager.toggleEnabled(id: schedule.id)
                return wasEnabled ? "已停用排程「\(label)」" : "已啟用排程「\(label)」"
            }
            return "錯誤：找不到指定的排程"

        case "remove":
            if let idStr = params["id"],
               let id = UUID(uuidString: String(idStr.prefix(36))) ?? manager.schedules.first(where: { $0.id.uuidString.hasPrefix(idStr) })?.id {
                manager.removeSchedule(id: id)
                return "已移除排程"
            }
            if let label = params["label"],
               let schedule = manager.schedules.first(where: { $0.label == label }) {
                manager.removeSchedule(id: schedule.id)
                return "已移除排程「\(label)」"
            }
            return "錯誤：找不到指定的排程"

        default:
            return "錯誤：未知動作 '\(action)'"
        }
    }

    /// 新增排程
    private static func addSchedule(params: [String: String]) -> String {
        let manager = ScheduleManager.shared

        guard manager.schedules.count < ScheduleManager.maxScheduleCount else {
            return "錯誤：已達排程上限 (\(ScheduleManager.maxScheduleCount))"
        }

        // 解析時間 (必填)
        guard let timeStr = params["time"] else {
            return "錯誤：需要 time 參數 (格式: HH:MM)"
        }
        let timeParts = timeStr.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]),
              hour >= 0, hour < 24, minute >= 0, minute < 60 else {
            return "錯誤：無效的時間格式 (需要 HH:MM)"
        }

        var time = DateComponents()
        time.hour = hour
        time.minute = minute

        // 解析動作 (必填)
        guard let doAction = params["do"] else {
            return "錯誤：需要 do 參數 (pomodoro/timer/command/notify)"
        }

        let action: ScheduleAction
        switch doAction {
        case "pomodoro":
            action = .startPomodoro

        case "timer":
            let duration = TimeInterval(params["sec"] ?? "300") ?? 300
            let label = params["label"] ?? "計時器"
            action = .startTimer(duration: duration, label: label)

        case "command":
            guard let cmd = params["cmd"], !cmd.isEmpty else {
                return "錯誤：command 動作需要 cmd 參數"
            }
            action = .runCommand(command: cmd)

        case "notify":
            let title = params["title"] ?? "提醒"
            let message = params["msg"] ?? ""
            action = .notification(title: title, message: message)

        default:
            return "錯誤：未知動作類型 '\(doAction)'"
        }

        // 解析重複規則 (選填，預設單次)
        let recurrence: RecurrenceRule
        if let repeatStr = params["repeat"] {
            switch repeatStr {
            case "daily":
                recurrence = .daily
            case "weekday":
                recurrence = .weekly(weekdays: Set([1, 2, 3, 4, 5]))
            case "weekend":
                recurrence = .weekly(weekdays: Set([6, 7]))
            default:
                // 嘗試解析為間隔小時數
                if let hours = Int(repeatStr), hours > 0 {
                    recurrence = .interval(hours: hours)
                } else {
                    recurrence = .none
                }
            }
        } else {
            recurrence = .none
        }

        // 解析標籤 (選填)
        let label = params["name"] ?? params["label"] ?? "排程"

        let schedule = Schedule(
            label: label,
            action: action,
            time: time,
            recurrence: recurrence
        )

        manager.addSchedule(schedule)

        // 自動顯示排程 widget（如果目前是隱藏的）
        if manager.settings.position == .hidden {
            manager.settings.position = .below
        }

        return "已新增排程「\(label)」於 \(timeStr)"
    }

    // MARK: - Status Query

    private static func handleStatus() -> String {
        let manager = CountdownManager.shared
        let pomodoro = PomodoroTimer.shared
        let scheduleManager = ScheduleManager.shared

        var status = "MacClock 狀態:\n"
        status += "- 計時器數量: \(manager.timers.count)\n"
        status += "- 執行中計時器: \(manager.timers.filter { $0.timerState == .running }.count)\n"
        status += "- 番茄鐘狀態: \(pomodoro.timerState == .running ? "執行中" : "停止")\n"
        status += "- 排程數量: \(scheduleManager.schedules.count) (啟用: \(scheduleManager.schedules.filter { $0.isEnabled }.count))"

        return status
    }

    // MARK: - Helpers

    private static func parseQueryParams(_ url: URL) -> [String: String] {
        var params: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                // 確保 URL 解碼
                let value = item.value?.removingPercentEncoding ?? item.value
                params[item.name] = value
            }
        }
        return params
    }

    /// Parse color parameter - supports color names or hex values
    private static func parseColor(_ colorStr: String?) -> UInt {
        guard let colorStr = colorStr?.lowercased() else {
            return CountdownColors.blue
        }

        // Support color names
        switch colorStr {
        case "blue", "藍", "藍色":
            return CountdownColors.blue
        case "red", "紅", "紅色":
            return CountdownColors.red
        case "green", "綠", "綠色":
            return CountdownColors.green
        case "purple", "紫", "紫色":
            return CountdownColors.purple
        case "orange", "橙", "橙色":
            return CountdownColors.orange
        case "pink", "粉", "粉色":
            return CountdownColors.pink
        case "cyan", "青", "青色":
            return CountdownColors.cyan
        case "yellow", "黃", "黃色":
            return CountdownColors.yellow
        default:
            // Try parsing as hex (e.g., "3B82F6" or "0x3B82F6")
            let hexStr = colorStr.hasPrefix("0x") ? String(colorStr.dropFirst(2)) : colorStr
            if let hex = UInt(hexStr, radix: 16) {
                return hex
            }
            return CountdownColors.blue
        }
    }
}
