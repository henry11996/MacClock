//
//  CountdownManager.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import AppKit
import Combine
import Foundation
import SwiftUI
import UserNotifications

/// Observable manager that handles all countdown timers
@MainActor
@Observable
final class CountdownManager {
    // MARK: - Singleton
    static let shared = CountdownManager()

    // MARK: - Constants
    static let maxTimerCount = 15

    // MARK: - Published State
    private(set) var timers: [CountdownTimer] = []

    // Tick counter to trigger view updates
    private(set) var tickCount: UInt64 = 0

    // Recently completed timer ID for completion animation
    private(set) var recentlyCompletedTimerId: UUID? = nil

    // Auto-expand state for auto-collapse mode
    private(set) var isAutoExpanded: Bool = false

    // MARK: - Settings
    var settings: CountdownSettings = .default {
        didSet {
            settings.save()
        }
    }

    // MARK: - Private
    private var tickTimer: AnyCancellable?
    private var autoCollapseTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Timers visible based on settings
    var visibleTimers: [CountdownTimer] {
        Array(timers.prefix(settings.maxVisibleTimers))
    }

    /// Number of additional timers not visible
    var hiddenCount: Int {
        max(0, timers.count - settings.maxVisibleTimers)
    }

    /// Check if any timer is running
    var hasRunningTimers: Bool {
        timers.contains { $0.timerState == .running }
    }

    /// Update auto-expand state: expand when any timer is running, collapse when none are
    private func updateAutoExpandState() {
        guard settings.autoCollapseEnabled else { return }
        if hasRunningTimers {
            if !isAutoExpanded {
                isAutoExpanded = true
                autoCollapseTask?.cancel()
            }
        } else if isAutoExpanded {
            // No running timers — collapse after 30 seconds
            autoCollapseTask?.cancel()
            autoCollapseTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                if !self.hasRunningTimers {
                    self.isAutoExpanded = false
                }
            }
        }
    }

    // MARK: - Initialization

    private init() {
        loadState()
        startTimerLoop()
    }

    // MARK: - Public Methods

    /// Add a new countdown timer
    /// - Returns: true if timer was added, false if limit reached
    @discardableResult
    func addTimer(label: String, duration: TimeInterval, colorHex: UInt = CountdownColors.blue, soundEnabled: Bool = true, completionCommand: String? = nil, repeatEnabled: Bool = false) -> Bool {
        guard timers.count < Self.maxTimerCount else { return false }

        let timer = CountdownTimer(
            label: label,
            duration: duration,
            colorHex: colorHex,
            soundEnabled: soundEnabled,
            completionCommand: completionCommand,
            repeatEnabled: repeatEnabled
        )
        timers.append(timer)
        saveState()
        return true
    }

    /// Remove a timer by ID
    func removeTimer(id: UUID) {
        timers.removeAll { $0.id == id }
        saveState()
        updateAutoExpandState()
    }

    /// Update an existing timer's properties
    func updateTimer(id: UUID, label: String, duration: TimeInterval, colorHex: UInt, completionCommand: String?) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }

        var timer = timers[index]
        timer.label = label
        timer.duration = duration
        timer.colorHex = colorHex
        timer.completionCommand = completionCommand

        timers[index] = timer
        saveState()
    }

    /// Start a timer
    func start(id: UUID) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        guard timers[index].timerState != .running else { return }

        var timer = timers[index]

        if timer.timerState == .paused, let remaining = timer.remainingSecondsWhenPaused {
            timer.targetEndTime = Date().addingTimeInterval(remaining)
        } else {
            timer.targetEndTime = Date().addingTimeInterval(timer.duration)
        }

        timer.timerState = .running
        timer.remainingSecondsWhenPaused = nil
        timers[index] = timer
        saveState()
        updateAutoExpandState()
    }

    /// Pause a timer
    func pause(id: UUID) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        guard timers[index].timerState == .running else { return }

        var timer = timers[index]
        timer.remainingSecondsWhenPaused = timer.currentRemainingSeconds()
        timer.timerState = .paused
        timer.targetEndTime = nil
        timers[index] = timer
        saveState()
        updateAutoExpandState()
    }

    /// Toggle start/pause
    func toggleStartPause(id: UUID) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }

        if timers[index].timerState == .running {
            pause(id: id)
        } else {
            start(id: id)
        }
    }

    /// Reset a timer to initial duration
    func reset(id: UUID) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }

        var timer = timers[index]
        timer.timerState = .idle
        timer.targetEndTime = nil
        timer.remainingSecondsWhenPaused = nil
        timers[index] = timer
        saveState()
        updateAutoExpandState()
    }

    /// Add time to a timer
    func addTime(id: UUID, seconds: TimeInterval) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }

        var timer = timers[index]

        switch timer.timerState {
        case .running:
            if let endTime = timer.targetEndTime {
                timer.targetEndTime = endTime.addingTimeInterval(seconds)
            }
        case .paused:
            if let remaining = timer.remainingSecondsWhenPaused {
                timer.remainingSecondsWhenPaused = remaining + seconds
            }
        case .idle:
            timer.duration += seconds
        }

        timers[index] = timer
        saveState()
    }

    // MARK: - Private Methods

    private func startTimerLoop() {
        tickTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
    }

    private func tick() {
        // Check if any timer is running
        let hasRunning = timers.contains { $0.timerState == .running }

        if hasRunning {
            // Increment tick count to trigger view updates
            tickCount &+= 1
        }

        var needsSave = false

        for index in timers.indices {
            guard timers[index].timerState == .running,
                  let endTime = timers[index].targetEndTime else { continue }

            let remaining = endTime.timeIntervalSinceNow

            if remaining <= 0 {
                handleTimerComplete(index: index)
                needsSave = true
            }
        }

        if needsSave {
            saveState()
        }
    }

    private func handleTimerComplete(index: Int) {
        var timer = timers[index]
        let timerId = timer.id

        // Set recently completed for animation
        recentlyCompletedTimerId = timerId

        // Clear after 2 seconds
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if self.recentlyCompletedTimerId == timerId {
                self.recentlyCompletedTimerId = nil
            }
        }

        // Auto-expand widget if auto-collapse mode is enabled
        if settings.autoCollapseEnabled {
            isAutoExpanded = true
            autoCollapseTask?.cancel()
            autoCollapseTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                // Only collapse if no timers are still running
                if !self.hasRunningTimers {
                    self.isAutoExpanded = false
                }
            }
        }

        // Play sound if enabled (using configured sound source from settings)
        if timer.soundEnabled {
            playCompletionSound()
        }

        // Execute completion command if set
        if let command = timer.completionCommand, !command.isEmpty {
            executeCommand(command)
        }

        // Send notification
        sendTimerCompleteNotification(label: timer.label)

        // Handle repeat or reset
        if timer.repeatEnabled {
            // Restart timer for repeat
            timer.targetEndTime = Date().addingTimeInterval(timer.duration)
            timer.timerState = .running
        } else {
            // Reset timer state
            timer.timerState = .idle
            timer.targetEndTime = nil
        }
        timer.remainingSecondsWhenPaused = nil
        timers[index] = timer
    }

    /// Play a system sound with specified volume
    func playSound(name: String, volume: Float) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = volume
            sound.play()
        }
    }

    /// 根據設定播放完成音效
    func playCompletionSound() {
        let source = settings.effectiveSoundSource
        let volume = settings.soundVolume

        switch source {
        case .system(let sound):
            playSound(name: sound.rawValue, volume: volume)

        case .tts(let alarm):
            let message = settings.customTTSMessage?.isEmpty == false
                ? settings.customTTSMessage!
                : alarm.message
            playTTS(message: message, voice: settings.ttsVoice.voiceIdentifier, rate: settings.ttsRate)

        case .custom(let bookmarkData, _):
            playCustomSound(bookmarkData: bookmarkData, volume: volume)
        }
    }

    /// 播放 TTS 語音
    func playTTS(message: String, voice: String?, rate: Int) {
        Task.detached {
            var args = [message]
            if let voice = voice, !voice.isEmpty {
                args += ["-v", voice]
            }
            args += ["-r", String(rate)]

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            process.arguments = args
            try? process.run()
        }
    }

    /// 播放自訂音效檔案
    func playCustomSound(bookmarkData: Data, volume: Float) {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            // 無法解析 bookmark，播放系統預設音效
            playSound(name: SystemSound.glass.rawValue, volume: volume)
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            playSound(name: SystemSound.glass.rawValue, volume: volume)
            return
        }

        defer { url.stopAccessingSecurityScopedResource() }

        if let sound = NSSound(contentsOf: url, byReference: true) {
            sound.volume = volume
            sound.play()
        } else {
            // 無法載入音效，播放系統預設
            playSound(name: SystemSound.glass.rawValue, volume: volume)
        }
    }

    /// 試聽音效 (用於設定介面)
    func previewSound(source: SoundSource) {
        let volume = settings.soundVolume

        switch source {
        case .system(let sound):
            playSound(name: sound.rawValue, volume: volume)

        case .tts(let alarm):
            let message = settings.customTTSMessage?.isEmpty == false
                ? settings.customTTSMessage!
                : alarm.message
            playTTS(message: message, voice: settings.ttsVoice.voiceIdentifier, rate: settings.ttsRate)

        case .custom(let bookmarkData, _):
            playCustomSound(bookmarkData: bookmarkData, volume: volume)
        }
    }

    /// Execute a shell command asynchronously
    private func executeCommand(_ command: String) {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Command execution error: \(error)")
            }
        }
    }

    private func sendTimerCompleteNotification(label: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }

        let content = UNMutableNotificationContent()
        content.title = "計時器完成！"
        content.body = label.isEmpty ? "倒數計時已結束" : "「\(label)」已結束"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    private static let timersKey = "countdownTimers"

    private func loadState() {
        settings = .load()

        guard let data = UserDefaults.standard.data(forKey: Self.timersKey),
              var loadedTimers = try? JSONDecoder().decode([CountdownTimer].self, from: data)
        else {
            return
        }

        // Restore running timers
        for index in loadedTimers.indices {
            if loadedTimers[index].timerState == .running,
               let endTime = loadedTimers[index].targetEndTime {
                let remaining = endTime.timeIntervalSinceNow
                if remaining <= 0 {
                    // Timer expired while app was closed
                    loadedTimers[index].timerState = .idle
                    loadedTimers[index].targetEndTime = nil
                }
            }
        }

        timers = loadedTimers
    }

    private func saveState() {
        if let data = try? JSONEncoder().encode(timers) {
            UserDefaults.standard.set(data, forKey: Self.timersKey)
        }
    }
}
