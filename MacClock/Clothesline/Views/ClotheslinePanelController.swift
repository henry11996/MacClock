//
//  ClotheslinePanelController.swift
//  MacClock
//
//  晾衣繩面板：滑鼠停在瀏海（或選單列中央）時從瀏海下方降下，離開後收回；
//  有新截圖時自動降下幾秒
//

import AppKit
import SwiftUI

@MainActor
final class ClotheslinePanelController {
    static let shared = ClotheslinePanelController()

    /// 滑鼠需在觸發區停留多久才展開（避免經過選單列就誤觸）
    private static let restDelay: Duration = .milliseconds(350)
    /// 離開後多久收回
    private static let leaveDelay: Duration = .milliseconds(600)
    /// 新截圖掛上時展開的時間
    private static let arrivalDisplay: Duration = .seconds(3)
    private static let revealAnimation: Animation = .spring(response: 0.42, dampingFraction: 0.78)
    private static let hideAnimation: Animation = .easeIn(duration: 0.22)
    private static let hideDuration: Duration = .milliseconds(260)
    /// 高於一般視窗；低於瀏海面板，讓瀏海上的時鐘維持在最上層
    private static let panelLevel = NSWindow.Level.statusBar

    private let store = ClotheslineStore.shared
    private let presentation = ClotheslinePresentation()
    private var panel: NSPanel?
    private var monitors: [Any] = []
    private var pendingTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var isPointerInside = false
    private var lastArrivalCount = 0
    /// 螢幕配置只在變更時重新計算，避免每次滑鼠移動都查詢 NSScreen
    private var cachedGeometry: Geometry?
    private var screenObserver: NSObjectProtocol?

    private init() {}

    func start() {
        installMouseMonitors()
        observeArrivals()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cachedGeometry = nil }
        }
    }

    // MARK: - Mouse tracking

    private func installMouseMonitors() {
        guard monitors.isEmpty else { return }
        let handler: (NSEvent) -> Void = { [weak self] _ in
            self?.pointerMoved(to: NSEvent.mouseLocation)
        }
        // 全域監聽滑鼠移動不需要輔助使用權限（只有鍵盤事件需要）
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func pointerMoved(to point: CGPoint) {
        guard store.settings.isEnabled else { return }
        // 收合中且滑鼠不在螢幕頂端附近時，不做任何計算
        if !presentation.isRevealed, !isPointerInside,
           let cached = cachedGeometry, point.y < cached.trigger.minY - 2 {
            return
        }
        guard let geometry = currentGeometry() else { return }

        if presentation.isRevealed, let panel {
            let inside = ClotheslineLayout.keepsOpen(mouse: point, panelFrame: panel.frame, triggerRect: geometry.trigger)
            if inside != isPointerInside {
                isPointerInside = inside
                inside ? pendingTask?.cancel() : schedule(after: Self.leaveDelay) { $0.hide() }
            }
        } else if geometry.trigger.contains(point) {
            // 繩子上沒有東西時，停在瀏海不展開，避免誤觸
            guard !isPointerInside, !store.items.isEmpty else { return }
            isPointerInside = true
            schedule(after: Self.restDelay) { $0.reveal() }
        } else if isPointerInside {
            isPointerInside = false
            pendingTask?.cancel()
        }
    }

    // MARK: - New captures

    private func observeArrivals() {
        withObservationTracking {
            _ = store.arrivalCount
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.handleArrival()
                self.observeArrivals()
            }
        }
    }

    private func handleArrival() {
        guard store.arrivalCount != lastArrivalCount else { return }
        lastArrivalCount = store.arrivalCount
        guard store.settings.isEnabled else { return }
        if presentation.isRevealed {
            resize()
        } else {
            reveal()
        }
        // 使用者沒有把滑鼠移上來，就幾秒後自動收回
        if !isPointerInside {
            schedule(after: Self.arrivalDisplay) { $0.hide() }
        }
    }

    // MARK: - Show / hide

    private func reveal() {
        pendingTask?.cancel()
        guard let geometry = currentGeometry() else { return }
        let panel = panel ?? makePanel()
        panel.setFrame(frame(for: geometry), display: false)
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
        self.panel = panel
        // 等一個 runloop 讓收合狀態先畫出來，降下的動畫才看得到
        revealTask?.cancel()
        revealTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled, let self else { return }
            withAnimation(Self.revealAnimation) { self.presentation.isRevealed = true }
        }
    }

    private func hide() {
        // 展開動畫尚未開始時也要能取消，否則面板會在收回後又被展開
        revealTask?.cancel()
        revealTask = nil
        guard presentation.isRevealed || panel?.isVisible == true else { return }
        isPointerInside = false
        withAnimation(Self.hideAnimation) { presentation.isRevealed = false }
        let target = panel
        schedule(after: Self.hideDuration) { _ in
            target?.ignoresMouseEvents = true
            target?.orderOut(nil)
        }
    }

    private func resize() {
        guard let panel, let geometry = currentGeometry() else { return }
        panel.setFrame(frame(for: geometry), display: true, animate: true)
    }

    private func schedule(after delay: Duration, _ action: @escaping @MainActor (ClotheslinePanelController) -> Void) {
        pendingTask?.cancel()
        pendingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            action(self)
        }
    }

    // MARK: - Geometry

    private struct Geometry {
        let screen: NSScreen
        let menuBarHeight: CGFloat
        let trigger: CGRect
        let centerX: CGFloat
    }

    private func currentGeometry() -> Geometry? {
        if let cachedGeometry { return cachedGeometry }
        let geometry = computeGeometry()
        cachedGeometry = geometry
        return geometry
    }

    /// 有瀏海時以瀏海螢幕為準，否則用主螢幕
    private func computeGeometry() -> Geometry? {
        if let screen = NotchGeometry.screenWithNotch {
            let notch = NotchGeometry.notchRect
            return Geometry(screen: screen, menuBarHeight: notch.height, trigger: notch, centerX: notch.midX)
        }
        guard let screen = NSScreen.main else { return nil }
        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        let trigger = ClotheslineLayout.triggerRect(screenFrame: screen.frame, menuBarHeight: menuBarHeight, notchRect: nil)
        return Geometry(screen: screen, menuBarHeight: menuBarHeight, trigger: trigger, centerX: screen.frame.midX)
    }

    private func frame(for geometry: Geometry) -> CGRect {
        ClotheslineLayout.panelFrame(
            screenFrame: geometry.screen.frame,
            menuBarHeight: geometry.menuBarHeight,
            centerX: geometry.centerX,
            itemCount: store.items.count
        )
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
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
        panel.contentView = NSHostingView(rootView: ClotheslineView(store: store, presentation: presentation))
        return panel
    }
}
