//
//  CountdownSettingsTab.swift
//  MacClock
//
//  計時器設定分頁
//

import AppKit
import os
import SwiftUI
import UniformTypeIdentifiers

private let countdownSettingsLogger = Logger(subsystem: "MacClock", category: "CountdownSettings")

struct CountdownSettingsTab: View {
    let onClose: () -> Void
    var manager = CountdownManager.shared

    @State private var isEnabled: Bool
    @State private var countdownPosition: CountdownPosition
    @State private var countdownFontScale: CGFloat
    @State private var autoCollapseEnabled: Bool

    // 新增 / 編輯計時器
    @State private var newLabel: String = ""
    @State private var timeInput: String = "5:00"
    @State private var selectedColorHex: UInt = CountdownColors.blue
    @State private var completionCommand: String = ""
    @State private var editingTimerId: UUID?

    // 提示音 UI 狀態
    @State private var soundSourceType: SoundSourceType = .system
    @State private var selectedSystemSound: SystemSound = .glass
    @State private var selectedTTSAlarm: TTSAlarm = .timeUp
    @State private var customTTSMessage: String = ""
    @State private var selectedTTSVoice: TTSVoice = .meiJia
    @State private var ttsRate: Int = 200
    @State private var customSoundName: String = ""
    @State private var customSoundBookmarkData: Data?

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let settings = CountdownManager.shared.settings
        _isEnabled = State(initialValue: settings.isEnabled)
        _countdownPosition = State(initialValue: settings.position)
        _countdownFontScale = State(initialValue: settings.fontScale)
        _autoCollapseEnabled = State(initialValue: settings.autoCollapseEnabled)
    }

    private var parsedSeconds: TimeInterval { CountdownTimeInput.parse(timeInput) }
    private var isEditing: Bool { editingTimerId != nil }
    private var isAtLimit: Bool { manager.timers.count >= CountdownManager.maxTimerCount }
    private var canSubmit: Bool { parsedSeconds > 0 && (isEditing || !isAtLimit) }
    private var trimmedCommand: String { completionCommand.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        SettingsTabScaffold(onClose: onClose) {
            headerCard
            if !isEnabled {
                disabledNotice
            }
            // 關閉時仍顯示內容（變暗且不可操作），讓使用者看得到既有計時器與設定
            Group {
                editorCard
                if !manager.timers.isEmpty { timerListCard }
                displayCard
                soundCard
            }
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .onAppear { syncSoundSettingsState() }
        .onChange(of: isEnabled) { manager.settings.isEnabled = isEnabled }
        .onChange(of: autoCollapseEnabled) { manager.settings.autoCollapseEnabled = autoCollapseEnabled }
        .onChange(of: countdownPosition) { savePositionSettings() }
        .onChange(of: countdownFontScale) { savePositionSettings() }
    }

    // MARK: - Header

    private var disabledNotice: some View {
        Label("計時器功能已關閉，小工具不會顯示計時器。開啟右上角開關即可編輯。", systemImage: "info.circle")
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var headerCard: some View {
        SettingsHeader(
            title: "倒數計時器",
            subtitle: "目前 \(manager.timers.count) / \(CountdownManager.maxTimerCount) 個計時器",
            icon: "hourglass"
        ) {
            Toggle("啟用計時器", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel("啟用計時器")
        }
    }

    // MARK: - Editor

    private var editorCard: some View {
        SettingsCard(title: isEditing ? "編輯計時器" : "新增計時器", icon: isEditing ? "pencil" : "plus.circle") {
            CountdownQuickChips(selectedSeconds: parsedSeconds) { timeInput = CountdownTimeInput.format($0) }

            HStack(alignment: .top, spacing: Spacing.md) {
                labeledField("時間（分 或 分:秒 或 時:分:秒）") {
                    TextField("5:00", text: $timeInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(width: 90)
                        .accessibilityLabel("時間")
                }
                labeledField("標籤") {
                    TextField("計時器", text: $newLabel)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("標籤")
                }
            }

            if !timeInput.isEmpty && parsedSeconds == 0 {
                Label("時間格式不正確，請輸入如 5、5:00 或 1:30:00", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.orange)
            }

            SettingRow(title: "顏色", icon: "paintpalette") {
                CountdownColorPicker(selectedHex: $selectedColorHex)
            }

            Divider()

            labeledField("完成時執行指令（選填）") {
                TextField("say \"時間到\"", text: $completionCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .accessibilityLabel("完成時執行的 shell 指令")
            }
            if !trimmedCommand.isEmpty {
                Label("計時結束時會以你的使用者權限自動執行此 shell 指令，請只輸入你信任的內容。",
                      systemImage: "exclamationmark.shield")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if isEditing {
                    Button("取消編輯", action: cancelEdit)
                }
                Spacer()
                Button(action: submit) {
                    Label(isEditing ? "儲存" : "新增計時器",
                          systemImage: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }

            if isAtLimit && !isEditing {
                SettingsFootnote(text: "已達計時器上限（\(CountdownManager.maxTimerCount) 個），請先刪除不需要的計時器。")
            }
        }
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Timer List

    private var timerListCard: some View {
        SettingsCard(title: "已建立的計時器（\(manager.timers.count)）", icon: "list.bullet") {
            VStack(spacing: Spacing.xs) {
                ForEach(manager.timers) { timer in
                    CountdownTimerRow(
                        timer: timer,
                        isEditing: editingTimerId == timer.id,
                        onEdit: { startEditing(timer) },
                        onDelete: { delete(timer) }
                    )
                }
            }
        }
    }

    // MARK: - Display

    private var displayCard: some View {
        SettingsCard(title: "顯示", icon: "rectangle.on.rectangle") {
            SettingRow(title: "位置", icon: "square.stack") {
                Picker("計時器位置", selection: $countdownPosition) {
                    Text("隱藏").tag(CountdownPosition.hidden)
                    Text("時鐘上方").tag(CountdownPosition.above)
                    Text("時鐘下方").tag(CountdownPosition.below)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            SettingToggleRow(
                title: "倒數時才顯示",
                subtitle: "計時器倒數時展開列表，停止 30 秒後自動收起",
                icon: "arrow.up.and.down.text.horizontal",
                isOn: $autoCollapseEnabled
            )

            Divider()

            FontScaleRow(title: "計時器", icon: "textformat.size", value: $countdownFontScale)
        }
    }

    private func savePositionSettings() {
        manager.settings.position = countdownPosition
        manager.settings.fontScale = countdownFontScale
        NotificationCenter.default.post(name: .fontScaleChanged, object: nil)
    }

    // MARK: - Sound

    private var soundCard: some View {
        SettingsCard(title: "提示音", icon: "speaker.wave.2") {
            Picker("提示音來源", selection: $soundSourceType) {
                ForEach(SoundSourceType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: soundSourceType) { applySoundSettings() }

            switch soundSourceType {
            case .system: systemSoundRows
            case .tts: ttsSoundRows
            case .custom: customSoundRows
            }

            Divider()

            HStack(spacing: Spacing.sm) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Slider(value: Bindable(manager).settings.soundVolume, in: 0...1)
                    .accessibilityLabel("音量")
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Button(action: previewCurrentSound) {
                    Label("試聽", systemImage: "play.fill")
                }
                .controlSize(.small)
            }
        }
    }

    private var systemSoundRows: some View {
        SettingRow(title: "選擇音效", icon: "bell") {
            Picker("選擇音效", selection: $selectedSystemSound) {
                ForEach(SystemSound.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .labelsHidden()
            .frame(width: 140)
            .onChange(of: selectedSystemSound) { applySoundSettings() }
        }
    }

    @ViewBuilder
    private var ttsSoundRows: some View {
        SettingRow(title: "預設語音", icon: "text.bubble") {
            Picker("預設語音", selection: $selectedTTSAlarm) {
                ForEach(TTSAlarm.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .labelsHidden()
            .frame(width: 140)
            .onChange(of: selectedTTSAlarm) { applySoundSettings() }
        }

        VStack(alignment: .leading, spacing: Spacing.xs) {
            SettingRow(title: "自訂訊息", subtitle: "留空則使用預設語音", icon: "pencil.line") { EmptyView() }
            TextField("留空則使用預設語音", text: $customTTSMessage)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("自訂語音訊息")
                .onChange(of: customTTSMessage) { applySoundSettings() }
        }

        SettingRow(title: "語音", icon: "person.wave.2") {
            Picker("語音", selection: $selectedTTSVoice) {
                ForEach(TTSVoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .labelsHidden()
            .frame(width: 140)
            .onChange(of: selectedTTSVoice) { applySoundSettings() }
        }

        SettingRow(title: "語速", icon: "gauge.with.dots.needle.33percent") {
            HStack(spacing: Spacing.xs) {
                Text("慢").font(.system(size: 10)).foregroundStyle(.secondary)
                Slider(
                    value: Binding(get: { Double(ttsRate) }, set: { ttsRate = Int($0) }),
                    in: 100...400,
                    step: 25
                )
                .frame(width: 90)
                .accessibilityLabel("語速")
                .accessibilityValue("\(ttsRate)")
                Text("快").font(.system(size: 10)).foregroundStyle(.secondary)
                Text("\(ttsRate)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }
            .onChange(of: ttsRate) { applySoundSettings() }
        }
    }

    @ViewBuilder
    private var customSoundRows: some View {
        SettingRow(
            title: "音效檔案",
            subtitle: customSoundName.isEmpty ? "支援 MP3、WAV、AIFF 格式" : "已選: \(customSoundName)",
            icon: "music.note"
        ) {
            HStack(spacing: Spacing.sm) {
                if !customSoundName.isEmpty {
                    Button(action: clearCustomSound) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除自訂音效")
                }
                Button(action: selectCustomSoundFile) {
                    Label("選擇檔案…", systemImage: "folder")
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Sound Helpers

    private func syncSoundSettingsState() {
        // 先載入上次選的系統音效，避免目前為 TTS/自訂時，切回「系統」被預設值 glass 覆蓋
        selectedSystemSound = manager.settings.soundName
        switch manager.settings.effectiveSoundSource {
        case .system(let sound):
            soundSourceType = .system
            selectedSystemSound = sound
        case .tts(let alarm):
            soundSourceType = .tts
            selectedTTSAlarm = alarm
        case .custom(let bookmarkData, let name):
            soundSourceType = .custom
            customSoundBookmarkData = bookmarkData
            customSoundName = name
        }
        customTTSMessage = manager.settings.customTTSMessage ?? ""
        selectedTTSVoice = manager.settings.ttsVoice
        ttsRate = manager.settings.ttsRate
    }

    private func applySoundSettings() {
        switch soundSourceType {
        case .system:
            manager.settings.soundSource = .system(selectedSystemSound)
            manager.settings.soundName = selectedSystemSound
        case .tts:
            manager.settings.soundSource = .tts(selectedTTSAlarm)
            manager.settings.customTTSMessage = customTTSMessage.isEmpty ? nil : customTTSMessage
            manager.settings.ttsVoice = selectedTTSVoice
            manager.settings.ttsRate = ttsRate
        case .custom:
            if let bookmarkData = customSoundBookmarkData {
                manager.settings.soundSource = .custom(bookmarkData: bookmarkData, name: customSoundName)
            }
        }
    }

    private func previewCurrentSound() {
        switch soundSourceType {
        case .system:
            manager.previewSound(source: .system(selectedSystemSound))
        case .tts:
            manager.previewSound(source: .tts(selectedTTSAlarm))
        case .custom:
            if let bookmarkData = customSoundBookmarkData {
                manager.previewSound(source: .custom(bookmarkData: bookmarkData, name: customSoundName))
            } else {
                manager.playSound(name: SystemSound.glass.rawValue, volume: manager.settings.soundVolume)
            }
        }
    }

    private func selectCustomSoundFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .mp3, .aiff, .wav]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "選擇計時器完成時播放的音效檔案"
        panel.prompt = "選擇"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            customSoundBookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            customSoundName = url.lastPathComponent
            applySoundSettings()
        } catch {
            countdownSettingsLogger.error("Failed to create bookmark: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func clearCustomSound() {
        customSoundBookmarkData = nil
        customSoundName = ""
        soundSourceType = .system
        applySoundSettings()
    }

    // MARK: - Timer Actions

    private func submit() {
        isEditing ? saveEditedTimer() : addCustomTimer()
    }

    private func addCustomTimer() {
        guard parsedSeconds > 0 else { return }
        let added = manager.addTimer(
            label: newLabel.isEmpty ? "計時器" : newLabel,
            duration: parsedSeconds,
            colorHex: selectedColorHex,
            completionCommand: trimmedCommand.isEmpty ? nil : trimmedCommand
        )
        if added { resetForm() }
    }

    private func startEditing(_ timer: CountdownTimer) {
        editingTimerId = timer.id
        newLabel = timer.label
        selectedColorHex = timer.colorHex
        completionCommand = timer.completionCommand ?? ""
        timeInput = CountdownTimeInput.format(timer.duration)
    }

    private func cancelEdit() { resetForm() }

    private func resetForm() {
        editingTimerId = nil
        newLabel = ""
        timeInput = "5:00"
        selectedColorHex = CountdownColors.blue
        completionCommand = ""
    }

    private func saveEditedTimer() {
        guard let id = editingTimerId, parsedSeconds > 0 else { return }
        manager.updateTimer(
            id: id,
            label: newLabel.isEmpty ? "計時器" : newLabel,
            duration: parsedSeconds,
            colorHex: selectedColorHex,
            completionCommand: trimmedCommand.isEmpty ? nil : trimmedCommand
        )
        resetForm()
    }

    private func delete(_ timer: CountdownTimer) {
        if editingTimerId == timer.id { cancelEdit() }
        manager.removeTimer(id: timer.id)
    }
}
