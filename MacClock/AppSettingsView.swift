//
//  AppSettingsView.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/3.
//

import SwiftUI

struct AppSettingsView: View {
    @Bindable var timer: PomodoroTimer
    @Binding var isPresented: Bool

    @State private var fontScale: CGFloat
    @State private var pomodoroPosition: PomodoroPosition
    @State private var countdownPosition: CountdownPosition
    @State private var liquidGlassEnabled: Bool
    @State private var backgroundUpdateFPS: BackgroundUpdateFPS

    init(timer: PomodoroTimer, isPresented: Binding<Bool>) {
        self.timer = timer
        self._isPresented = isPresented
        _fontScale = State(initialValue: timer.settings.fontScale)
        _pomodoroPosition = State(initialValue: timer.settings.pomodoroPosition)
        _countdownPosition = State(initialValue: CountdownManager.shared.settings.position)
        _liquidGlassEnabled = State(initialValue: timer.settings.liquidGlassEnabled)
        _backgroundUpdateFPS = State(initialValue: timer.settings.backgroundUpdateFPS)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack {
                Text("顯示設定")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Label("字體大小", systemImage: "textformat.size")
                        .font(.system(size: 13, design: .rounded))
                    Spacer()
                    Text("\(Int(fontScale * 100))%")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }
                HStack(spacing: Spacing.md) {
                    Text("小")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Slider(value: $fontScale, in: 0.8...5.0, step: 0.1)
                        .controlSize(.small)
                    Text("大")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(Spacing.md)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Pomodoro position setting
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("番茄鐘位置", systemImage: "timer")
                    .font(.system(size: 13, design: .rounded))

                Picker("番茄鐘位置", selection: $pomodoroPosition) {
                    Text("隱藏").tag(PomodoroPosition.hidden)
                    Text("時鐘上方").tag(PomodoroPosition.above)
                    Text("時鐘下方").tag(PomodoroPosition.below)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(Spacing.md)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Countdown position setting
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("倒數計時位置", systemImage: "hourglass")
                    .font(.system(size: 13, design: .rounded))

                Picker("倒數計時位置", selection: $countdownPosition) {
                    Text("隱藏").tag(CountdownPosition.hidden)
                    Text("時鐘上方").tag(CountdownPosition.above)
                    Text("時鐘下方").tag(CountdownPosition.below)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(Spacing.md)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Liquid Glass 設定
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Toggle(isOn: $liquidGlassEnabled) {
                    Label("Liquid Glass 效果", systemImage: "drop.fill")
                        .font(.system(size: 13, design: .rounded))
                }
                .toggleStyle(.switch)

                if liquidGlassEnabled {
                    Divider()
                        .padding(.vertical, Spacing.xs)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Label("背景更新 (FPS)", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)

                        Picker("背景更新頻率", selection: $backgroundUpdateFPS) {
                            ForEach(BackgroundUpdateFPS.allCases, id: \.self) { fps in
                                Text(fps.displayName).tag(fps)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
            }
            .padding(Spacing.md)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Divider()

            // Action buttons
            HStack {
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
        .frame(width: 280)
    }

    private func saveSettings() {
        var settings = timer.settings
        settings.fontScale = fontScale
        settings.pomodoroPosition = pomodoroPosition
        settings.liquidGlassEnabled = liquidGlassEnabled
        settings.backgroundUpdateFPS = backgroundUpdateFPS
        timer.settings = settings

        var countdownSettings = CountdownManager.shared.settings
        countdownSettings.position = countdownPosition
        CountdownManager.shared.settings = countdownSettings

        // Notify BackgroundRefreshService about settings change
        NotificationCenter.default.post(name: .backgroundRefreshSettingsChanged, object: nil)
    }
}
