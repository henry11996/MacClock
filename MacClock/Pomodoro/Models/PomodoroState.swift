//
//  PomodoroState.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import Foundation

/// Represents the current phase of the Pomodoro timer
enum PomodoroPhase: String, Codable {
    case work = "work"
    case shortBreak = "shortBreak"
    case longBreak = "longBreak"

    var displayName: String {
        switch self {
        case .work: return "工作中"
        case .shortBreak: return "短休息"
        case .longBreak: return "長休息"
        }
    }

    var displayNameEnglish: String {
        switch self {
        case .work: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }
}

/// Represents the running state of the timer
enum TimerState: String, Codable {
    case idle = "idle"
    case running = "running"
    case paused = "paused"
}

/// Persistent state for the Pomodoro timer
struct PomodoroSessionState: Codable {
    var phase: PomodoroPhase
    var timerState: TimerState
    var completedPomodoros: Int
    var targetEndTime: Date?
    var remainingSecondsWhenPaused: TimeInterval?
    var totalFocusTime: TimeInterval

    static var initial: PomodoroSessionState {
        PomodoroSessionState(
            phase: .work,
            timerState: .idle,
            completedPomodoros: 0,
            targetEndTime: nil,
            remainingSecondsWhenPaused: nil,
            totalFocusTime: 0
        )
    }
}
