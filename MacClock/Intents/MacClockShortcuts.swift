//
//  MacClockShortcuts.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import AppIntents

struct MacClockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTimerIntent(),
            phrases: [
                "Start timer in \(.applicationName)",
                "Set a timer with \(.applicationName)",
                "用 \(.applicationName) 設定計時器"
            ],
            shortTitle: "Start Timer",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: PomodoroIntent(),
            phrases: [
                "Start pomodoro in \(.applicationName)",
                "用 \(.applicationName) 開始番茄鐘"
            ],
            shortTitle: "Pomodoro",
            systemImageName: "clock.badge.checkmark"
        )
    }
}
