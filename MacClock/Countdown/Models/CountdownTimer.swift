//
//  CountdownTimer.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import Foundation

/// Single countdown timer data model
struct CountdownTimer: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    var duration: TimeInterval
    var colorHex: UInt
    var soundEnabled: Bool
    var completionCommand: String?
    var repeatEnabled: Bool

    // Runtime state (for persistence)
    var timerState: TimerState
    var targetEndTime: Date?
    var remainingSecondsWhenPaused: TimeInterval?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        duration: TimeInterval,
        colorHex: UInt = CountdownColors.blue,
        soundEnabled: Bool = true,
        completionCommand: String? = nil,
        repeatEnabled: Bool = false,
        timerState: TimerState = .idle,
        targetEndTime: Date? = nil,
        remainingSecondsWhenPaused: TimeInterval? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.duration = duration
        self.colorHex = colorHex
        self.soundEnabled = soundEnabled
        self.completionCommand = completionCommand
        self.repeatEnabled = repeatEnabled
        self.timerState = timerState
        self.targetEndTime = targetEndTime
        self.remainingSecondsWhenPaused = remainingSecondsWhenPaused
        self.createdAt = createdAt
    }

    /// Calculate current remaining seconds based on state
    func currentRemainingSeconds() -> TimeInterval {
        switch timerState {
        case .idle:
            return duration
        case .paused:
            return remainingSecondsWhenPaused ?? duration
        case .running:
            guard let endTime = targetEndTime else { return duration }
            return max(0, endTime.timeIntervalSinceNow)
        }
    }

    /// Progress value (0.0 to 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return 1.0 - (currentRemainingSeconds() / duration)
    }

    /// Formatted time string (MM:SS or HH:MM:SS)
    var formattedTime: String {
        let remaining = currentRemainingSeconds()
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Preset colors for countdown timers
enum CountdownColors {
    static let blue: UInt = 0x3B82F6
    static let red: UInt = 0xEF4444
    static let green: UInt = 0x22C55E
    static let purple: UInt = 0x8B5CF6
    static let orange: UInt = 0xF97316
    static let pink: UInt = 0xEC4899
    static let cyan: UInt = 0x06B6D4
    static let yellow: UInt = 0xEAB308

    static let all: [UInt] = [blue, red, green, purple, orange, pink, cyan, yellow]

    static func name(for hex: UInt) -> String {
        switch hex {
        case blue: return "藍色"
        case red: return "紅色"
        case green: return "綠色"
        case purple: return "紫色"
        case orange: return "橙色"
        case pink: return "粉色"
        case cyan: return "青色"
        case yellow: return "黃色"
        default: return "自訂"
        }
    }
}
