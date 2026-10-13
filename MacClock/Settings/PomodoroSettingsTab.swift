//
//  PomodoroSettingsTab.swift
//  MacClock
//

import SwiftUI

struct PomodoroSettingsTab: View {
    let onClose: () -> Void
    var timer = PomodoroTimer.shared

    @State private var pomodoroPosition: PomodoroPosition
    @State private var fontScale: CGFloat
    @State private var workMinutes: Double
    @State private var shortBreakMinutes: Double
    @State private var longBreakMinutes: Double
    @State private var pomodorosUntilLongBreak: Int
    @State private var soundEnabled: Bool
    @State private var soundVolume: Float
    @State private var autoStartBreaks: Bool
    @State private var autoStartWork: Bool
    @State private var showResetConfirmation = false

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let settings = PomodoroTimer.shared.settings
        _pomodoroPosition = State(initialValue: settings.pomodoroPosition)
        _fontScale = State(initialValue: settings.fontScale)
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
        SettingsTabScaffold(onClose: onClose, leading: { resetButton }) {
            SettingsHeader(
                title: "番茄鐘",
                subtitle: "已完成 \(timer.completedPomodoros) 個番茄鐘，累計專注 \(timer.formattedFocusTime)",
                icon: "timer",
                tint: ThemeColors.workPhase
            )

            durationCard
            displayCard
            soundCard
            autoStartCard
        }
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
        // 任何變更立即存檔，直接關閉視窗也不會遺失
        .onChange(of: pomodoroPosition) { _, v in update(notifyLayout: true) { $0.pomodoroPosition = v } }
        .onChange(of: fontScale) { _, v in update(notifyLayout: true) { $0.fontScale = v } }
        .onChange(of: workMinutes) { _, v in update { $0.workDuration = v * 60 } }
        .onChange(of: shortBreakMinutes) { _, v in update { $0.shortBreakDuration = v * 60 } }
        .onChange(of: longBreakMinutes) { _, v in update { $0.longBreakDuration = v * 60 } }
        .onChange(of: pomodorosUntilLongBreak) { _, v in update { $0.pomodorosUntilLongBreak = v } }
        .onChange(of: soundEnabled) { _, v in update { $0.soundEnabled = v } }
        .onChange(of: soundVolume) { _, v in update { $0.soundVolume = v } }
        .onChange(of: autoStartBreaks) { _, v in update { $0.autoStartBreaks = v } }
        .onChange(of: autoStartWork) { _, v in update { $0.autoStartWork = v } }
    }

    // MARK: - Cards

    private var durationCard: some View {
        SettingsCard(title: "時間", icon: "clock") {
            durationRow("工作", icon: "brain.head.profile", color: ThemeColors.workPhase,
                        value: $workMinutes, range: 1...60, step: 5)
            durationRow("短休息", icon: "cup.and.saucer", color: ThemeColors.shortBreak,
                        value: $shortBreakMinutes, range: 1...30, step: 1)
            durationRow("長休息", icon: "figure.walk", color: ThemeColors.longBreak,
                        value: $longBreakMinutes, range: 5...60, step: 5)

            Divider()

            SettingRow(title: "長休息間隔", subtitle: "每完成幾個番茄鐘進入長休息", icon: "repeat") {
                Stepper(value: $pomodorosUntilLongBreak, in: 2...8) {
                    valueText("\(pomodorosUntilLongBreak) 個")
                }
                .accessibilityLabel("長休息間隔")
                .accessibilityValue("\(pomodorosUntilLongBreak) 個")
            }

            cycleSummary
        }
    }

    /// 一輪循環的視覺化：工作與休息交替，最後一段為長休息
    private var cycleSummary: some View {
        let cycleMinutes = Int(workMinutes) * pomodorosUntilLongBreak
            + Int(shortBreakMinutes) * (pomodorosUntilLongBreak - 1)
            + Int(longBreakMinutes)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 3) {
                ForEach(0..<pomodorosUntilLongBreak, id: \.self) { index in
                    Capsule().fill(ThemeColors.workPhase).frame(height: 6)
                    if index < pomodorosUntilLongBreak - 1 {
                        Capsule().fill(ThemeColors.shortBreak).frame(width: 10, height: 6)
                    }
                }
                Capsule().fill(ThemeColors.longBreak).frame(width: 24, height: 6)
            }
            SettingsFootnote(text: "一輪約 \(formatDuration(cycleMinutes))")
        }
        .padding(.top, Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("一輪約 \(formatDuration(cycleMinutes))")
    }

    private var displayCard: some View {
        SettingsCard(title: "顯示", icon: "square.stack") {
            SettingRow(title: "位置", subtitle: "番茄鐘相對於時鐘的位置", icon: "rectangle.split.1x2") {
                Picker("番茄鐘位置", selection: $pomodoroPosition) {
                    Text("隱藏").tag(PomodoroPosition.hidden)
                    Text("上方").tag(PomodoroPosition.above)
                    Text("下方").tag(PomodoroPosition.below)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            if pomodoroPosition != .hidden {
                FontScaleRow(title: "字體大小", icon: "textformat.size", value: $fontScale)
            }
        }
    }

    private var soundCard: some View {
        SettingsCard(title: "聲音", icon: "speaker.wave.2") {
            SettingToggleRow(title: "階段結束提示音", icon: "bell", isOn: $soundEnabled)

            if soundEnabled {
                HStack(spacing: Spacing.md) {
                    Slider(value: $soundVolume, in: 0...1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Image(systemName: "speaker.fill").font(.system(size: 10))
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3.fill").font(.system(size: 10))
                    }
                    .controlSize(.small)
                    .accessibilityLabel("提示音音量")
                    .accessibilityValue("\(Int(soundVolume * 100))%")

                    Button {
                        NotificationService.shared.playCompletionSound(volume: soundVolume)
                    } label: {
                        Label("試聽", systemImage: "play.circle")
                    }
                    .controlSize(.small)
                }
                .padding(.leading, 20 + Spacing.md)
            }
        }
    }

    private var autoStartCard: some View {
        SettingsCard(title: "自動開始", icon: "arrow.triangle.2.circlepath") {
            SettingToggleRow(
                title: "自動開始休息",
                subtitle: "工作結束後自動進入休息",
                icon: "cup.and.saucer",
                isOn: $autoStartBreaks
            )
            SettingToggleRow(
                title: "自動開始工作",
                subtitle: "休息結束後自動進入下一個番茄鐘",
                icon: "brain.head.profile",
                isOn: $autoStartWork
            )
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showResetConfirmation = true
        } label: {
            Label("重置進度", systemImage: "arrow.counterclockwise")
                .font(.system(size: 12, design: .rounded))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.red)
    }

    // MARK: - Rows

    private func durationRow(
        _ title: String,
        icon: String,
        color: Color,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        SettingRow(title: title, icon: icon, iconColor: color) {
            Stepper(value: value, in: range, step: step) {
                valueText("\(Int(value.wrappedValue)) 分鐘")
            }
            .accessibilityLabel(title)
            .accessibilityValue("\(Int(value.wrappedValue)) 分鐘")
        }
    }

    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
            .frame(minWidth: 64, alignment: .trailing)
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder) 分鐘" }
        return remainder == 0 ? "\(hours) 小時" : "\(hours) 小時 \(remainder) 分鐘"
    }

    /// 只寫入有變動的欄位，避免用分頁開啟時的舊值覆蓋其他地方的修改
    private func update(notifyLayout: Bool = false, _ change: (inout PomodoroSettings) -> Void) {
        var settings = timer.settings
        change(&settings)
        guard settings != timer.settings else { return }
        timer.settings = settings
        if notifyLayout {
            NotificationCenter.default.post(name: .fontScaleChanged, object: nil)
        }
    }
}
