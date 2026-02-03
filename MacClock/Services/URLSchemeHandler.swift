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

            manager.addTimer(label: label, duration: seconds, completionCommand: command, repeatEnabled: repeatEnabled)

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
            manager.addTimer(label: label, duration: seconds, completionCommand: command, repeatEnabled: repeatEnabled)
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

    // MARK: - Status Query

    private static func handleStatus() -> String {
        let manager = CountdownManager.shared
        let pomodoro = PomodoroTimer.shared

        var status = "MacClock 狀態:\n"
        status += "- 計時器數量: \(manager.timers.count)\n"
        status += "- 執行中計時器: \(manager.timers.filter { $0.timerState == .running }.count)\n"
        status += "- 番茄鐘狀態: \(pomodoro.timerState == .running ? "執行中" : "停止")"

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
}
