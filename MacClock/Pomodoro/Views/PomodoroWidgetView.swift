//
//  PomodoroWidgetView.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import SwiftUI

/// Compact Pomodoro view for inline display (above/below clock)
struct CompactPomodoroView: View {
    @Bindable var timer: PomodoroTimer
    @Binding var showSettings: Bool
    let namespace: Namespace.ID

    @State private var isEditingPomodoros = false
    @State private var editedCount = 0

    private var fontScale: CGFloat {
        timer.settings.fontScale
    }

    private var liquidGlassEnabled: Bool {
        timer.settings.liquidGlassEnabled
    }

    var body: some View {
        Button {
            NotificationCenter.default.post(
                name: .enterPomodoroFullScreen,
                object: nil
            )
        } label: {
            pomodoroContent
        }
        .buttonStyle(.plain)
        .conditionalGlassEffect(enabled: liquidGlassEnabled, in: RoundedRectangle(cornerRadius: 20))
        .glassEffectID("compactPomodoro", in: namespace)
        .popover(isPresented: $showSettings) {
            PomodoroSettingsView(timer: timer, isPresented: $showSettings)
        }
    }

    private var pomodoroContent: some View {
        VStack(spacing: 6) {
            // Top row: Time, Phase, Controls
            HStack(spacing: Spacing.sm) {
                // Timer display
                Text(timer.formattedTime)
                    .font(.system(size: 28 * fontScale, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .contentTransition(.numericText())

                // Phase indicator (show different text based on timer state)
                Text(phaseDisplayText)
                    .font(.system(size: 14 * fontScale, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(phaseColor)

                // Control buttons
                HStack(spacing: Spacing.xs) {
                    // Play/Pause button
                    Button {
                        timer.toggleStartPause()
                    } label: {
                        Image(
                            systemName: timer.timerState == .running
                                ? "pause.fill" : "play.fill"
                        )
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                    }
                    .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.15))

                    // Skip button
                    Button {
                        timer.skip()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.1))

                    // Settings button
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.1))
                }
            }

            // Bottom row: Progress bar + dots + focus time
            HStack(spacing: Spacing.sm) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(phaseColor)
                            .frame(width: geo.size.width * timer.progress, height: 4)
                            .animation(AnimationPresets.progressUpdate, value: timer.progress)
                    }
                }
                .frame(height: 4)
                .frame(width: 60)

                // Pomodoro progress dots (clickable to edit)
                Button {
                    editedCount = timer.completedPomodoros
                    isEditingPomodoros = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        ForEach(0..<timer.settings.pomodorosUntilLongBreak, id: \.self) {
                            index in
                            Circle()
                                .fill(
                                    isCompleted(index: index)
                                        ? ThemeColors.workPhase : Color.secondary.opacity(0.3)
                                )
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(InteractiveButtonStyle())
                .popover(isPresented: $isEditingPomodoros) {
                    pomodoroEditPopover
                }

                // Total focus time
                HStack(spacing: Spacing.xs) {
                    Text("專注:")
                        .font(.system(size: 11 * fontScale, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Text(timer.formattedFocusTime)
                        .font(.system(size: 11 * fontScale, weight: .medium, design: .rounded))
                        .lineLimit(1)
                }
            }
        }
        .fixedSize()
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private func isCompleted(index: Int) -> Bool {
        let cycleProgress = timer.completedPomodoros % timer.settings.pomodorosUntilLongBreak
        if timer.completedPomodoros > 0 && cycleProgress == 0 {
            return true
        }
        return index < cycleProgress
    }

    private var phaseDisplayText: String {
        if timer.timerState == .running {
            return timer.phase.displayName
        } else {
            switch timer.phase {
            case .work: return "工作"
            case .shortBreak, .longBreak: return "休息"
            }
        }
    }

    private var phaseColor: Color {
        switch timer.phase {
        case .work: return ThemeColors.workPhase
        case .shortBreak: return ThemeColors.shortBreak
        case .longBreak: return ThemeColors.longBreak
        }
    }

    private var pomodoroEditPopover: some View {
        VStack(spacing: Spacing.md) {
            Text("編輯番茄鐘數")
                .font(.headline)

            Stepper(value: $editedCount, in: 0...99) {
                Text("\(editedCount) 個番茄鐘")
            }

            HStack(spacing: Spacing.sm) {
                Button("取消") {
                    isEditingPomodoros = false
                }
                .buttonStyle(InteractiveButtonStyle())

                Button("確定") {
                    timer.setCompletedPomodoros(editedCount)
                    isEditingPomodoros = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 200)
    }
}

struct PomodoroWidgetView: View {
    @Bindable var timer: PomodoroTimer
    @Binding var showSettings: Bool
    var onEnterFullScreen: () -> Void
    let namespace: Namespace.ID

    @State private var isEditingPomodoros = false
    @State private var editedCount = 0

    private var fontScale: CGFloat {
        timer.settings.fontScale
    }

    private var liquidGlassEnabled: Bool {
        timer.settings.liquidGlassEnabled
    }

    var body: some View {
        Button {
            onEnterFullScreen()
        } label: {
            VStack(spacing: 6) {
                // Top row: Time, Phase, Controls
                HStack(spacing: Spacing.sm) {
                    // Timer display
                    Text(timer.formattedTime)
                        .font(.system(size: 28 * fontScale, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .contentTransition(.numericText())

                    // Phase indicator (show different text based on timer state)
                    Text(phaseDisplayText)
                        .font(.system(size: 14 * fontScale, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(phaseColor)

                    // Control buttons
                    HStack(spacing: Spacing.xs) {
                        // Play/Pause button
                        Button {
                            timer.toggleStartPause()
                        } label: {
                            Image(
                                systemName: timer.timerState == .running
                                    ? "pause.fill" : "play.fill"
                            )
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                        }
                        .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.15))

                        // Skip button
                        Button {
                            timer.skip()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .contentShape(Circle())
                        }
                        .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.1))

                        // Settings button
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .contentShape(Circle())
                        }
                        .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.1))
                    }
                }

                // Bottom row: Progress bar + dots + focus time
                HStack(spacing: Spacing.sm) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(phaseColor)
                                .frame(width: geo.size.width * timer.progress, height: 4)
                                .animation(AnimationPresets.progressUpdate, value: timer.progress)
                        }
                    }
                    .frame(height: 4)
                    .frame(width: 60)

                    // Pomodoro progress dots (clickable to edit)
                    Button {
                        editedCount = timer.completedPomodoros
                        isEditingPomodoros = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            ForEach(0..<timer.settings.pomodorosUntilLongBreak, id: \.self) {
                                index in
                                Circle()
                                    .fill(
                                        isCompleted(index: index)
                                            ? ThemeColors.workPhase : Color.secondary.opacity(0.3)
                                    )
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(InteractiveButtonStyle())
                    .popover(isPresented: $isEditingPomodoros) {
                        pomodoroEditPopover
                    }

                    // Total focus time
                    HStack(spacing: Spacing.xs) {
                        Text("專注:")
                            .font(.system(size: 11 * fontScale, design: .rounded))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Text(timer.formattedFocusTime)
                            .font(.system(size: 11 * fontScale, weight: .medium, design: .rounded))
                            .lineLimit(1)
                    }
                }
            }
            .fixedSize()
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.plain)
        .conditionalGlassEffect(enabled: liquidGlassEnabled, in: RoundedRectangle(cornerRadius: 20))
        .glassEffectID("pomodoro", in: namespace)
    }

    private func isCompleted(index: Int) -> Bool {
        let cycleProgress = timer.completedPomodoros % timer.settings.pomodorosUntilLongBreak
        if timer.completedPomodoros > 0 && cycleProgress == 0 {
            return true  // Full cycle completed
        }
        return index < cycleProgress
    }

    private var phaseDisplayText: String {
        // Show different text based on timer state
        if timer.timerState == .running {
            return timer.phase.displayName  // 工作中, 短休息, 長休息
        } else {
            // When idle or paused, show simpler text
            switch timer.phase {
            case .work: return "工作"
            case .shortBreak, .longBreak: return "休息"
            }
        }
    }

    private var phaseColor: Color {
        switch timer.phase {
        case .work: return ThemeColors.workPhase
        case .shortBreak: return ThemeColors.shortBreak
        case .longBreak: return ThemeColors.longBreak
        }
    }

    private var pomodoroEditPopover: some View {
        VStack(spacing: Spacing.md) {
            Text("編輯番茄鐘數")
                .font(.headline)

            Stepper(value: $editedCount, in: 0...99) {
                Text("\(editedCount) 個番茄鐘")
            }

            HStack(spacing: Spacing.sm) {
                Button("取消") {
                    isEditingPomodoros = false
                }
                .buttonStyle(InteractiveButtonStyle())

                Button("確定") {
                    timer.setCompletedPomodoros(editedCount)
                    isEditingPomodoros = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 200)
    }
}
