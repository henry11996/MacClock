//
//  NotchCountdownView.swift
//  MacClock
//
//  Created by Claude on 2026/2/12.
//

import SwiftUI

/// Right notch panel: displays countdown timer(s) and Pomodoro status
/// Expands on hover to show all timers and controls
struct NotchCountdownView: View {
    @State private var isHovered = false
    var manager = CountdownManager.shared
    var pomodoro = PomodoroTimer.shared

    // MARK: - Computed State

    private var pomodoroIsActive: Bool {
        pomodoro.timerState == .running || pomodoro.timerState == .paused
    }

    private var pomodoroPhaseColor: Color {
        switch pomodoro.phase {
        case .work: return ThemeColors.workPhase
        case .shortBreak: return ThemeColors.shortBreak
        case .longBreak: return ThemeColors.longBreak
        }
    }

    /// Determines which timer to show in the collapsed state
    private var urgentTimer: CountdownTimer? {
        // 1. Show recently completed timer (for 3 seconds)
        if let completedId = manager.recentlyCompletedTimerId,
           let timer = manager.timers.first(where: { $0.id == completedId }) {
            return timer
        }

        // 2. Show running timer ending soonest
        let running = manager.timers.filter { $0.timerState == .running }
        if let first = running.sorted(by: { $0.currentRemainingSeconds() < $1.currentRemainingSeconds() }).first {
            return first
        }

        // 3. Show first paused timer
        return manager.timers.filter { $0.timerState == .paused }.first
    }

    // MARK: - Body

    var body: some View {
        let _ = manager.tickCount
        return VStack(alignment: .leading, spacing: 0) {
            // Primary Row (Always Visible)
            HStack(spacing: 12) {
                // Pomodoro Status
                if pomodoroIsActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(pomodoroPhaseColor)
                            .frame(width: 6, height: 6)
                        
                        Text(pomodoro.formattedTime)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(pomodoroPhaseColor)
                    }
                    .opacity(pomodoro.timerState == .paused ? 0.6 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NotificationCenter.default.post(name: .showSettings, object: SettingsTab.pomodoro)
                    }
                    
                    if urgentTimer != nil {
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 1, height: 12)
                    }
                }

                // Urgent Countdown Timer
                if let timer = urgentTimer {
                    singleTimerView(timer, showControls: false)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            NotificationCenter.default.post(name: .showSettings, object: SettingsTab.countdown)
                        }
                } else if !pomodoroIsActive {
                    // Placeholder when completely empty
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NotificationCenter.default.post(name: .showSettings, object: SettingsTab.countdown)
                    }
                }
            }
            .frame(height: NotchGeometry.menuBarHeight)
            .padding(.horizontal, 12)

            // Expanded List (Visible on Hover)
            if isHovered && !manager.timers.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .background(.white.opacity(0.1))
                    
                    ForEach(manager.timers) { timer in
                        HStack {
                            singleTimerView(timer, showControls: true)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleTimer(timer)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(minWidth: 80, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
        .background(.black)
        .clipShape(.rect(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("關閉瀏海模式") {
                NotificationCenter.default.post(name: .notchModeChanged, object: false)
            }
            Divider()
            Button("計時器設定...") {
                NotificationCenter.default.post(name: .showSettings, object: SettingsTab.countdown)
            }
        }
    }

    // MARK: - Components

    private func singleTimerView(_ timer: CountdownTimer, showControls: Bool) -> some View {
        HStack(spacing: 6) {
            // Status Dot
            Circle()
                .fill(Color(hex: timer.colorHex))
                .frame(width: 6, height: 6)
                .opacity(timer.timerState == .running ? 1.0 : 0.5)

            // Label
            Text(timer.label)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .frame(maxWidth: 60, alignment: .leading)

            Spacer()

            // Time
            Text(timer.formattedTime)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(urgencyColor(for: timer))

            // Control Button (only in expanded view)
            if showControls {
                Image(systemName: timer.timerState == .running ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Helpers

    private func urgencyColor(for timer: CountdownTimer) -> Color {
        // Highlight completed timer
        if timer.id == manager.recentlyCompletedTimerId {
            return .red
        }
        guard timer.timerState == .running else {
            return .white.opacity(0.6)
        }
        let remaining = timer.currentRemainingSeconds()
        let level = UrgencyLevel.from(progress: timer.progress, remainingSeconds: remaining)
        return level.timeColor
    }

    private func toggleTimer(_ timer: CountdownTimer) {
        if timer.timerState == .running {
            manager.pause(id: timer.id)
        } else {
            manager.start(id: timer.id)
        }
    }
}