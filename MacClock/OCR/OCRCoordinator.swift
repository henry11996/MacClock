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
    /// 目前快捷鍵是否註冊成功（失敗通常是被其他 App 佔用）
    private(set) var isHotKeyRegistered = false
    private(set) var lastRecognizedText: String?

    private let overlay = SelectionOverlayController()
    private let toast = OCRToastController()

    private init() {
        settings = OCRSettings.load()
    }

    /// App 啟動時呼叫
    func start() {
        registerHotKey()
    }

    func update(_ newSettings: OCRSettings) {
        guard newSettings != settings else { return }
        let hotKeyChanged = newSettings.hotKey != settings.hotKey
            || newSettings.hotKeyEnabled != settings.hotKeyEnabled
        settings = newSettings
        newSettings.save()
        if hotKeyChanged {
            registerHotKey()
        }
    }

    /// 錄製新快捷鍵時暫停全域快捷鍵，避免被攔截
    func suspendHotKey() {
        GlobalHotKeyService.shared.unregister()
        isHotKeyRegistered = false
    }

    func resumeHotKey() {
        registerHotKey()
    }

    // MARK: - Capture Flow

    func startCapture() {
        guard !isCapturing, !overlay.isActive else { return }

        guard ScreenCaptureService.hasPermission else {
            handleMissingPermission()
            return
        }

        isCapturing = true
        overlay.begin { [weak self] rect in
            guard let self else { return }
            guard let rect else {
                self.isCapturing = false
                return
            }
            Task { await self.recognize(in: rect) }
        }
    }

    private func recognize(in rect: CGRect) async {
        defer { isCapturing = false }
        let currentSettings = settings
        do {
            let image = try await ScreenCaptureService.capture(appKitRect: rect)
            let fragments = try await TextRecognizer.recognize(
                image,
                options: TextRecognitionOptions(settings: currentSettings)
            )
            let text = OCRTextFormatter.format(fragments, keepLineBreaks: currentSettings.keepLineBreaks)
            deliver(text, settings: currentSettings, near: rect)
        } catch ScreenCaptureError.permissionDenied {
            handleMissingPermission()
        } catch {
            Self.logger.error("OCR failed: \(error.localizedDescription, privacy: .public)")
            showToast(title: "文字辨識失敗", message: error.localizedDescription, style: .warning, near: rect)
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
        toast.show(title: title, message: message, style: style, near: rect)
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

    private func registerHotKey() {
        guard settings.hotKeyEnabled else {
            GlobalHotKeyService.shared.unregister()
            isHotKeyRegistered = false
            return
        }
        isHotKeyRegistered = GlobalHotKeyService.shared.register(settings.hotKey) { [weak self] in
            self?.startCapture()
        }
    }
}
