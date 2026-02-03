//
//  PomodoroTimer.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import Combine
import Foundation
import SwiftUI

/// Observable timer class that manages Pomodoro timing logic
@MainActor
@Observable
final class PomodoroTimer {
    // MARK: - Singleton
    static let shared = PomodoroTimer()

    // MARK: - Published State
    private(set) var phase: PomodoroPhase = .work
    private(set) var timerState: TimerState = .idle
    private(set) var completedPomodoros: Int = 0
    private(set) var remainingSeconds: TimeInterval = 25 * 60
    private(set) var totalFocusTime: TimeInterval = 0

    // MARK: - Settings
    var settings: PomodoroSettings = .default {
        didSet {
            settings.save()
            if timerState == .idle {
                remainingSeconds = settings.duration(for: phase)
            }
        }
    }

    // MARK: - Private
    private var targetEndTime: Date?
    private var focusStartTime: Date?
    private var timer: AnyCancellable?
    private var sessionState: PomodoroSessionState = .initial

    // MARK: - Computed Properties

    var progress: Double {
        let total = settings.duration(for: phase)
        guard total > 0 else { return 0 }
        return 1.0 - (remainingSeconds / total)
    }

    var formattedTime: String {
        let minutes = Int(remainingSeconds) / 60
        let seconds = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedFocusTime: String {
        let hours = Int(totalFocusTime) / 3600
        let minutes = (Int(totalFocusTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Initialization

    private init() {
        loadState()
        startTimerLoop()
    }

    // MARK: - Public Methods

    /// Start or resume the timer
    func start() {
        guard timerState != .running else { return }

        if timerState == .paused, let remaining = sessionState.remainingSecondsWhenPaused {
            targetEndTime = Date().addingTimeInterval(remaining)
        } else {
            targetEndTime = Date().addingTimeInterval(remainingSeconds)
        }

        if phase == .work {
            focusStartTime = Date()
        }

        timerState = .running
        saveState()
    }

    /// Pause the timer
    func pause() {
        guard timerState == .running else { return }

        // Save remaining time when paused
        sessionState.remainingSecondsWhenPaused = remainingSeconds

        // Add focus time if in work phase
        if phase == .work, let startTime = focusStartTime {
            totalFocusTime += Date().timeIntervalSince(startTime)
            focusStartTime = nil
        }

        timerState = .paused
        targetEndTime = nil
        saveState()
    }

    /// Toggle between start and pause
    func toggleStartPause() {
        if timerState == .running {
            pause()
        } else {
            start()
        }
    }

    /// Skip to the next phase
    func skip() {
        // Add any accumulated focus time
        if phase == .work, timerState == .running, let startTime = focusStartTime {
            totalFocusTime += Date().timeIntervalSince(startTime)
            focusStartTime = nil
        }

        advanceToNextPhase()
    }

    /// Reset the current phase timer
    func reset() {
        pause()
        remainingSeconds = settings.duration(for: phase)
        sessionState.remainingSecondsWhenPaused = nil
        timerState = .idle
        saveState()
    }

    /// Reset all progress (pomodoros, focus time)
    func resetAll() {
        pause()
        phase = .work
        completedPomodoros = 0
        totalFocusTime = 0
        remainingSeconds = settings.duration(for: phase)
        sessionState.remainingSecondsWhenPaused = nil
        timerState = .idle
        saveState()
    }

    /// Update completed pomodoros count (for manual editing)
    func setCompletedPomodoros(_ count: Int) {
        completedPomodoros = max(0, count)
        saveState()
    }

    // MARK: - Private Methods

    private func startTimerLoop() {
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
    }

    private func tick() {
        guard timerState == .running, let endTime = targetEndTime else { return }

        let remaining = endTime.timeIntervalSinceNow

        if remaining <= 0 {
            // Timer completed
            handlePhaseComplete()
        } else {
            remainingSeconds = remaining
        }
    }

    private func handlePhaseComplete() {
        // Add focus time for completed work session
        if phase == .work {
            if let startTime = focusStartTime {
                totalFocusTime += Date().timeIntervalSince(startTime)
            }
            focusStartTime = nil
            completedPomodoros += 1
        }

        // Determine next phase
        let nextPhase = determineNextPhase()

        // Play sound and send notification
        if settings.soundEnabled {
            NotificationService.shared.playCompletionSound(volume: settings.soundVolume)
        }
        NotificationService.shared.sendPhaseCompleteNotification(phase: phase, nextPhase: nextPhase)

        // Advance to next phase
        phase = nextPhase
        remainingSeconds = settings.duration(for: phase)
        targetEndTime = nil
        sessionState.remainingSecondsWhenPaused = nil

        // Auto-start if enabled
        if (phase == .work && settings.autoStartWork) ||
            (phase != .work && settings.autoStartBreaks) {
            start()
        } else {
            timerState = .idle
        }

        saveState()
    }

    private func determineNextPhase() -> PomodoroPhase {
        switch phase {
        case .work:
            // After completing required pomodoros, take long break
            if completedPomodoros > 0 && completedPomodoros % settings.pomodorosUntilLongBreak == 0 {
                return .longBreak
            }
            return .shortBreak
        case .shortBreak, .longBreak:
            return .work
        }
    }

    private func advanceToNextPhase() {
        if phase == .work {
            completedPomodoros += 1
        }

        phase = determineNextPhase()
        remainingSeconds = settings.duration(for: phase)
        targetEndTime = nil
        sessionState.remainingSecondsWhenPaused = nil
        timerState = .idle
        saveState()
    }

    // MARK: - Persistence

    private func loadState() {
        settings = .load()
        sessionState = .load()

        phase = sessionState.phase
        completedPomodoros = sessionState.completedPomodoros
        totalFocusTime = sessionState.totalFocusTime

        // Handle running state restoration
        if sessionState.timerState == .running, let endTime = sessionState.targetEndTime {
            let remaining = endTime.timeIntervalSinceNow
            if remaining > 0 {
                // Timer was still running
                remainingSeconds = remaining
                targetEndTime = endTime
                timerState = .running
                if phase == .work {
                    focusStartTime = Date()
                }
            } else {
                // Timer expired while app was closed
                handlePhaseComplete()
            }
        } else if sessionState.timerState == .paused,
                  let remaining = sessionState.remainingSecondsWhenPaused {
            remainingSeconds = remaining
            timerState = .paused
        } else {
            remainingSeconds = settings.duration(for: phase)
            timerState = .idle
        }
    }

    private func saveState() {
        sessionState = PomodoroSessionState(
            phase: phase,
            timerState: timerState,
            completedPomodoros: completedPomodoros,
            targetEndTime: targetEndTime,
            remainingSecondsWhenPaused: timerState == .paused ? remainingSeconds : nil,
            totalFocusTime: totalFocusTime
        )
        sessionState.save()
    }
}
