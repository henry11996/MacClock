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
    private let hasNotch = NotchGeometry.hasNotch

    var body: some View {
        SettingsTabScaffold(onClose: onClose) {
            headerCard
            triggerCard
            translationCard
            recognitionCard
            resultCard
            appearanceCard
            privacyNote
        }
        .onAppear { hasPermission = ScreenCaptureService.hasPermission }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasPermission = ScreenCaptureService.hasPermission
        }
    }

    // MARK: - Header

    /// 功能摘要 + 權限狀態 + 立即擷取
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(ThemeColors.primary)
                    .frame(width: 44, height: 44)
                    .background(ThemeColors.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text("螢幕文字辨識")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(headerSubtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: Spacing.sm) {
                permissionBadge
                Spacer()
                if !hasPermission {
                    Button("前往授權…", action: requestPermission)
                }
                Button {
                    onClose()
                    coordinator.startCapture()
                } label: {
                    Label("立即擷取", systemImage: "viewfinder")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var headerSubtitle: String {
        let shortcut = settings.hotKeyEnabled ? "按 \(settings.hotKey.displayString) " : ""
        return "\(shortcut)框選畫面任意區域，文字會自動複製到剪貼簿。"
    }

    private var permissionBadge: some View {
        Label(
            hasPermission ? "螢幕錄製已授權" : "需要螢幕錄製權限",
            systemImage: hasPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
        )
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(hasPermission ? Color.green : Color.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((hasPermission ? Color.green : Color.orange).opacity(0.12), in: Capsule())
    }

    // MARK: - Cards

    private var triggerCard: some View {
        SettingsCard(title: "觸發方式", icon: "keyboard") {
            SettingRow(title: "全域快捷鍵", subtitle: "在任何 App 中都能使用", icon: "command") {
                Toggle("", isOn: binding(\.hotKeyEnabled))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if settings.hotKeyEnabled {
                SettingRow(title: "快捷鍵", subtitle: "點擊後按下新的組合鍵", icon: "keyboard.badge.ellipsis") {
                    HotKeyRecorder(hotKey: settings.hotKey) { newHotKey in
                        coordinator.update(settings.with(\.hotKey, newHotKey))
                    }
                }
                if !coordinator.isHotKeyRegistered {
                    Label("快捷鍵註冊失敗，可能已被其他 App 使用，請換一組", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.orange)
                }
            }

            Divider()
            SettingsFootnote(text: "也可用 macclock://ocr（翻譯：macclock://ocr?action=translate）或「捷徑」觸發。框選時按 Esc 或右鍵取消。")
        }
    }

    private var translationCard: some View {
        SettingsCard(title: "翻譯", icon: "translate") {
            SettingRow(
                title: "擷取並翻譯",
                subtitle: "框選後翻譯，結果顯示在瀏海下方",
                icon: "character.bubble"
            ) {
                Toggle("擷取並翻譯快捷鍵", isOn: binding(\.translateHotKeyEnabled))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if settings.translateHotKeyEnabled {
                SettingRow(title: "翻譯快捷鍵", subtitle: "點擊後按下新的組合鍵", icon: "keyboard.badge.ellipsis") {
                    HotKeyRecorder(hotKey: settings.translateHotKey) { newHotKey in
                        coordinator.update(settings.with(\.translateHotKey, newHotKey))
                    }
                }
                if let warning = translateHotKeyWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.orange)
                }
            }

            SettingRow(title: "翻譯成", subtitle: "原文已是此語言時會改翻成英文", icon: "globe") {
                Picker("翻譯成", selection: translationTargetBinding) {
                    ForEach(TranslationLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            SettingToggleRow(
                title: "自動複製譯文",
                subtitle: "翻譯完成後把譯文放到剪貼簿",
                icon: "doc.on.clipboard",
                isOn: binding(\.autoCopyTranslation)
            )

            Divider()

            HStack {
                SettingsFootnote(text: "使用 macOS 內建翻譯，在本機處理。第一次翻譯某種語言時，需要先下載該語言包。")
                Spacer()
                Button("管理翻譯語言…") {
                    if let url = TranslationService.languageSettingsURL {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }
        }
    }

    private var translateHotKeyWarning: String? {
        if settings.hotKeyEnabled, settings.translateHotKey == settings.hotKey {
            return "與「擷取文字」的快捷鍵相同，請換一組"
        }
        return coordinator.isTranslateHotKeyRegistered ? nil : "快捷鍵註冊失敗，可能已被其他 App 使用，請換一組"
    }

    private var translationTargetBinding: Binding<TranslationLanguage> {
        Binding(
            get: { TranslationLanguage(rawValue: coordinator.settings.translationTarget) ?? .defaultTarget },
            set: { coordinator.update(coordinator.settings.with(\.translationTarget, $0.rawValue)) }
        )
    }

    private var recognitionCard: some View {
        SettingsCard(title: "辨識", icon: "character.book.closed") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("辨識語言")
                    .font(.system(size: 13, design: .rounded))
                OCRLanguageChips(selected: settings.languages, onToggle: toggleLanguage)
                SettingsFootnote(text: settings.languages.isEmpty ? "未選擇語言，將自動偵測" : "可複選；全部取消時會自動偵測")
            }

            Divider()

            SettingRow(
                title: "辨識模式",
                subtitle: settings.accurateMode ? "較準確，適合小字與中文" : "速度較快，適合大字",
                icon: "speedometer"
            ) {
                Picker("", selection: binding(\.accurateMode)) {
                    Text("精準").tag(true)
                    Text("快速").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            SettingRow(
                title: "語言校正",
                subtitle: "依字典修正拼字；辨識程式碼或代號時建議關閉",
                icon: "textformat.abc.dottedunderline"
            ) {
                Toggle("", isOn: binding(\.usesLanguageCorrection))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    private var resultCard: some View {
        SettingsCard(title: "結果", icon: "doc.on.clipboard") {
            SettingRow(title: "保留換行", subtitle: "關閉時會把多行文字合併為一段", icon: "text.alignleft") {
                Toggle("", isOn: binding(\.keepLineBreaks))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            SettingRow(title: "完成時播放音效", icon: "speaker.wave.2") {
                Toggle("", isOn: binding(\.playSound))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            SettingRow(title: "顯示複製成功提示", subtitle: "辨識失敗的提示一律會顯示", icon: "bell.badge") {
                Toggle("", isOn: binding(\.showResultToast))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if settings.showResultToast {
                SettingRow(title: "提示位置", subtitle: toastPositionSubtitle, icon: "rectangle.topthird.inset.filled") {
                    Picker("", selection: binding(\.toastPosition)) {
                        ForEach(OCRToastPosition.allCases, id: \.self) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                HStack {
                    Spacer()
                    Button {
                        coordinator.previewToast()
                    } label: {
                        Label("預覽提示", systemImage: "play.circle")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var toastPositionSubtitle: String {
        switch settings.toastPosition {
        case .notchRight:
            return hasNotch ? "從瀏海裡往右滑出，幾秒後收回" : "此 Mac 沒有瀏海，會顯示在畫面上方"
        case .notchBelow:
            return hasNotch ? "從瀏海往下彈出，幾秒後收回" : "此 Mac 沒有瀏海，會顯示在畫面上方"
        case .topCenter:
            return "顯示在畫面上方中央，可看到較多預覽文字"
        }
    }

    private var appearanceCard: some View {
        SettingsCard(title: "框選外觀", icon: "circle.lefthalf.filled") {
            SettingRow(title: "遮罩深淺", subtitle: "只影響顯示，不影響辨識結果", icon: "square.filled.on.square") {
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
            OCRDimPreview(opacity: settings.drawnDimOpacity)
        }
    }

    private var dimOpacityLabel: String {
        let percent = Int((OCRSettings.clampedDimOpacity(settings.overlayDimOpacity) * 100).rounded())
        return percent == 0 ? "不變暗" : "\(percent)%"
    }

    private var privacyNote: some View {
        Label("使用 macOS 內建 Vision 文字辨識，完全在本機處理，不會上傳或儲存截圖。", systemImage: "lock.shield")
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(.secondary)
    }

    // MARK: - Actions

    private func requestPermission() {
        if !ScreenCaptureService.requestPermission() {
            ScreenCaptureService.openPrivacySettings()
        }
        hasPermission = ScreenCaptureService.hasPermission
    }

    private func toggleLanguage(_ language: OCRLanguage) {
        let current = settings.languages
        let isOn = !current.contains(language)
        coordinator.update(settings.with(\.languages, OCRLanguage.toggled(language, isOn: isOn, in: current)))
    }

    // MARK: - Bindings

    private func binding<Value>(_ keyPath: WritableKeyPath<OCRSettings, Value>) -> Binding<Value> {
        Binding(
            get: { coordinator.settings[keyPath: keyPath] },
            set: { coordinator.update(coordinator.settings.with(keyPath, $0)) }
        )
    }
}
