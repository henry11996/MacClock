//
//  TranslationDownloadController.swift
//  MacClock
//
//  一鍵下載翻譯語言包：開一個小視窗掛上 SwiftUI .translationTask，
//  由系統顯示下載確認畫面；下載完成後關閉視窗並通知呼叫端重新翻譯
//

import AppKit
import SwiftUI
import Translation

@MainActor
final class TranslationDownloadController: NSObject, NSWindowDelegate {
    static let shared = TranslationDownloadController()

    private var window: NSWindow?
    private var completion: ((Bool) -> Void)?
    /// 每次下載一個 token；舊視窗的 task 被取消後回呼時不會影響新的下載
    private var currentToken: UUID?

    /// - Parameter completion: 下載成功（語言已可用）時傳入 true
    func download(source: String, target: TranslationLanguage, completion: @escaping (Bool) -> Void) {
        finish(success: false)
        self.completion = completion
        let token = UUID()
        currentToken = token

        let configuration = TranslationSession.Configuration(
            source: Locale.Language(identifier: source),
            target: Locale.Language(identifier: target.rawValue)
        )
        let view = TranslationDownloadView(
            sourceName: TranslationService.displayName(forCode: source),
            targetName: target.displayName,
            configuration: configuration
        ) { [weak self] success in
            guard self?.currentToken == token else { return }
            self?.finish(success: success)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "下載翻譯語言"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        window.contentView = NSHostingView(rootView: view)
        window.center()
        self.window = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // 使用者自行關閉視窗視為取消
        let callback = completion
        completion = nil
        window = nil
        callback?(false)
    }

    private func finish(success: Bool) {
        let callback = completion
        completion = nil
        currentToken = nil
        if let window {
            window.delegate = nil
            window.close()
        }
        window = nil
        callback?(success)
    }
}

private struct TranslationDownloadView: View {
    let sourceName: String
    let targetName: String
    let configuration: TranslationSession.Configuration
    let onFinish: (Bool) -> Void

    @State private var message = "正在請系統準備語言包…"

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 28))
                .foregroundStyle(ThemeColors.primary)
            Text("\(sourceName) → \(targetName)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(message)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(width: 360, height: 150)
        // 系統會在需要時顯示下載確認畫面；完成後 prepareTranslation 才會返回
        .translationTask(configuration) { session in
            // 系統提供的 session 只在這個 task 內使用，不會被其他執行緒共用
            nonisolated(unsafe) let session = session
            do {
                try await session.prepareTranslation()
                onFinish(true)
            } catch {
                // 視窗被關閉導致 task 取消時，不顯示訊息也不回報
                if Task.isCancelled || error is CancellationError { return }
                message = "下載未完成：\(error.localizedDescription)"
                try? await Task.sleep(for: .seconds(2))
                onFinish(false)
            }
        }
    }
}
