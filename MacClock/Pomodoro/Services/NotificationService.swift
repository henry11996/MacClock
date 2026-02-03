//
//  NotificationService.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import AppKit
import UserNotifications

/// Handles sound playback and system notifications for the Pomodoro timer
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    /// Check if notifications are available (requires bundle identifier)
    private var canUseNotifications: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private init() {
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        guard canUseNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
        }
    }

    /// Play completion sound
    func playCompletionSound(volume: Float) {
        // Use system sound "Glass" for timer completion
        if let sound = NSSound(named: "Glass") {
            sound.volume = volume
            sound.play()
        }
    }

    /// Send a notification when phase completes
    func sendPhaseCompleteNotification(phase: PomodoroPhase, nextPhase: PomodoroPhase) {
        guard canUseNotifications else { return }

        let content = UNMutableNotificationContent()

        switch phase {
        case .work:
            content.title = "番茄鐘完成！"
            content.body = nextPhase == .longBreak ? "辛苦了！休息一下吧（長休息）" : "辛苦了！休息一下吧"
        case .shortBreak, .longBreak:
            content.title = "休息結束"
            content.body = "準備開始下一個番茄鐘！"
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
