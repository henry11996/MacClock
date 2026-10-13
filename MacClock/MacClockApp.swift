//
//  MacClockApp.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import AppKit
import SwiftUI

@main
struct MacClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .handlesExternalEvents(matching: ["*"])
    }
}

/// Settings tab identifier
enum SettingsTab: String, CaseIterable {
    case general = "general"
    case clock = "clock"
    case pomodoro = "pomodoro"
    case countdown = "countdown"
    case schedule = "schedule"
    case ocr = "ocr"

    var title: String {
        switch self {
        case .general: return "一般"
        case .clock: return "時鐘"
        case .pomodoro: return "番茄鐘"
        case .countdown: return "計時器"
        case .schedule: return "排程"
        case .ocr: return "文字辨識"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .clock: return "clock"
        case .pomodoro: return "timer"
        case .countdown: return "hourglass"
        case .schedule: return "calendar.badge.clock"
        case .ocr: return "text.viewfinder"
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: NSPanel!
    var fullScreenWindow: NSWindow?
    var settingsWindow: NSWindow?
    var settingsInitialTab: SettingsTab = .general

    // Notch mode panels
    var notchLeftPanel: NSPanel?
    var notchRightPanel: NSPanel?

    // UserDefaults keys for position memory
    private let windowPositionXKey = "windowPositionX"
    private let windowPositionYKey = "windowPositionY"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the floating panel with titled style for proper glass effect background sampling
        // Fixed width of 320, height adjusts dynamically based on content
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure panel properties
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.delegate = self

        // Hide titlebar while keeping its functionality for glass effect
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Prevent panel from hiding when app loses focus
        panel.hidesOnDeactivate = false

        // Create the SwiftUI content view with glassEffect
        let hostingView = NSHostingView(rootView: ContentView())
        // Allow SwiftUI to dynamically resize the window based on content
        hostingView.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hostingView

        // Restore saved position or use default top-right corner
        if UserDefaults.standard.object(forKey: windowPositionXKey) != nil {
            let x = UserDefaults.standard.double(forKey: windowPositionXKey)
            let y = UserDefaults.standard.double(forKey: windowPositionYKey)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel.frame
            let x = screenFrame.maxX - panelFrame.width - 20
            let y = screenFrame.maxY - panelFrame.height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Register for full-screen notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enterFullScreen),
            name: .enterPomodoroFullScreen,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(exitFullScreen),
            name: .exitPomodoroFullScreen,
            object: nil
        )

        // Configure background refresh service
        BackgroundRefreshService.shared.configure(panel: panel)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundRefreshSettingsChanged),
            name: .backgroundRefreshSettingsChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettings(_:)),
            name: .showSettings,
            object: nil
        )

        // Initialize ScheduleManager to start checking schedules
        _ = ScheduleManager.shared

        // Register the screen OCR global hotkey
        OCRCoordinator.shared.start()

        // Notch mode observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotchModeChanged(_:)),
            name: .notchModeChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged), // Reuse reposition logic
            name: .fontScaleChanged,
            object: nil
        )

        // Activate notch mode if previously enabled (only on notch Macs)
        if NotchGeometry.hasNotch && PomodoroSettings.load().notchModeEnabled {
            activateNotchMode()
        } else {
            panel.orderFront(nil)
        }
    }

    @MainActor @objc private func handleBackgroundRefreshSettingsChanged() {
        let settings = PomodoroSettings.load()
        BackgroundRefreshService.shared.setFPS(
            settings.backgroundUpdateFPS,
            liquidGlassEnabled: settings.liquidGlassEnabled
        )
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == panel else { return }
        
        // Save position to UserDefaults
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: windowPositionXKey)
        UserDefaults.standard.set(origin.y, forKey: windowPositionYKey)
    }

    // MARK: - Full Screen Management

    @MainActor @objc private func enterFullScreen() {
        guard fullScreenWindow == nil, let screen = NSScreen.main else { return }

        let screenFrame = screen.frame

        // Create full screen window
        fullScreenWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        guard let window = fullScreenWindow else { return }

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false

        let fullScreenView = PomodoroFullScreenView(timer: PomodoroTimer.shared) {
            NotificationCenter.default.post(name: .exitPomodoroFullScreen, object: nil)
        }

        let hostingView = NSHostingView(rootView: fullScreenView)
        window.contentView = hostingView

        window.setFrame(screenFrame, display: true)
        window.makeKeyAndOrderFront(nil)

        // Hide the widget panel and notch panels while in full screen
        panel.orderOut(nil)
        notchLeftPanel?.orderOut(nil)
        notchRightPanel?.orderOut(nil)
    }

    @MainActor @objc private func exitFullScreen() {
        fullScreenWindow?.orderOut(nil)
        fullScreenWindow = nil

        // Restore appropriate panels based on notch mode
        if PomodoroTimer.shared.settings.notchModeEnabled {
            notchLeftPanel?.orderFront(nil)
            notchRightPanel?.orderFront(nil)
        } else {
            panel.orderFront(nil)
        }
    }

    // MARK: - Notch Mode Management

    @MainActor func activateNotchMode() {
        // Hide the main floating widget
        panel.orderOut(nil)

        let barHeight = NotchGeometry.menuBarHeight

        // Create left panel (clock + pomodoro) - Width will adapt
        let leftFrame = NotchGeometry.leftPanelFrame(panelWidth: 100)
        let leftPanel = createNotchPanel(frame: leftFrame)
        let leftHosting = NSHostingView(rootView: NotchClockView())
        leftHosting.sizingOptions = [.intrinsicContentSize]
        leftHosting.frame = NSRect(x: 0, y: 0, width: leftFrame.width, height: barHeight)
        leftPanel.contentView = leftHosting
        leftPanel.delegate = self // Handle anchoring
        leftPanel.orderFront(nil)
        notchLeftPanel = leftPanel

        // Create right panel (countdown timers) - Width will adapt
        let rightFrame = NotchGeometry.rightPanelFrame(panelWidth: 100)
        let rightPanel = createNotchPanel(frame: rightFrame)
        let rightHosting = NSHostingView(rootView: NotchCountdownView())
        rightHosting.sizingOptions = [.intrinsicContentSize]
        rightHosting.frame = NSRect(x: 0, y: 0, width: rightFrame.width, height: barHeight)
        rightPanel.contentView = rightHosting
        rightPanel.delegate = self
        rightPanel.orderFront(nil)
        notchRightPanel = rightPanel

        // Configure background refresh for notch panels
        BackgroundRefreshService.shared.configureNotchPanels(left: leftPanel, right: rightPanel)
    }

    // Handle dynamic resizing for notch panels
    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // If left panel resizes, we must adjust its origin so it stays anchored to the right (at the notch)
        if window == notchLeftPanel {
            let newWidth = window.frame.width
            let newFrame = NotchGeometry.leftPanelFrame(panelWidth: newWidth)
            if window.frame.origin.x != newFrame.origin.x {
                window.setFrameOrigin(newFrame.origin)
            }
        }
        
        // If right panel resizes (vertical expansion), anchor to top
        if window == notchRightPanel {
            let topY = NotchGeometry.notchRect.maxY
            let newOriginY = topY - window.frame.height
            if window.frame.origin.y != newOriginY {
                window.setFrameOrigin(NSPoint(x: window.frame.origin.x, y: newOriginY))
            }
        }
    }

    @MainActor func deactivateNotchMode() {
        // Remove notch panels
        notchLeftPanel?.orderOut(nil)
        notchLeftPanel = nil
        notchRightPanel?.orderOut(nil)
        notchRightPanel = nil

        // Clear notch panels from background refresh
        BackgroundRefreshService.shared.configureNotchPanels(left: nil, right: nil)

        // Restore the main floating widget
        panel.orderFront(nil)
    }

    @MainActor func repositionNotchPanels() {
        if let left = notchLeftPanel {
            let leftFrame = NotchGeometry.leftPanelFrame(panelWidth: left.frame.width)
            left.setFrame(leftFrame, display: true)
        }
        if let right = notchRightPanel {
            let rightFrame = NotchGeometry.rightPanelFrame(panelWidth: right.frame.width)
            right.setFrame(rightFrame, display: true)
        }
    }

    /// Window level above statusBar so panels stay visible when menu bar auto-hides
    private static let notchPanelLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

    private func createNotchPanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = Self.notchPanelLevel
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        return panel
    }

    @MainActor @objc private func handleNotchModeChanged(_ notification: Notification) {
        guard NotchGeometry.hasNotch else { return }

        let enabled: Bool
        if let value = notification.object as? Bool {
            // From context menu, URL scheme, or settings toggle
            enabled = value
        } else {
            // Fallback: read from current settings
            enabled = PomodoroTimer.shared.settings.notchModeEnabled
        }

        // Update settings if triggered externally (context menu / URL scheme)
        if PomodoroTimer.shared.settings.notchModeEnabled != enabled {
            var settings = PomodoroTimer.shared.settings
            settings.notchModeEnabled = enabled
            PomodoroTimer.shared.settings = settings
        }

        let isCurrentlyActive = notchLeftPanel != nil
        if enabled && !isCurrentlyActive {
            activateNotchMode()
        } else if !enabled && isCurrentlyActive {
            deactivateNotchMode()
        }
    }

    @MainActor @objc private func handleScreenParametersChanged() {
        if PomodoroTimer.shared.settings.notchModeEnabled {
            repositionNotchPanels()
        }
    }

    // MARK: - Settings Window

    @MainActor @objc private func showSettings(_ notification: Notification) {
        // Determine which tab to show
        let tab = (notification.object as? SettingsTab) ?? .general
        settingsInitialTab = tab

        // If window already exists, bring it to front
        if let window = settingsWindow {
            // Update the tab in existing window
            if let hostingView = window.contentView as? NSHostingView<UnifiedSettingsView> {
                hostingView.rootView.selectedTab = tab
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create new settings window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "設定"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        // Create unified settings view
        let contentView = UnifiedSettingsView(
            initialTab: tab,
            onClose: { [weak self] in
                self?.settingsWindow?.close()
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView

        settingsWindow = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(hostingView)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
            // 保險：若關閉視窗時正在錄製快捷鍵，確保全域快捷鍵恢復
            OCRCoordinator.shared.resumeHotKey()
        }
    }

    // MARK: - URL Scheme Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let result = URLSchemeHandler.handle(url)
            print("[MacClock URL] \(result)")

            // For list/status commands, copy result to clipboard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let action = components?.queryItems?.first(where: { $0.name == "action" })?.value

            if action == "list" || url.host == "status" {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
                print("[MacClock URL] Result copied to clipboard: \(result)")
            }
        }
    }
}
