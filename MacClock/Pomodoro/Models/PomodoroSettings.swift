//
//  PomodoroSettings.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import Foundation

/// Display position for the Pomodoro timer relative to the clock
enum PomodoroPosition: String, Codable {
    case hidden  // 隱藏
    case above   // 時鐘上方
    case below   // 時鐘下方
}

/// Clock display style options
enum ClockStyle: String, Codable, CaseIterable {
    case standard       // 時間 + 星期 + 日期 (預設)
    case withSeconds    // 時間含秒數 + 星期 + 日期
    case timeOnly       // 僅時間
    case timeWithSeconds // 僅時間含秒數
    case compact        // 時間 + 短日期

    var displayName: String {
        switch self {
        case .standard: return "標準"
        case .withSeconds: return "含秒數"
        case .timeOnly: return "僅時間"
        case .timeWithSeconds: return "時間+秒"
        case .compact: return "精簡"
        }
    }

    var description: String {
        switch self {
        case .standard: return "12:34 週一 1月1日"
        case .withSeconds: return "12:34:56 週一 1月1日"
        case .timeOnly: return "12:34"
        case .timeWithSeconds: return "12:34:56"
        case .compact: return "12:34 1/1"
        }
    }
}

/// Background update FPS options for Liquid Glass effect
enum BackgroundUpdateFPS: Int, Codable, CaseIterable {
    case disabled = 0
    case fps1 = 1
    case fps24 = 24
    case fps48 = 48
    case fps60 = 60

    var displayName: String {
        switch self {
        case .disabled: return "關閉"
        case .fps1: return "1"
        case .fps24: return "24"
        case .fps48: return "48"
        case .fps60: return "60"
        }
    }

    var timerInterval: TimeInterval? {
        guard self != .disabled else { return nil }
        return 1.0 / Double(rawValue)
    }
}

/// User-configurable settings for the Pomodoro timer
struct PomodoroSettings: Codable {
    var workDuration: TimeInterval  // in seconds
    var shortBreakDuration: TimeInterval
    var longBreakDuration: TimeInterval
    var pomodorosUntilLongBreak: Int
    var soundEnabled: Bool
    var soundVolume: Float  // 0.0 - 1.0
    var autoStartBreaks: Bool
    var autoStartWork: Bool
    var fontScale: CGFloat  // 0.8 ~ 5.0 (番茄鐘)
    var clockFontScale: CGFloat  // 0.8 ~ 5.0 (時鐘)
    var clockStyle: ClockStyle  // 時鐘樣式
    var pomodoroPosition: PomodoroPosition
    var liquidGlassEnabled: Bool  // Liquid Glass 效果開關
    var backgroundUpdateFPS: BackgroundUpdateFPS  // 背景更新 FPS

    static var `default`: PomodoroSettings {
        PomodoroSettings(
            workDuration: 25 * 60,  // 25 minutes
            shortBreakDuration: 5 * 60,  // 5 minutes
            longBreakDuration: 15 * 60,  // 15 minutes
            pomodorosUntilLongBreak: 4,
            soundEnabled: true,
            soundVolume: 0.7,
            autoStartBreaks: false,
            autoStartWork: false,
            fontScale: 1.0,
            clockFontScale: 1.0,
            clockStyle: .standard,
            pomodoroPosition: .hidden,
            liquidGlassEnabled: false,
            backgroundUpdateFPS: .disabled
        )
    }

    /// Get duration for the given phase
    func duration(for phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .work: return workDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }
}

// MARK: - UserDefaults persistence
extension PomodoroSettings {
    private static let settingsKey = "pomodoroSettings"

    static func load() -> PomodoroSettings {
        guard let data = UserDefaults.standard.data(forKey: Self.settingsKey),
            let settings = try? JSONDecoder().decode(PomodoroSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }
}

extension PomodoroSessionState {
    private static let stateKey = "pomodoroSessionState"

    static func load() -> PomodoroSessionState {
        guard let data = UserDefaults.standard.data(forKey: Self.stateKey),
            let state = try? JSONDecoder().decode(PomodoroSessionState.self, from: data)
        else {
            return .initial
        }
        return state
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.stateKey)
        }
    }
}
