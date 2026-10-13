//
//  OCRToastController.swift
//  MacClock
//
//  辨識完成後短暫顯示的結果提示
//  - 瀏海右側：黑底、與選單列同高，看起來像從瀏海延伸出來
//  - 畫面上方：毛玻璃卡片（沒有瀏海的螢幕也使用這個樣式）
//

import AppKit
import SwiftUI

@MainActor
final class OCRToastController {
    enum Style {
        case success
        case warning
    }

    private static let displayDuration: Duration = .seconds(2.5)
    private static let fadeInDuration: TimeInterval = 0.15
    private static let fadeOutDuration: TimeInterval = 0.25
    private static let expandAnimation: Animation = .spring(response: 0.42, dampingFraction: 0.72)
    private static let collapseAnimation: Animation = .spring(response: 0.32, dampingFraction: 0.95)
    private static let collapseDuration: Duration = .milliseconds(450)
    private static let previewLimit = 120
    static let width: CGFloat = 340
    /// 瀏海提示的最大寬度（含圖示與標題）
    static let notchMaxWidth: CGFloat = 400
    /// 高於瀏海面板（statusBar + 1），確保蓋在倒數計時面板上
    private static let notchLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(
        title: String,
        message: String,
        style: Style,
        position: OCRToastPosition,
        near rect: CGRect?
    ) {
        dismissTask?.cancel()
        panel?.orderOut(nil)
        panel = nil

        let preview = Self.preview(of: message)
        if position == .notchRight, let screen = NotchGeometry.screenWithNotch,
           Self.isOnScreen(rect, screen: screen) {
            presentNotch(title: title, message: preview, style: style, screen: screen)
        } else {
            presentCard(title: title, message: preview, style: style, near: rect)
        }
    }

    /// 瀏海樣式：從瀏海右緣彈出（彈簧展開），停留後縮回瀏海
    private func presentNotch(title: String, message: String, style: Style, screen: NSScreen) {
        let state = NotchToastState()
        let newPanel = makeNotchPanel(title: title, message: message, style: style, screen: screen, state: state)
        newPanel.orderFrontRegardless()
        panel = newPanel

        dismissTask = Task { [weak self] in
            // 等一個 runloop 讓收合狀態先畫出來，展開動畫才會從瀏海開始
            try? await Task.sleep(for: .milliseconds(16))
            withAnimation(Self.expandAnimation) { state.isExpanded = true }

            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled else { return }
            withAnimation(Self.collapseAnimation) { state.isExpanded = false }

            try? await Task.sleep(for: Self.collapseDuration)
            self?.remove(newPanel)
        }
    }

    /// 卡片樣式：淡入淡出
    private func presentCard(title: String, message: String, style: Style, near rect: CGRect?) {
        let newPanel = makeCardPanel(title: title, message: message, style: style, near: rect)
        newPanel.alphaValue = 0
        newPanel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInDuration
            newPanel.animator().alphaValue = 1
        }
        panel = newPanel

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled else { return }
            self?.fadeOut(newPanel)
        }
    }

    /// 文字過長時截斷，只顯示單行預覽
    static func preview(of text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > previewLimit else { return singleLine }
        return String(singleLine.prefix(previewLimit)) + "…"
    }

    /// 框選區不在瀏海螢幕上時（例如在外接螢幕框選），改用畫面上方卡片，避免提示出現在另一個螢幕
    private static func isOnScreen(_ rect: CGRect?, screen: NSScreen) -> Bool {
        guard let rect else { return true }
        return screen.frame.intersects(rect)
    }

    // MARK: - Private

    private func remove(_ target: NSPanel) {
        target.orderOut(nil)
        if panel === target {
            panel = nil
        }
    }

    private func fadeOut(_ target: NSPanel) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeOutDuration
            target.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.remove(target)
            }
        })
    }

    private func makeNotchPanel(
        title: String,
        message: String,
        style: Style,
        screen: NSScreen,
        state: NotchToastState
    ) -> NSPanel {
        let notch = NotchGeometry.notchRect
        let content = OCRNotchToastContent(
            title: title,
            message: message,
            style: style,
            leadingInset: OCRToastLayout.notchOverlap
        )
        // 先量內容的理想寬度，再依螢幕可用寬度決定展開後的大小
        let idealWidth = NSHostingView(rootView: content.fixedSize()).fittingSize.width
        let baseFrame = OCRToastLayout.notchRightFrame(
            notchRect: notch,
            screenFrame: screen.frame,
            contentWidth: min(idealWidth, Self.notchMaxWidth)
        )
        // 展開時往下多長出一點，像從瀏海掉出來的通知
        let frame = OCRToastLayout.expandedNotchFrame(baseFrame, extraHeight: OCRNotchToastView.extraHeight)
        let hosting = NSHostingView(rootView: OCRNotchToastView(
            content: content,
            state: state,
            expandedSize: frame.size,
            collapsedHeight: notch.height,
            collapsedWidth: OCRToastLayout.notchOverlap
        ))
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        let newPanel = makeBasePanel(frame: frame, level: Self.notchLevel, hasShadow: false)
        newPanel.contentView = hosting
        return newPanel
    }

    private func makeCardPanel(title: String, message: String, style: Style, near rect: CGRect?) -> NSPanel {
        let hosting = NSHostingView(rootView: OCRCardToastView(title: title, message: message, style: style))
        hosting.sizingOptions = [.intrinsicContentSize]
        let size = hosting.fittingSize
        let screen = rect.flatMap { r in NSScreen.screens.first { $0.frame.intersects(r) } }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let origin = screen.map { OCRToastLayout.topCenterOrigin(size: size, visibleFrame: $0.visibleFrame) } ?? .zero
        let newPanel = makeBasePanel(frame: NSRect(origin: origin, size: size), level: .statusBar, hasShadow: true)
        newPanel.contentView = hosting
        return newPanel
    }

    private func makeBasePanel(frame: NSRect, level: NSWindow.Level, hasShadow: Bool) -> NSPanel {
        let newPanel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.level = level
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = hasShadow
        newPanel.ignoresMouseEvents = true
        newPanel.isReleasedWhenClosed = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient]
        return newPanel
    }
}

// MARK: - Views

private extension OCRToastController.Style {
    var iconName: String { self == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill" }
    var tint: Color { self == .success ? ThemeColors.primary : .orange }
}

/// 瀏海提示的展開狀態（由 controller 以動畫切換）
@MainActor
@Observable
private final class NotchToastState {
    var isExpanded = false
}

/// 瀏海提示的內容列（固定寬度，展開時以裁切呈現，避免文字跟著寬度重排）
private struct OCRNotchToastContent: View {
    let title: String
    let message: String
    let style: OCRToastController.Style
    let leadingInset: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: style.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(style.tint)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .layoutPriority(1)
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 200, alignment: .leading)
            }
        }
        .padding(.leading, leadingInset + 10)
        .padding(.trailing, 14)
    }
}

/// 瀏海右側樣式：黑色形狀從瀏海右緣長出（變寬、往下長），收合時縮回瀏海
private struct OCRNotchToastView: View {
    static let extraHeight: CGFloat = 6
    private static let expandedRadius: CGFloat = 14
    private static let collapsedRadius: CGFloat = 6

    let content: OCRNotchToastContent
    let state: NotchToastState
    let expandedSize: CGSize
    let collapsedHeight: CGFloat
    /// 收合時藏在瀏海後方的寬度
    let collapsedWidth: CGFloat

    var body: some View {
        let expanded = state.isExpanded
        let radius = expanded ? Self.expandedRadius : Self.collapsedRadius
        ZStack(alignment: .leading) {
            Color.black
            content
                .frame(width: expandedSize.width, height: expandedSize.height, alignment: .leading)
                .opacity(expanded ? 1 : 0)
                .blur(radius: expanded ? 0 : 6)
                .scaleEffect(expanded ? 1 : 0.85, anchor: .leading)
        }
        .frame(
            width: expanded ? expandedSize.width : collapsedWidth,
            height: expanded ? expandedSize.height : collapsedHeight,
            alignment: .leading
        )
        .clipShape(.rect(bottomLeadingRadius: radius, bottomTrailingRadius: radius))
        .frame(width: expandedSize.width, height: expandedSize.height, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

/// 畫面上方樣式：毛玻璃卡片，可顯示多行預覽
private struct OCRCardToastView: View {
    let title: String
    let message: String
    let style: OCRToastController.Style

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: style.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(style.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(width: OCRToastController.width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
