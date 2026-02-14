//
//  PomodoroSettingsView.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import SwiftUI

/// Card-style settings section
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ThemeColors.primary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Content
            VStack(alignment: .leading, spacing: Spacing.sm) {
                content()
            }
            .padding(Spacing.md)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// Settings row with consistent styling
struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

struct PomodoroSettingsView: View {
    @Bindable var timer: PomodoroTimer
    @Binding var isPresented: Bool

    @State private var workMinutes: Double
    @State private var shortBreakMinutes: Double
    @State private var longBreakMinutes: Double
    @State private var pomodorosUntilLongBreak: Int
    @State private var soundEnabled: Bool
    @State private var soundVolume: Float
    @State private var autoStartBreaks: Bool
    @State private var autoStartWork: Bool
    @State private var showResetConfirmation = false

    init(timer: PomodoroTimer, isPresented: Binding<Bool>) {
        self.timer = timer
        self._isPresented = isPresented

        let settings = timer.settings
        _workMinutes = State(initialValue: settings.workDuration / 60)
        _shortBreakMinutes = State(initialValue: settings.shortBreakDuration / 60)
        _longBreakMinutes = State(initialValue: settings.longBreakDuration / 60)
        _pomodorosUntilLongBreak = State(initialValue: settings.pomodorosUntilLongBreak)
        _soundEnabled = State(initialValue: settings.soundEnabled)
        _soundVolume = State(initialValue: settings.soundVolume)
        _autoStartBreaks = State(initialValue: settings.autoStartBreaks)
        _autoStartWork = State(initialValue: settings.autoStartWork)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack {
                Text("番茄鐘設定")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Time settings card
                    SettingsCard(title: "時間設定", icon: "clock") {
                        HStack {
                            Label("工作", systemImage: "brain.head.profile")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(ThemeColors.workPhase)
                            Spacer()
                            Stepper(value: $workMinutes, in: 1...60, step: 5) {
                                Text(formatMinutes(workMinutes))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }

                        HStack {
                            Label("短休息", systemImage: "cup.and.saucer")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(ThemeColors.shortBreak)
                            Spacer()
                            Stepper(value: $shortBreakMinutes, in: 1...30, step: 1) {
                                Text(formatMinutes(shortBreakMinutes))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }

                        HStack {
                            Label("長休息", systemImage: "figure.walk")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(ThemeColors.longBreak)
                            Spacer()
                            Stepper(value: $longBreakMinutes, in: 5...60, step: 5) {
                                Text(formatMinutes(longBreakMinutes))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }

                        Divider()
                            .padding(.vertical, Spacing.xs)

                        HStack {
                            Label("長休息間隔", systemImage: "repeat")
                                .font(.system(size: 13, design: .rounded))
                            Spacer()
                            Stepper(value: $pomodorosUntilLongBreak, in: 2...8) {
                                Text("\(pomodorosUntilLongBreak) 個")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }

                    // Sound settings card
                    SettingsCard(title: "聲音設定", icon: "speaker.wave.2") {
                        Toggle(isOn: $soundEnabled) {
                            Text("啟用提示音")
                                .font(.system(size: 13, design: .rounded))
                        }
                        .toggleStyle(.switch)

                        if soundEnabled {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: "speaker.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Slider(value: $soundVolume, in: 0...1)
                                    .controlSize(.small)
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Button {
                                    NotificationService.shared.playCompletionSound(
                                        volume: soundVolume)
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(ThemeColors.primary)
                                }
                                .buttonStyle(InteractiveButtonStyle())
                            }
                            .padding(.top, Spacing.xs)
                        }
                    }

                    // Auto-start settings card
                    SettingsCard(title: "自動開始", icon: "arrow.triangle.2.circlepath") {
                        Toggle(isOn: $autoStartBreaks) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("自動開始休息")
                                    .font(.system(size: 13, design: .rounded))
                                Text("工作結束後自動進入休息")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $autoStartWork) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("自動開始工作")
                                    .font(.system(size: 13, design: .rounded))
                                Text("休息結束後自動進入工作")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
            }
            .frame(maxHeight: 350)

            Divider()

            // Action buttons
            HStack(spacing: Spacing.md) {
                Button {
                    showResetConfirmation = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置進度")
                    }
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.red)
                }
                .buttonStyle(InteractiveButtonStyle())

                Spacer()

                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(InteractiveButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])

                Button("儲存") {
                    saveSettings()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(Spacing.lg)
        .frame(width: 340)
        .confirmationDialog(
            "確定要重置所有進度嗎？",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置", role: .destructive) {
                timer.resetAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這將清除所有已完成的番茄鐘和專注時間記錄。")
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        "\(Int(minutes)) 分鐘"
    }

    private func saveSettings() {
        timer.settings = PomodoroSettings(
            workDuration: workMinutes * 60,
            shortBreakDuration: shortBreakMinutes * 60,
            longBreakDuration: longBreakMinutes * 60,
            pomodorosUntilLongBreak: pomodorosUntilLongBreak,
            soundEnabled: soundEnabled,
            soundVolume: soundVolume,
            autoStartBreaks: autoStartBreaks,
            autoStartWork: autoStartWork,
            fontScale: timer.settings.fontScale,
            clockFontScale: timer.settings.clockFontScale,
            clockStyle: timer.settings.clockStyle,
            pomodoroPosition: timer.settings.pomodoroPosition,
            liquidGlassEnabled: timer.settings.liquidGlassEnabled,
            backgroundUpdateFPS: timer.settings.backgroundUpdateFPS,
            notchModeEnabled: timer.settings.notchModeEnabled
        )
    }
}
