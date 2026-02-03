//
//  StartTimerIntent.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import AppIntents

struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Timer"
    static let description = IntentDescription("Start a countdown timer in MacClock")

    @Parameter(title: "Duration (seconds)")
    var seconds: Int

    @Parameter(title: "Label", default: "Timer")
    var label: String

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$seconds) second timer named \(\.$label)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let manager = CountdownManager.shared

        // 檢查計時器上限
        guard manager.timers.count < CountdownManager.maxTimerCount else {
            return .result(value: "錯誤：已達計時器上限 (\(CountdownManager.maxTimerCount))")
        }

        manager.addTimer(label: label, duration: TimeInterval(seconds))

        if let timer = manager.timers.last {
            manager.start(id: timer.id)
        }

        // 如果倒數計時目前是隱藏的，自動顯示
        if manager.settings.position == .hidden {
            manager.settings.position = .below
        }

        return .result(value: "已啟動 \(seconds) 秒計時器「\(label)」")
    }
}
