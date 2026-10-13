//
//  OCRToastController.swift
//  MacClock
//
//  辨識完成後在畫面上方短暫顯示的結果提示
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
    private static let previewLimit = 120
    static let width: CGFloat = 340

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(title: String, message: String, style: Style, near rect: CGRect?) {
        dismissTask?.cancel()
        panel?.orderOut(nil)

        let view = OCRToastView(
            title: title,
            message: Self.preview(of: message),
            style: style
        )
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.intrinsicContentSize]
        let size = hosting.fittingSize

        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .statusBar
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.ignoresMouseEvents = true
        newPanel.isReleasedWhenClosed = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        newPanel.contentView = hosting
        newPanel.setFrameOrigin(Self.origin(for: size, near: rect))
        newPanel.orderFrontRegardless()
        panel = newPanel

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }
    }

    /// 文字過長時截斷，只顯示預覽
    static func preview(of text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > previewLimit else { return singleLine }
        return String(singleLine.prefix(previewLimit)) + "…"
    }

    /// 顯示在選取區域所在螢幕的上方中央
    private static func origin(for size: CGSize, near rect: CGRect?) -> CGPoint {
        let screen = rect.flatMap { r in NSScreen.screens.first { $0.frame.intersects(r) } }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return .zero }
        return CGPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 24)
    }
}

private struct OCRToastView: View {
    let title: String
    let message: String
    let style: OCRToastController.Style

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: style == .success ? "text.viewfinder" : "exclamationmark.triangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(style == .success ? ThemeColors.primary : Color.orange)
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
