//
//  BackgroundRefreshService.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/3.
//

import AppKit
import Combine
import QuartzCore

/// Service that periodically refreshes the panel to update Liquid Glass background
@MainActor
final class BackgroundRefreshService {
    static let shared = BackgroundRefreshService()

    private weak var panel: NSPanel?
    private weak var notchLeftPanel: NSPanel?
    private weak var notchRightPanel: NSPanel?
    private var timerCancellable: AnyCancellable?

    private init() {}

    func configure(panel: NSPanel) {
        self.panel = panel
        let settings = PomodoroSettings.load()
        setFPS(settings.backgroundUpdateFPS, liquidGlassEnabled: settings.liquidGlassEnabled)
    }

    func configureNotchPanels(left: NSPanel?, right: NSPanel?) {
        self.notchLeftPanel = left
        self.notchRightPanel = right
    }

    func setFPS(_ fps: BackgroundUpdateFPS, liquidGlassEnabled: Bool) {
        stop()

        guard liquidGlassEnabled, let interval = fps.timerInterval else { return }

        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshPanel()
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func refreshPanel() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if let panel {
            panel.invalidateShadow()
            invalidateLayerTree(panel.contentView?.layer)
            panel.contentView?.needsDisplay = true
            panel.viewsNeedDisplay = true
            panel.display()
        }

        for notchPanel in [notchLeftPanel, notchRightPanel] {
            guard let notchPanel else { continue }
            notchPanel.invalidateShadow()
            invalidateLayerTree(notchPanel.contentView?.layer)
            notchPanel.contentView?.needsDisplay = true
            notchPanel.viewsNeedDisplay = true
            notchPanel.display()
        }

        CATransaction.commit()
    }

    private func invalidateLayerTree(_ layer: CALayer?) {
        guard let layer else { return }
        layer.setNeedsDisplay()
        layer.displayIfNeeded()
        layer.sublayers?.forEach { invalidateLayerTree($0) }
    }
}
