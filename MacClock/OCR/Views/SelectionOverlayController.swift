//
//  SelectionOverlayController.swift
//  MacClock
//
//  全螢幕半透明遮罩，讓使用者拖曳選取要辨識的區域
//  - 每個螢幕各一個 panel
//  - Esc 或右鍵取消
//

import AppKit

@MainActor
final class SelectionOverlayController {
    /// 回傳 AppKit 全域座標的選取框；nil 代表取消
    typealias Completion = (CGRect?) -> Void

    /// 逾時自動取消，避免遮罩卡住導致之後的快捷鍵都被擋下
    private static let timeout: Duration = .seconds(60)

    private var panels: [NSPanel] = []
    private var completion: Completion?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timeoutTask: Task<Void, Never>?

    var isActive: Bool { !panels.isEmpty }

    func begin(completion: @escaping Completion) {
        guard !isActive else { return }
        self.completion = completion

        panels = NSScreen.screens.map { screen in
            let panel = OverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.setFrame(screen.frame, display: false)

            let view = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onFinish = { [weak self, weak panel] localRect in
                guard let self, let panel else { return }
                self.finish(with: localRect.map { panel.convertToScreen($0) })
            }
            panel.contentView = view
            return panel
        }

        panels.forEach { $0.orderFrontRegardless() }
        // 讓滑鼠所在螢幕的 panel 成為 key，以接收 Esc
        let mouse = NSEvent.mouseLocation
        let keyPanel = panels.first { $0.frame.contains(mouse) } ?? panels.first
        // 啟用 App 才能確保 Esc 送到遮罩
        NSApp.activate(ignoringOtherApps: true)
        keyPanel?.makeKey()
        NSCursor.crosshair.push()
        installCancelTriggers()
    }

    /// 螢幕配置改變、切換桌面、逾時都自動取消
    private func installCancelTriggers() {
        let cancelHandler: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.cancel() }
        }
        let center = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        observers = [
            (center, center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil, queue: .main, using: cancelHandler
            )),
            (workspaceCenter, workspaceCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil, queue: .main, using: cancelHandler
            )),
        ]
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.timeout)
            guard !Task.isCancelled else { return }
            self?.cancel()
        }
    }

    private func removeCancelTriggers() {
        observers.forEach { center, token in center.removeObserver(token) }
        observers = []
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    func cancel() {
        finish(with: nil)
    }

    private func finish(with rect: CGRect?) {
        guard isActive else { return }
        removeCancelTriggers()
        NSCursor.pop()
        panels.forEach { $0.orderOut(nil) }
        panels = []
        let callback = completion
        completion = nil
        callback?(rect.flatMap { CaptureGeometry.isValidSelection($0) ? $0 : nil })
    }
}

/// 無邊框 panel 預設無法成為 key window，覆寫以接收鍵盤事件
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class SelectionOverlayView: NSView {
    var onFinish: ((CGRect?) -> Void)?

    private var dragStart: CGPoint?
    private var selection: CGRect = .null

    private static let dimColor = NSColor.black.withAlphaComponent(0.28)
    private static let borderColor = NSColor.white
    private static let escapeKeyCode: UInt16 = 0x35

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        Self.dimColor.setFill()
        bounds.fill()

        guard !selection.isNull, selection.width > 0, selection.height > 0 else { return }

        // 挖空選取區域並畫框
        NSColor.clear.setFill()
        selection.fill(using: .copy)
        Self.borderColor.setStroke()
        let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()

        drawSizeLabel()
    }

    private func drawSizeLabel() {
        let text = "\(Int(selection.width)) × \(Int(selection.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let padding: CGFloat = 4
        var origin = CGPoint(x: selection.minX, y: selection.minY - size.height - padding * 2 - 4)
        if origin.y < bounds.minY {
            origin.y = selection.minY + 4
        }
        let background = CGRect(
            x: origin.x, y: origin.y,
            width: size.width + padding * 2, height: size.height + padding * 2
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: background, xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: origin.x + padding, y: origin.y + padding), withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        selection = .null
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        selection = CaptureGeometry.rect(from: dragStart, to: current).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragStart = nil
        onFinish?(selection.isNull ? nil : selection)
    }

    override func rightMouseDown(with event: NSEvent) {
        onFinish?(nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            onFinish?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onFinish?(nil)
    }
}
