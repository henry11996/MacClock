//
//  OCRCoordinator.swift
//  MacClock
//
//  串接整個流程：快捷鍵 → 選取區域 → 擷取畫面 → Vision 辨識 → 複製到剪貼簿
//

import AppKit
import OSLog

@MainActor
@Observable
final class OCRCoordinator {
    static let shared = OCRCoordinator()

    private static let logger = Logger(subsystem: "com.henry.MacClock", category: "OCR")
    private static let permissionRequestedKey = "ocrScreenCapturePermissionRequested"

    private(set) var settings: OCRSettings
    private(set) var isCapturing = false
    /// 擷取後要做什麼
    enum CaptureMode {
        /// 辨識文字並複製
        case copyText
        /// 辨識後翻譯，結果顯示在瀏海下方的卡片
        case translate
    }

    /// 目前快捷鍵是否註冊成功（失敗通常是被其他 App 佔用）
    private(set) var isHotKeyRegistered = false
    private(set) var isTranslateHotKeyRegistered = false
    private(set) var lastRecognizedText: String?

    /// 進行中的翻譯；新的翻譯開始時取消舊的，避免較晚回來的舊結果蓋掉新結果
    private var translationTask: Task<Void, Never>?
    private var translationGeneration = 0

    private let overlay = SelectionOverlayController()
    private let toast = OCRToastController()

    private init() {
        settings = OCRSettings.load()
    }

    /// App 啟動時呼叫
    func start() {
        registerHotKeys()
    }

    func update(_ newSettings: OCRSettings) {
        guard newSettings != settings else { return }
        let hotKeyChanged = newSettings.hotKey != settings.hotKey
            || newSettings.hotKeyEnabled != settings.hotKeyEnabled
            || newSettings.translateHotKey != settings.translateHotKey
            || newSettings.translateHotKeyEnabled != settings.translateHotKeyEnabled
        settings = newSettings
        newSettings.save()
        if hotKeyChanged {
            registerHotKeys()
        }
    }

    /// 錄製新快捷鍵時暫停全域快捷鍵，避免被攔截
    func suspendHotKey() {
        GlobalHotKeyService.shared.unregisterAll()
        isHotKeyRegistered = false
        isTranslateHotKeyRegistered = false
    }

    func resumeHotKey() {
        registerHotKeys()
    }

    // MARK: - Capture Flow

    func startCapture(mode: CaptureMode = .copyText) {
        guard !isCapturing, !overlay.isActive else { return }

        guard ScreenCaptureService.hasPermission else {
            handleMissingPermission()
            return
        }

        isCapturing = true
        overlay.begin(dimOpacity: settings.drawnDimOpacity) { [weak self] rect in
            guard let self else { return }
            guard let rect else {
                self.isCapturing = false
                return
            }
            Task { await self.recognize(in: rect, mode: mode) }
        }
    }

    private func recognize(in rect: CGRect, mode: CaptureMode) async {
        defer { isCapturing = false }
        let currentSettings = settings
        do {
            let image = try await ScreenCaptureService.capture(appKitRect: rect)
            ClotheslineStore.shared.hangCapture(image)
            let fragments = try await TextRecognizer.recognize(
                image,
                options: TextRecognitionOptions(settings: currentSettings)
            )
            let text = OCRTextFormatter.format(fragments, keepLineBreaks: currentSettings.keepLineBreaks)
            switch mode {
            case .copyText:
                deliver(text, settings: currentSettings, near: rect)
            case .translate:
                guard !text.isEmpty else {
                    showToast(title: "未辨識到文字", message: "請選取包含清楚文字的區域", style: .warning, near: rect)
                    return
                }
                translate(text)
            }
        } catch ScreenCaptureError.permissionDenied {
            handleMissingPermission()
        } catch {
            Self.logger.error("OCR failed: \(error.localizedDescription, privacy: .public)")
            showToast(title: "文字辨識失敗", message: error.localizedDescription, style: .warning, near: rect)
        }
    }

    // MARK: - Translation

    /// 翻譯並顯示在瀏海下方的卡片；重試時使用同一段文字
    private func translate(_ text: String) {
        lastRecognizedText = text
        let card = TranslationCardController.shared
        card.showTranslating(original: text) { [weak self] in
            self?.translate(text)
        }
        let target = TranslationLanguage(rawValue: settings.translationTarget) ?? .defaultTarget
        let autoCopy = settings.autoCopyTranslation
        translationTask?.cancel()
        translationGeneration += 1
        let generation = translationGeneration
        translationTask = Task { [weak self] in
            let outcome = await TranslationService.translate(text, preferredTarget: target)
            // 已有更新的翻譯、或使用者已關閉卡片時，不更新畫面也不動剪貼簿
            guard let self, !Task.isCancelled, generation == self.translationGeneration, card.isShowing else { return }
            switch outcome {
            case let .success(result):
                if autoCopy {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(result.translated, forType: .string)
                }
                card.showResult(result, autoCopied: autoCopy)
            case let .failure(failure):
                Self.logger.error("Translation failed: \(failure.message, privacy: .public)")
                card.showFailure(original: text, failure: failure)
            }
        }
    }

    private func deliver(_ text: String, settings: OCRSettings, near rect: CGRect) {
        guard !text.isEmpty else {
            showToast(title: "未辨識到文字", message: "請選取包含清楚文字的區域", style: .warning, near: rect)
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastRecognizedText = text

        if settings.playSound {
            NSSound(named: "Tink")?.play()
        }
        showToast(title: "已複製 \(text.count) 個字元", message: text, style: .success, near: rect)
    }

    private func showToast(title: String, message: String, style: OCRToastController.Style, near rect: CGRect?) {
        guard settings.showResultToast || style == .warning else { return }
        toast.show(title: title, message: message, style: style, position: settings.toastPosition, near: rect)
    }

    /// 設定頁「試試看」：用目前設定顯示一次範例提示
    func previewToast() {
        toast.show(
            title: "已複製 12 個字元",
            message: "Hello 範例文字 MacClock",
            style: .success,
            position: settings.toastPosition,
            near: nil
        )
    }

    private func handleMissingPermission() {
        // 第一次只跳系統詢問；之後才顯示自訂說明，避免同時出現兩個視窗
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.permissionRequestedKey) else {
            defaults.set(true, forKey: Self.permissionRequestedKey)
            ScreenCaptureService.requestPermission()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "需要螢幕錄製權限"
        alert.informativeText = "MacClock 需要「螢幕與系統錄音」權限才能擷取畫面文字。\n"
            + "請在系統設定中允許 MacClock，然後重新啟動 App。\n\n辨識完全在本機進行，畫面不會被上傳或儲存。"
        alert.addButton(withTitle: "打開系統設定")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            ScreenCaptureService.openPrivacySettings()
        }
    }

    private func registerHotKeys() {
        let service = GlobalHotKeyService.shared
        if settings.hotKeyEnabled {
            isHotKeyRegistered = service.register(settings.hotKey, for: .captureText) { [weak self] in
                self?.startCapture(mode: .copyText)
            }
        } else {
            service.unregister(.captureText)
            isHotKeyRegistered = false
        }

        // 與擷取文字的快捷鍵相同時不註冊，避免一個按鍵觸發兩種動作
        if settings.translateHotKeyEnabled,
           !(settings.hotKeyEnabled && settings.translateHotKey == settings.hotKey) {
            isTranslateHotKeyRegistered = service.register(settings.translateHotKey, for: .translate) { [weak self] in
                self?.startCapture(mode: .translate)
            }
        } else {
            service.unregister(.translate)
            isTranslateHotKeyRegistered = false
        }
    }
}
