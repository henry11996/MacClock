//
//  OCRSettingsTab.swift
//  MacClock
//
//  文字辨識（OCR）設定分頁
//

import AppKit
import SwiftUI

struct OCRSettingsTab: View {
    let onClose: () -> Void
    var coordinator = OCRCoordinator.shared

    @State private var hasPermission = ScreenCaptureService.hasPermission

    private var settings: OCRSettings { coordinator.settings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                captureCard
                appearanceCard
                languageCard
                outputCard
                privacyNote
            }
            .padding(Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Spacer()
                    Button("關閉", action: onClose)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(Spacing.lg)
            }
            .background(.regularMaterial)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasPermission = ScreenCaptureService.hasPermission
        }
    }

    // MARK: - Cards

    private var captureCard: some View {
        SettingsCard(title: "擷取", icon: "text.viewfinder") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("螢幕錄製權限", systemImage: hasPermission ? "checkmark.shield" : "exclamationmark.shield")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(hasPermission ? Color.primary : Color.orange)
                    Text(hasPermission ? "已授權" : "尚未授權，擷取前需先允許")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !hasPermission {
                    Button("授權…") {
                        if !ScreenCaptureService.requestPermission() {
                            ScreenCaptureService.openPrivacySettings()
                        }
                        hasPermission = ScreenCaptureService.hasPermission
                    }
                }
            }

            Divider().padding(.vertical, Spacing.xs)

            Toggle(isOn: binding(\.hotKeyEnabled)) {
                Label("全域快捷鍵", systemImage: "keyboard")
                    .font(.system(size: 13, design: .rounded))
            }
            .toggleStyle(.switch)

            if settings.hotKeyEnabled {
                HStack {
                    Text("快捷鍵")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    HotKeyRecorder(hotKey: settings.hotKey) { newHotKey in
                        coordinator.update(settings.with(\.hotKey, newHotKey))
                    }
                }
                if !coordinator.isHotKeyRegistered {
                    Text("快捷鍵註冊失敗，可能已被其他 App 使用，請換一組")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.orange)
                }
            }

            Divider().padding(.vertical, Spacing.xs)

            HStack {
                Text("也可使用 macclock://ocr 觸發")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    onClose()
                    coordinator.startCapture()
                } label: {
                    Label("立即擷取文字", systemImage: "viewfinder")
                }
            }
        }
    }

    private var appearanceCard: some View {
        SettingsCard(title: "框選外觀", icon: "circle.lefthalf.filled") {
            HStack {
                Label("遮罩深淺", systemImage: "square.filled.on.square")
                    .font(.system(size: 13, design: .rounded))
                Spacer()
                Text(dimOpacityLabel)
                    .font(.system(size: 12, design: .rounded).monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Slider(
                value: binding(\.overlayDimOpacity),
                in: 0...OCRSettings.maxOverlayDimOpacity,
                step: 0.02
            ) {
                EmptyView()
            } minimumValueLabel: {
                Image(systemName: "sun.max").font(.system(size: 10))
            } maximumValueLabel: {
                Image(systemName: "moon.fill").font(.system(size: 10))
            }
            .accessibilityLabel("遮罩深淺")
            .accessibilityValue(dimOpacityLabel)
            dimPreview
            Text("框選時畫面變暗的程度，只影響顯示，不影響辨識結果")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    private var dimOpacityLabel: String {
        let percent = Int((OCRSettings.clampedDimOpacity(settings.overlayDimOpacity) * 100).rounded())
        return percent == 0 ? "不變暗" : "\(percent)%"
    }

    /// 預覽：外圍套用遮罩、中間為選取區
    private var dimPreview: some View {
        ZStack {
            LinearGradient(
                colors: [ThemeColors.primary.opacity(0.6), Color.orange.opacity(0.6)],
                startPoint: .leading, endPoint: .trailing
            )
            Color.black.opacity(settings.drawnDimOpacity)
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: 2)
                                .frame(width: 120, height: 28)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white, lineWidth: 1)
                .frame(width: 120, height: 28)
            Text("範例文字")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var languageCard: some View {
        SettingsCard(title: "辨識", icon: "character.book.closed") {
            Text("辨識語言（未勾選任何語言時自動偵測）")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)

            ForEach(OCRLanguage.allCases, id: \.self) { language in
                Toggle(language.displayName, isOn: languageBinding(language))
                    .font(.system(size: 13, design: .rounded))
            }

            Divider().padding(.vertical, Spacing.xs)

            Picker("辨識模式", selection: binding(\.accurateMode)) {
                Text("精準").tag(true)
                Text("快速").tag(false)
            }
            .pickerStyle(.segmented)

            Toggle(isOn: binding(\.usesLanguageCorrection)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("語言校正")
                        .font(.system(size: 13, design: .rounded))
                    Text("依字典修正拼字；辨識程式碼或代號時建議關閉")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    private var outputCard: some View {
        SettingsCard(title: "輸出", icon: "doc.on.clipboard") {
            Toggle(isOn: binding(\.keepLineBreaks)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("保留換行")
                        .font(.system(size: 13, design: .rounded))
                    Text("關閉時會把多行文字合併為一段")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            Toggle("顯示辨識結果提示", isOn: binding(\.showResultToast))
                .toggleStyle(.switch)
                .font(.system(size: 13, design: .rounded))

            Toggle("完成時播放音效", isOn: binding(\.playSound))
                .toggleStyle(.switch)
                .font(.system(size: 13, design: .rounded))
        }
    }

    private var privacyNote: some View {
        Label("使用 macOS 內建 Vision 文字辨識，完全在本機處理，不會上傳或儲存截圖。", systemImage: "lock.shield")
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(.secondary)
    }

    // MARK: - Bindings

    private func binding<Value>(_ keyPath: WritableKeyPath<OCRSettings, Value>) -> Binding<Value> {
        Binding(
            get: { coordinator.settings[keyPath: keyPath] },
            set: { coordinator.update(coordinator.settings.with(keyPath, $0)) }
        )
    }

    private func languageBinding(_ language: OCRLanguage) -> Binding<Bool> {
        Binding(
            get: { coordinator.settings.languages.contains(language) },
            set: { isOn in
                let current = coordinator.settings.languages.filter { $0 != language }
                // 依 allCases 順序排列，維持穩定的優先順序
                let updated = isOn
                    ? OCRLanguage.allCases.filter { current.contains($0) || $0 == language }
                    : current
                coordinator.update(coordinator.settings.with(\.languages, updated))
            }
        )
    }
}

// MARK: - Hot Key Recorder

/// 點擊後按下新的組合鍵即可錄製；Esc 取消
private struct HotKeyRecorder: View {
    let hotKey: OCRHotKey
    let onChange: (OCRHotKey) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var hint: String?

    private static let escapeKeyCode: UInt16 = 0x35

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(isRecording ? "請按下組合鍵…" : hotKey.displayString)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? ThemeColors.primary : nil)

            if let hint {
                Text(hint)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.orange)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        guard monitor == nil else { return }
        hint = nil
        isRecording = true
        OCRCoordinator.shared.suspendHotKey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil  // 吞掉按鍵，避免觸發其他動作
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        let wasRecording = isRecording
        monitor = nil
        isRecording = false
        if wasRecording {
            OCRCoordinator.shared.resumeHotKey()
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            stopRecording()
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyName = OCRHotKey.specialKeyName(for: event.keyCode)
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? ""
        let candidate = OCRHotKey(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: OCRHotKey.carbonModifiers(
                command: flags.contains(.command),
                shift: flags.contains(.shift),
                option: flags.contains(.option),
                control: flags.contains(.control)
            ),
            keyDisplay: keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard candidate.isValid else {
            hint = "需包含 ⌘、⌃ 或 ⌥"
            return
        }
        hint = nil
        // 先更新設定再恢復註冊，才會註冊到新的組合鍵
        onChange(candidate)
        stopRecording()
    }
}
