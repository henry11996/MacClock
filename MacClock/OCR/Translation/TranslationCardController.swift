//
//  TranslationCardController.swift
//  MacClock
//
//  翻譯結果卡片：從瀏海（或選單列中央）下方降下，顯示原文與譯文
//  - 滑鼠在卡片上時一直停留；移開一段時間後自動收回
//  - 點卡片以外的地方、或按「關閉」立即收回
//

import AppKit
import SwiftUI

/// 卡片的位置計算（AppKit 全域座標）
nonisolated enum TranslationCardLayout {
    static let width: CGFloat = 440
    static let maxHeight: CGFloat = 420
    /// 與選單列之間的距離
    static let topGap: CGFloat = 6
    static let screenMargin: CGFloat = 12

    /// 卡片貼在選單列下方，以瀏海（或螢幕中央）為中心，不超出螢幕
    static func frame(screenFrame: CGRect, menuBarHeight: CGFloat, centerX: CGFloat, contentHeight: CGFloat) -> CGRect {
        let width = min(self.width, screenFrame.width - screenMargin * 2)
        let height = min(max(contentHeight, 1), maxHeight)
        let minX = screenFrame.minX + screenMargin
        let maxX = screenFrame.maxX - screenMargin - width
        let x = min(max(centerX - width / 2, minX), maxX)
        let top = screenFrame.maxY - menuBarHeight - topGap
        return CGRect(x: x, y: top - height, width: width, height: height)
    }
}

/// 卡片狀態
@MainActor
@Observable
final class TranslationCardState {
    enum Phase: Equatable {
        case translating(original: String)
        case done(TranslationResult)
        case failed(original: String, failure: TranslationFailure)
    }

    var phase: Phase = .translating(original: "")
    var isPresented = false
    var copiedLabel: String?
}

@MainActor
final class TranslationCardController {
    static let shared = TranslationCardController()

    /// 翻譯完成後，滑鼠不在卡片上時多久收回
    private static let idleDismissDelay: Duration = .seconds(10)
    private static let showAnimation: Animation = .spring(response: 0.38, dampingFraction: 0.8)
    private static let hideAnimation: Animation = .easeIn(duration: 0.18)
    private static let hideDuration: Duration = .milliseconds(220)
    private static let panelLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)

    private let state = TranslationCardState()
    private var panel: NSPanel?
    private var hosting: NSHostingView<TranslationCardView>?
    private var outsideClickMonitor: Any?
    private var dismissTask: Task<Void, Never>?
    private var presentTask: Task<Void, Never>?
    private var isPointerInside = false
    private var onRetry: (() -> Void)?

    private init() {}

    // MARK: - Public

    func showTranslating(original: String, onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        state.copiedLabel = nil
        state.phase = .translating(original: original)
        present()
    }

    func showResult(_ result: TranslationResult, autoCopied: Bool) {
        state.phase = .done(result)
        state.copiedLabel = autoCopied ? "已自動複製譯文" : nil
        relayout()
        scheduleIdleDismiss()
    }

    func showFailure(original: String, failure: TranslationFailure) {
        state.phase = .failed(original: original, failure: failure)
        relayout()
        scheduleIdleDismiss()
    }

    /// 卡片是否顯示中（含展開動畫尚未開始的瞬間）
    var isShowing: Bool { panel?.isVisible == true }

    func dismiss() {
        dismissTask?.cancel()
        presentTask?.cancel()
        presentTask = nil
        removeOutsideClickMonitor()
        guard isShowing else { return }
        withAnimation(Self.hideAnimation) { state.isPresented = false }
        let target = panel
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.hideDuration)
            guard !Task.isCancelled else { return }
            target?.orderOut(nil)
            self?.isPointerInside = false
        }
    }

    // MARK: - Actions from the view

    fileprivate func copy(_ text: String, label: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        state.copiedLabel = label
    }

    fileprivate func retry() {
        onRetry?()
    }

    /// 一鍵下載語言包，完成後自動重新翻譯
    fileprivate func downloadLanguages(_ failure: TranslationFailure) {
        guard case let .notInstalled(source, target) = failure else { return }
        dismissTask?.cancel()
        TranslationDownloadController.shared.download(source: source, target: target) { [weak self] success in
            if success {
                self?.retry()
            } else {
                // 使用者取消下載時，恢復自動收回
                self?.scheduleIdleDismiss()
            }
        }
    }

    fileprivate func openLanguageSettings() {
        if let url = TranslationService.languageSettingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    fileprivate func pointerInside(_ inside: Bool) {
        isPointerInside = inside
        if inside {
            dismissTask?.cancel()
        } else if case .translating = state.phase {
            // 翻譯中不自動收回
        } else {
            scheduleIdleDismiss()
        }
    }

    // MARK: - Presentation

    private func present() {
        dismissTask?.cancel()
        presentTask?.cancel()
        isPointerInside = panel.map { $0.isVisible && $0.frame.contains(NSEvent.mouseLocation) } ?? false
        let panel = panel ?? makePanel()
        self.panel = panel
        relayout()
        panel.orderFrontRegardless()
        installOutsideClickMonitor()
        if !state.isPresented {
            presentTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled, let self else { return }
                withAnimation(Self.showAnimation) { self.state.isPresented = true }
            }
        }
    }

    /// 內容高度改變時重新計算大小，上緣維持貼齊選單列
    private func relayout() {
        applyLayout()
        // SwiftUI 會在下一個 runloop 才套用狀態變更，再量一次確保高度正確
        Task { @MainActor [weak self] in self?.applyLayout() }
    }

    private func applyLayout() {
        guard let panel, let hosting, let geometry = Self.geometry() else { return }
        let contentHeight = hosting.fittingSize.height
        panel.setFrame(
            TranslationCardLayout.frame(
                screenFrame: geometry.screen.frame,
                menuBarHeight: geometry.menuBarHeight,
                centerX: geometry.centerX,
                contentHeight: contentHeight
            ),
            display: true
        )
    }

    private func scheduleIdleDismiss() {
        dismissTask?.cancel()
        guard !isPointerInside else { return }
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.idleDismissDelay)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        // 點擊其他 App 時收回（全域滑鼠事件不需要輔助使用權限）
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel, !panel.frame.contains(NSEvent.mouseLocation) else { return }
                self.dismiss()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: TranslationCardLayout.width, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = Self.panelLevel
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let hosting = NSHostingView(rootView: TranslationCardView(state: state, controller: self))
        panel.contentView = hosting
        self.hosting = hosting
        return panel
    }

    private struct Geometry {
        let screen: NSScreen
        let menuBarHeight: CGFloat
        let centerX: CGFloat
    }

    private static func geometry() -> Geometry? {
        if let screen = NotchGeometry.screenWithNotch {
            let notch = NotchGeometry.notchRect
            return Geometry(screen: screen, menuBarHeight: notch.height, centerX: notch.midX)
        }
        guard let screen = NSScreen.main else { return nil }
        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        return Geometry(screen: screen, menuBarHeight: menuBarHeight, centerX: screen.frame.midX)
    }
}

// MARK: - View

struct TranslationCardView: View {
    let state: TranslationCardState
    let controller: TranslationCardController

    var body: some View {
        let presented = state.isPresented
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(16)
        .frame(width: TranslationCardLayout.width, alignment: .leading)
        // 不透明黑底：與瀏海一致，也避免後方視窗的文字干擾閱讀
        .background(Color.black, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08)))
        .environment(\.colorScheme, .dark)
        .onHover { controller.pointerInside($0) }
        .offset(y: presented ? 0 : -24)
        .opacity(presented ? 1 : 0)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "translate")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ThemeColors.primary)
            Text(headerTitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                controller.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("關閉")
        }
    }

    private var headerTitle: String {
        switch state.phase {
        case .translating: return "翻譯中…"
        case let .done(result):
            return "\(TranslationService.displayName(forCode: result.sourceCode)) → \(result.target.displayName)"
        case .failed: return "無法翻譯"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case let .translating(original):
            originalText(original)
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("翻譯中…")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }

        case let .done(result):
            originalText(result.original)
            Divider()
            ScrollView {
                Text(result.translated)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: 240)
            .fixedSize(horizontal: false, vertical: true)
            actions(result)

        case let .failed(original, failure):
            originalText(original)
            Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if failure.canDownloadLanguages {
                    Button {
                        controller.downloadLanguages(failure)
                    } label: {
                        Label("下載語言包", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(CardPrimaryButtonStyle())
                    Button("在系統設定管理…") { controller.openLanguageSettings() }
                }
                Button("重試") { controller.retry() }
                Spacer()
                if !original.isEmpty {
                    Button("複製原文") { controller.copy(original, label: "已複製原文") }
                }
            }
            .controlSize(.small)
        }
    }

    private func originalText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actions(_ result: TranslationResult) -> some View {
        HStack(spacing: 8) {
            Button {
                controller.copy(result.translated, label: "已複製譯文")
            } label: {
                Label("複製譯文", systemImage: "doc.on.doc")
            }
            .buttonStyle(CardPrimaryButtonStyle())
            Button("複製原文") {
                controller.copy(result.original, label: "已複製原文")
            }
            Spacer()
            if let copied = state.copiedLabel {
                Label(copied, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
        .controlSize(.small)
    }
}

/// 卡片是不搶焦點的面板，系統的 borderedProminent 在非作用中視窗會變灰，因此自訂主要按鈕樣式
private struct CardPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                ThemeColors.primary.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}
