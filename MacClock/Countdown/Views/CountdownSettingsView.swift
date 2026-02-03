//
//  CountdownSettingsView.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import SwiftUI

/// Settings view for adding and managing countdown timers
struct CountdownSettingsView: View {
    @Bindable var manager: CountdownManager
    @Binding var isPresented: Bool

    @State private var newLabel: String = ""
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 5
    @State private var selectedSeconds: Int = 0
    @State private var selectedColorHex: UInt = CountdownColors.blue
    @State private var completionCommand: String = ""

    // Edit mode state
    @State private var editingTimerId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header
            HStack {
                Text("倒數計時器")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
            }

            // Sound settings section
            soundSettingsSection

            Divider()

            // Quick add section
            quickAddSection

            Divider()

            // Custom timer section
            customTimerSection

            // Existing timers list
            if !manager.timers.isEmpty {
                Divider()
                existingTimersSection
            }

            Divider()

            // Close button
            HStack {
                Spacer()
                Button("關閉") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(Spacing.lg)
        .frame(width: 320)
    }

    // MARK: - Sound Settings Section

    private var soundSettingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("聲音設定")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            // Sound picker
            HStack {
                Text("提示聲音")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                Picker("", selection: $manager.settings.soundName) {
                    ForEach(SystemSound.allCases, id: \.self) { sound in
                        Text(sound.displayName).tag(sound)
                    }
                }
                .frame(width: 160)
                .labelsHidden()
            }

            // Volume slider
            HStack {
                Text("音量")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Slider(value: $manager.settings.soundVolume, in: 0...1)
                        .frame(width: 100)
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            // Preview button
            HStack {
                Spacer()
                Button {
                    manager.playSound(
                        name: manager.settings.soundName.rawValue,
                        volume: manager.settings.soundVolume
                    )
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "play.fill")
                        Text("試聽")
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Quick Add Section

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("快速新增")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.sm) {
                quickAddButton(label: "1 分鐘", duration: 60)
                quickAddButton(label: "5 分鐘", duration: 300)
                quickAddButton(label: "10 分鐘", duration: 600)
                quickAddButton(label: "15 分鐘", duration: 900)
                quickAddButton(label: "30 分鐘", duration: 1800)
                quickAddButton(label: "1 小時", duration: 3600)
            }
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func quickAddButton(label: String, duration: TimeInterval) -> some View {
        Button {
            manager.addTimer(label: label, duration: duration, colorHex: selectedColorHex)
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(InteractiveButtonStyle())
    }

    // MARK: - Custom Timer Section

    private var customTimerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(editingTimerId != nil ? "編輯計時器" : "自訂計時器")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                if editingTimerId != nil {
                    Button("取消編輯") {
                        cancelEdit()
                    }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            }

            // Label input
            HStack {
                Text("標籤")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                TextField("計時器名稱", text: $newLabel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }

            // Time picker
            HStack {
                Text("時間")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                timePickers
            }

            // Color picker
            HStack {
                Text("顏色")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                colorPicker
            }

            // Completion command input
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("完成指令")
                        .font(.system(size: 12, design: .rounded))
                    Spacer()
                }
                TextField("例如：say \"時間到了\"", text: $completionCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                Text("計時結束時執行的 shell 指令（可留空）")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            // Add/Save button
            Button {
                if editingTimerId != nil {
                    saveEditedTimer()
                } else {
                    addCustomTimer()
                }
            } label: {
                HStack {
                    Image(systemName: editingTimerId != nil ? "checkmark.circle.fill" : "plus.circle.fill")
                    Text(editingTimerId != nil ? "儲存變更" : "新增計時器")
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .disabled(totalSeconds == 0)
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var timePickers: some View {
        HStack(spacing: Spacing.xs) {
            Picker("", selection: $selectedHours) {
                ForEach(0..<24, id: \.self) { hour in
                    Text("\(hour)").tag(hour)
                }
            }
            .frame(width: 50)
            .labelsHidden()
            Text("時")
                .font(.system(size: 11, design: .rounded))

            Picker("", selection: $selectedMinutes) {
                ForEach(0..<60, id: \.self) { minute in
                    Text("\(minute)").tag(minute)
                }
            }
            .frame(width: 50)
            .labelsHidden()
            Text("分")
                .font(.system(size: 11, design: .rounded))

            Picker("", selection: $selectedSeconds) {
                ForEach(0..<60, id: \.self) { second in
                    Text("\(second)").tag(second)
                }
            }
            .frame(width: 50)
            .labelsHidden()
            Text("秒")
                .font(.system(size: 11, design: .rounded))
        }
    }

    private var colorPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(CountdownColors.all, id: \.self) { hex in
                Button {
                    selectedColorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selectedColorHex == hex ? 2 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var totalSeconds: TimeInterval {
        TimeInterval(selectedHours * 3600 + selectedMinutes * 60 + selectedSeconds)
    }

    private func addCustomTimer() {
        guard totalSeconds > 0 else { return }
        manager.addTimer(
            label: newLabel.isEmpty ? "計時器" : newLabel,
            duration: totalSeconds,
            colorHex: selectedColorHex,
            completionCommand: completionCommand.isEmpty ? nil : completionCommand
        )
        newLabel = ""
        selectedHours = 0
        selectedMinutes = 5
        selectedSeconds = 0
        completionCommand = ""
    }

    // MARK: - Existing Timers Section

    private var existingTimersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("已建立的計時器 (\(manager.timers.count))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: Spacing.xs) {
                    ForEach(manager.timers) { timer in
                        existingTimerRow(timer)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func existingTimerRow(_ timer: CountdownTimer) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(Color(hex: timer.colorHex))
                .frame(width: 10, height: 10)

            Text(timer.label.isEmpty ? "計時器" : timer.label)
                .font(.system(size: 12, design: .rounded))
                .lineLimit(1)

            // Command indicator
            if timer.completionCommand != nil && !timer.completionCommand!.isEmpty {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .help("完成時執行指令")
            }

            Spacer()

            Text(formatDuration(timer.duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            // State indicator
            if timer.timerState == .running {
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(ThemeColors.primary)
            } else if timer.timerState == .paused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            }

            // Edit button
            Button {
                startEditing(timer)
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.primary)
            }
            .buttonStyle(.plain)

            // Delete button
            Button {
                if editingTimerId == timer.id {
                    cancelEdit()
                }
                manager.removeTimer(id: timer.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(editingTimerId == timer.id ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Edit Functions

    private func startEditing(_ timer: CountdownTimer) {
        editingTimerId = timer.id
        newLabel = timer.label
        selectedColorHex = timer.colorHex
        completionCommand = timer.completionCommand ?? ""

        let totalSecs = Int(timer.duration)
        selectedHours = totalSecs / 3600
        selectedMinutes = (totalSecs % 3600) / 60
        selectedSeconds = totalSecs % 60
    }

    private func cancelEdit() {
        editingTimerId = nil
        newLabel = ""
        selectedHours = 0
        selectedMinutes = 5
        selectedSeconds = 0
        selectedColorHex = CountdownColors.blue
        completionCommand = ""
    }

    private func saveEditedTimer() {
        guard let id = editingTimerId, totalSeconds > 0 else { return }

        manager.updateTimer(
            id: id,
            label: newLabel.isEmpty ? "計時器" : newLabel,
            duration: totalSeconds,
            colorHex: selectedColorHex,
            completionCommand: completionCommand.isEmpty ? nil : completionCommand
        )

        cancelEdit()
    }
}
