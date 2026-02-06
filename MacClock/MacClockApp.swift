//
//  MacClockApp.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

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

    var title: String {
        switch self {
        case .general: return "一般"
        case .clock: return "時鐘"
        case .pomodoro: return "番茄鐘"
        case .countdown: return "計時器"
        case .schedule: return "排程"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .clock: return "clock"
        case .pomodoro: return "timer"
        case .countdown: return "hourglass"
        case .schedule: return "calendar.badge.clock"
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: NSPanel!
    var fullScreenWindow: NSWindow?
    var settingsWindow: NSWindow?
    var settingsInitialTab: SettingsTab = .general

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

        // Show the panel
        panel.orderFront(nil)

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

        // Hide the widget panel while in full screen
        panel.orderOut(nil)
    }

    @MainActor @objc private func exitFullScreen() {
        fullScreenWindow?.orderOut(nil)
        fullScreenWindow = nil

        // Show the widget panel again
        panel.orderFront(nil)
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

// MARK: - Unified Settings View

/// Unified settings view with tabs for all settings
struct UnifiedSettingsView: View {
    @State var selectedTab: SettingsTab
    let onClose: () -> Void

    init(initialTab: SettingsTab = .general, onClose: @escaping () -> Void) {
        _selectedTab = State(initialValue: initialTab)
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Tab content
            switch selectedTab {
            case .general:
                GeneralSettingsTab(onClose: onClose)
            case .clock:
                ClockSettingsTab(onClose: onClose)
            case .pomodoro:
                PomodoroSettingsTab(onClose: onClose)
            case .countdown:
                CountdownSettingsTab(onClose: onClose)
            case .schedule:
                ScheduleSettingsTab(onClose: onClose)
            }
        }
        .frame(minWidth: 520, minHeight: 400)
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsTab: View {
    let onClose: () -> Void
    var timer = PomodoroTimer.shared

    @State private var liquidGlassEnabled: Bool
    @State private var backgroundUpdateFPS: BackgroundUpdateFPS
    @State private var launchAtLogin: Bool

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let settings = PomodoroTimer.shared.settings
        _liquidGlassEnabled = State(initialValue: settings.liquidGlassEnabled)
        _backgroundUpdateFPS = State(initialValue: settings.backgroundUpdateFPS)
        _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Visual Effects Card
                SettingsCard(title: "視覺效果", icon: "sparkles") {
                    Toggle(isOn: $liquidGlassEnabled) {
                        Label("Liquid Glass 效果", systemImage: "drop.fill")
                            .font(.system(size: 13, design: .rounded))
                    }
                    .toggleStyle(.switch)

                    if liquidGlassEnabled {
                        Divider()
                            .padding(.vertical, Spacing.xs)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Label("背景更新 (FPS)", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)

                            Picker("背景更新頻率", selection: $backgroundUpdateFPS) {
                                ForEach(BackgroundUpdateFPS.allCases, id: \.self) { fps in
                                    Text(fps.displayName).tag(fps)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                }

                // System Card
                SettingsCard(title: "系統", icon: "gearshape") {
                    Toggle(isOn: $launchAtLogin) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("開機時啟動", systemImage: "power")
                                .font(.system(size: 13, design: .rounded))
                            Text("登入時自動啟動 MacClock")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
                }

                Spacer()
            }
            .padding(Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Spacer()
                    Button("關閉") {
                        saveSettings()
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(Spacing.lg)
            }
            .background(.regularMaterial)
        }
        .onChange(of: liquidGlassEnabled) { saveSettings() }
        .onChange(of: backgroundUpdateFPS) { saveSettings() }
    }

    private func saveSettings() {
        var settings = timer.settings
        settings.liquidGlassEnabled = liquidGlassEnabled
        settings.backgroundUpdateFPS = backgroundUpdateFPS
        timer.settings = settings

        NotificationCenter.default.post(name: .backgroundRefreshSettingsChanged, object: nil)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Clock Settings Tab

private struct ClockSettingsTab: View {
    let onClose: () -> Void
    var timer = PomodoroTimer.shared

    @State private var clockStyle: ClockStyle
    @State private var clockFontScale: CGFloat

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let settings = PomodoroTimer.shared.settings
        _clockStyle = State(initialValue: settings.clockStyle)
        _clockFontScale = State(initialValue: settings.clockFontScale)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Clock Style Card
                SettingsCard(title: "時鐘樣式", icon: "clock") {
                    ForEach(ClockStyle.allCases, id: \.self) { style in
                        clockStyleRow(style)
                    }

                    Divider()
                        .padding(.vertical, Spacing.xs)

                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Date-Time-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("系統日期與時間設定", systemImage: "clock.badge.gearshape")
                                .font(.system(size: 13, design: .rounded))
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Clock Font Size Card
                SettingsCard(title: "字體大小", icon: "textformat.size") {
                    fontScaleRow("時鐘", icon: "clock", value: $clockFontScale)
                }

                Spacer()
            }
            .padding(Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Spacer()
                    Button("關閉") {
                        saveSettings()
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(Spacing.lg)
            }
            .background(.regularMaterial)
        }
        .onChange(of: clockStyle) { saveSettings() }
        .onChange(of: clockFontScale) { saveSettings() }
    }

    @ViewBuilder
    private func clockStyleRow(_ style: ClockStyle) -> some View {
        Button {
            clockStyle = style
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .font(.system(size: 13, design: .rounded))
                    Text(style.description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if clockStyle == style {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ThemeColors.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fontScaleRow(_ label: String, icon: String, value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.system(size: 13, design: .rounded))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(width: 50, alignment: .trailing)
            }
            HStack(spacing: Spacing.md) {
                Text("小")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Slider(value: value, in: 0.8...5.0, step: 0.1)
                    .controlSize(.small)
                Text("大")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func saveSettings() {
        var settings = timer.settings
        settings.clockStyle = clockStyle
        settings.clockFontScale = clockFontScale
        timer.settings = settings
    }
}

// MARK: - Pomodoro Settings Tab

private struct PomodoroSettingsTab: View {
    let onClose: () -> Void
    var timer = PomodoroTimer.shared

    @State private var pomodoroPosition: PomodoroPosition
    @State private var fontScale: CGFloat
    @State private var workMinutes: Double
    @State private var shortBreakMinutes: Double
    @State private var longBreakMinutes: Double
    @State private var pomodorosUntilLongBreak: Int
    @State private var soundEnabled: Bool
    @State private var soundVolume: Float
    @State private var autoStartBreaks: Bool
    @State private var autoStartWork: Bool
    @State private var showResetConfirmation = false

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let settings = PomodoroTimer.shared.settings
        _pomodoroPosition = State(initialValue: settings.pomodoroPosition)
        _fontScale = State(initialValue: settings.fontScale)
        _workMinutes = State(initialValue: settings.workDuration / 60)
        _shortBreakMinutes = State(initialValue: settings.shortBreakDuration / 60)
        _longBreakMinutes = State(initialValue: settings.longBreakDuration / 60)
        _pomodorosUntilLongBreak = State(initialValue: settings.pomodorosUntilLongBreak)
        _soundEnabled = State(initialValue: settings.soundEnabled)
        _soundVolume = State(initialValue: settings.soundVolume)
        _autoStartBreaks = State(initialValue: settings.autoStartBreaks)
        _autoStartWork = State(initialValue: settings.autoStartWork)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Position Card
                SettingsCard(title: "位置", icon: "square.stack") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Picker("番茄鐘位置", selection: $pomodoroPosition) {
                            Text("隱藏").tag(PomodoroPosition.hidden)
                            Text("時鐘上方").tag(PomodoroPosition.above)
                            Text("時鐘下方").tag(PomodoroPosition.below)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                // Font Size Card
                SettingsCard(title: "字體大小", icon: "textformat.size") {
                    fontScaleRow("番茄鐘", icon: "timer", value: $fontScale)
                }

                // Time settings
                SettingsCard(title: "時間設定", icon: "clock") {
                    HStack {
                        Label("工作", systemImage: "brain.head.profile")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(ThemeColors.workPhase)
                        Spacer()
                        Stepper(value: $workMinutes, in: 1...60, step: 5) {
                            Text(formatMinutes(workMinutes))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }

                    HStack {
                        Label("短休息", systemImage: "cup.and.saucer")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(ThemeColors.shortBreak)
                        Spacer()
                        Stepper(value: $shortBreakMinutes, in: 1...30, step: 1) {
                            Text(formatMinutes(shortBreakMinutes))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }

                    HStack {
                        Label("長休息", systemImage: "figure.walk")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(ThemeColors.longBreak)
                        Spacer()
                        Stepper(value: $longBreakMinutes, in: 5...60, step: 5) {
                            Text(formatMinutes(longBreakMinutes))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }

                    Divider()
                        .padding(.vertical, Spacing.xs)

                    HStack {
                        Label("長休息間隔", systemImage: "repeat")
                            .font(.system(size: 13, design: .rounded))
                        Spacer()
                        Stepper(value: $pomodorosUntilLongBreak, in: 2...8) {
                            Text("\(pomodorosUntilLongBreak) 個")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }

                // Sound settings
                SettingsCard(title: "聲音設定", icon: "speaker.wave.2") {
                    Toggle(isOn: $soundEnabled) {
                        Text("啟用提示音")
                            .font(.system(size: 13, design: .rounded))
                    }
                    .toggleStyle(.switch)

                    if soundEnabled {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Slider(value: $soundVolume, in: 0...1)
                                .controlSize(.small)
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Button {
                                NotificationService.shared.playCompletionSound(volume: soundVolume)
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(ThemeColors.primary)
                            }
                            .buttonStyle(InteractiveButtonStyle())
                        }
                        .padding(.top, Spacing.xs)
                    }
                }

                // Auto-start settings
                SettingsCard(title: "自動開始", icon: "arrow.triangle.2.circlepath") {
                    Toggle(isOn: $autoStartBreaks) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("自動開始休息")
                                .font(.system(size: 13, design: .rounded))
                            Text("工作結束後自動進入休息")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: $autoStartWork) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("自動開始工作")
                                .font(.system(size: 13, design: .rounded))
                            Text("休息結束後自動進入工作")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }

                Spacer()
            }
            .padding(Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button {
                        showResetConfirmation = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("重置進度")
                        }
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.red)
                    }
                    .buttonStyle(InteractiveButtonStyle())

                    Spacer()

                    Button("關閉") {
                        saveSettings()
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(Spacing.lg)
            }
            .background(.regularMaterial)
        }
        .confirmationDialog(
            "確定要重置所有進度嗎？",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置", role: .destructive) {
                timer.resetAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這將清除所有已完成的番茄鐘和專注時間記錄。")
        }
        .onChange(of: pomodoroPosition) { saveSettings() }
        .onChange(of: fontScale) { saveSettings() }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        "\(Int(minutes)) 分鐘"
    }

    @ViewBuilder
    private func fontScaleRow(_ label: String, icon: String, value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.system(size: 13, design: .rounded))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(width: 50, alignment: .trailing)
            }
            HStack(spacing: Spacing.md) {
                Text("小")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Slider(value: value, in: 0.8...5.0, step: 0.1)
                    .controlSize(.small)
                Text("大")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func saveSettings() {
        timer.settings = PomodoroSettings(
            workDuration: workMinutes * 60,
            shortBreakDuration: shortBreakMinutes * 60,
            longBreakDuration: longBreakMinutes * 60,
            pomodorosUntilLongBreak: pomodorosUntilLongBreak,
            soundEnabled: soundEnabled,
            soundVolume: soundVolume,
            autoStartBreaks: autoStartBreaks,
            autoStartWork: autoStartWork,
            fontScale: fontScale,
            clockFontScale: timer.settings.clockFontScale,
            clockStyle: timer.settings.clockStyle,
            pomodoroPosition: pomodoroPosition,
            liquidGlassEnabled: timer.settings.liquidGlassEnabled,
            backgroundUpdateFPS: timer.settings.backgroundUpdateFPS
        )
    }
}

// MARK: - Countdown Settings Tab

private struct CountdownSettingsTab: View {
    let onClose: () -> Void
    var manager = CountdownManager.shared

    @State private var isEnabled: Bool
    @State private var countdownPosition: CountdownPosition
    @State private var countdownFontScale: CGFloat
    @State private var newLabel: String = ""
    @State private var timeInput: String = "5:00"
    @State private var selectedColorHex: UInt = CountdownColors.blue
    @State private var completionCommand: String = ""
    @State private var editingTimerId: UUID?
    @State private var showAdvanced: Bool = true

    // Sound settings UI state
    @State private var soundSourceType: SoundSourceType = .system
    @State private var selectedSystemSound: SystemSound = .glass
    @State private var selectedTTSAlarm: TTSAlarm = .timeUp
    @State private var customTTSMessage: String = ""
    @State private var selectedTTSVoice: TTSVoice = .meiJia
    @State private var ttsRate: Int = 200
    @State private var customSoundName: String = ""
    @State private var customSoundBookmarkData: Data?

    @State private var autoCollapseEnabled: Bool

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let settings = CountdownManager.shared.settings
        _isEnabled = State(initialValue: settings.isEnabled)
        _countdownPosition = State(initialValue: settings.position)
        _countdownFontScale = State(initialValue: settings.fontScale)
        _autoCollapseEnabled = State(initialValue: settings.autoCollapseEnabled)
    }

    private var parsedSeconds: TimeInterval {
        parseTimeInput(timeInput)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Enable Toggle
                SettingsCard(title: "功能", icon: "switch.2") {
                    Toggle(isOn: $isEnabled) {
                        Label("啟用計時器", systemImage: "hourglass")
                            .font(.system(size: 13, design: .rounded))
                    }
                    .toggleStyle(.switch)
                    .onChange(of: isEnabled) {
                        manager.settings.isEnabled = isEnabled
                    }

                    if isEnabled {
                        Divider()
                            .padding(.vertical, Spacing.xs)

                        Toggle(isOn: $autoCollapseEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("完成時才顯示")
                                    .font(.system(size: 13, design: .rounded))
                                Text("計時器完成時展開列表，10 秒後自動收起")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .onChange(of: autoCollapseEnabled) {
                            manager.settings.autoCollapseEnabled = autoCollapseEnabled
                        }
                    }
                }

                // Position Card
                SettingsCard(title: "位置", icon: "square.stack") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Picker("計時器位置", selection: $countdownPosition) {
                            Text("隱藏").tag(CountdownPosition.hidden)
                            Text("時鐘上方").tag(CountdownPosition.above)
                            Text("時鐘下方").tag(CountdownPosition.below)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                // Font Size Card
                SettingsCard(title: "字體大小", icon: "textformat.size") {
                    fontScaleRow("計時器", icon: "hourglass", value: $countdownFontScale)
                }

                // Quick add chips
                quickAddChips

                // Timer input
                timerInputSection

                // Existing timers
                if !manager.timers.isEmpty {
                    existingTimersSection
                }

                // Advanced settings (collapsible)
                advancedSettingsSection

                Spacer()
            }
            .padding(Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Spacer()
                    Button("關閉") {
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(Spacing.lg)
            }
            .background(.regularMaterial)
        }
        .onChange(of: countdownPosition) { savePositionSettings() }
        .onChange(of: countdownFontScale) { savePositionSettings() }
    }

    private func savePositionSettings() {
        var settings = manager.settings
        settings.position = countdownPosition
        settings.fontScale = countdownFontScale
        manager.settings = settings
    }

    @ViewBuilder
    private func fontScaleRow(_ label: String, icon: String, value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.system(size: 13, design: .rounded))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(width: 50, alignment: .trailing)
            }
            HStack(spacing: Spacing.md) {
                Text("小")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Slider(value: value, in: 0.8...5.0, step: 0.1)
                    .controlSize(.small)
                Text("大")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Parse Time Input

    private func parseTimeInput(_ input: String) -> TimeInterval {
        let parts = input.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 1: return TimeInterval(parts[0] * 60) // Just minutes
        case 2: return TimeInterval(parts[0] * 60 + parts[1]) // MM:SS
        case 3: return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2]) // HH:MM:SS
        default: return 0
        }
    }

    private func formatSecondsToInput(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Quick Add Chips

    private var quickAddChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach([("1m", 60), ("3m", 180), ("5m", 300), ("10m", 600), ("15m", 900), ("25m", 1500), ("30m", 1800), ("1h", 3600)], id: \.0) { label, seconds in
                    Button {
                        timeInput = formatSecondsToInput(TimeInterval(seconds))
                    } label: {
                        Text(label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(parsedSeconds == TimeInterval(seconds) ? Color.accentColor : Color.primary.opacity(0.08))
                            .foregroundStyle(parsedSeconds == TimeInterval(seconds) ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Timer Input Section

    private var timerInputSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Time and Label row
            HStack(spacing: Spacing.md) {
                // Time input
                VStack(alignment: .leading, spacing: 4) {
                    Text("時間")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    TextField("5:00", text: $timeInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                }

                // Label input
                VStack(alignment: .leading, spacing: 4) {
                    Text("標籤")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    TextField("計時器", text: $newLabel)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }

                Spacer()

                // Color picker (compact)
                VStack(alignment: .leading, spacing: 4) {
                    Text("顏色")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    compactColorPicker
                }
            }

            // Add button
            Button {
                if editingTimerId != nil {
                    saveEditedTimer()
                } else {
                    addCustomTimer()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: editingTimerId != nil ? "checkmark.circle.fill" : "plus.circle.fill")
                    Text(editingTimerId != nil ? "儲存" : "新增計時器")
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .disabled(parsedSeconds == 0)

            if editingTimerId != nil {
                Button("取消編輯") {
                    cancelEdit()
                }
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var compactColorPicker: some View {
        HStack(spacing: 4) {
            ForEach(CountdownColors.all.prefix(6), id: \.self) { hex in
                Button {
                    selectedColorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selectedColorHex == hex ? 2 : 0)
                        )
                        .shadow(color: selectedColorHex == hex ? Color(hex: hex).opacity(0.5) : .clear, radius: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Advanced Settings Section

    private var advancedSettingsSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Completion command
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("完成時執行指令")
                        .font(.system(size: 12, design: .rounded))
                    TextField("say \"時間到\"", text: $completionCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                }

                Divider()

                // Sound settings
                soundSettingsContent
            }
            .padding(.top, Spacing.sm)
        } label: {
            HStack {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                Text("進階設定")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            syncSoundSettingsState()
        }
    }

    private var soundSettingsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("提示音")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            // Sound source type picker
            Picker("", selection: $soundSourceType) {
                ForEach(SoundSourceType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: soundSourceType) { _, _ in
                applySoundSettings()
            }

            // Dynamic content based on sound source type
            Group {
                if soundSourceType == .system {
                    systemSoundPicker
                } else if soundSourceType == .tts {
                    ttsSoundSettings
                } else {
                    customSoundPicker
                }
            }

            // Volume slider
            HStack {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Slider(value: Bindable(manager).settings.soundVolume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Button {
                    previewCurrentSound()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - System Sound Picker

    private var systemSoundPicker: some View {
        HStack {
            Text("選擇音效")
                .font(.system(size: 12, design: .rounded))
            Spacer()
            Picker("", selection: $selectedSystemSound) {
                ForEach(SystemSound.allCases, id: \.self) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .frame(width: 140)
            .labelsHidden()
            .onChange(of: selectedSystemSound) { _, _ in
                applySoundSettings()
            }
        }
    }

    // MARK: - TTS Sound Settings

    private var ttsSoundSettings: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Preset TTS alarm
            HStack {
                Text("預設語音")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                Picker("", selection: $selectedTTSAlarm) {
                    ForEach(TTSAlarm.allCases, id: \.self) { alarm in
                        Text(alarm.displayName).tag(alarm)
                    }
                }
                .frame(width: 140)
                .labelsHidden()
                .onChange(of: selectedTTSAlarm) { _, _ in
                    applySoundSettings()
                }
            }

            // Custom TTS message
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("自訂訊息")
                        .font(.system(size: 12, design: .rounded))
                    Spacer()
                }
                TextField("留空則使用預設語音", text: $customTTSMessage)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .onChange(of: customTTSMessage) { _, _ in
                        applySoundSettings()
                    }
            }

            // Voice selection
            HStack {
                Text("語音")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                Picker("", selection: $selectedTTSVoice) {
                    ForEach(TTSVoice.allCases, id: \.self) { voice in
                        Text(voice.displayName).tag(voice)
                    }
                }
                .frame(width: 140)
                .labelsHidden()
                .onChange(of: selectedTTSVoice) { _, _ in
                    applySoundSettings()
                }
            }

            // Speech rate
            HStack {
                Text("語速")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                HStack(spacing: Spacing.xs) {
                    Text("慢")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { Double(ttsRate) },
                        set: { ttsRate = Int($0) }
                    ), in: 100...400, step: 25)
                        .frame(width: 80)
                    Text("快")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(ttsRate)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                }
                .onChange(of: ttsRate) { _, _ in
                    applySoundSettings()
                }
            }
        }
    }

    // MARK: - Custom Sound Picker

    private var customSoundPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("音效檔案")
                    .font(.system(size: 12, design: .rounded))
                Spacer()
                Button {
                    selectCustomSoundFile()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "folder.fill")
                        Text("選擇檔案...")
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .buttonStyle(.bordered)
            }

            if !customSoundName.isEmpty {
                HStack {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("已選: \(customSoundName)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        clearCustomSound()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("支援 MP3、WAV、AIFF 格式")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Sound Helper Methods

    private func syncSoundSettingsState() {
        let source = manager.settings.effectiveSoundSource
        switch source {
        case .system(let sound):
            soundSourceType = .system
            selectedSystemSound = sound
        case .tts(let alarm):
            soundSourceType = .tts
            selectedTTSAlarm = alarm
        case .custom(let bookmarkData, let name):
            soundSourceType = .custom
            customSoundBookmarkData = bookmarkData
            customSoundName = name
        }

        customTTSMessage = manager.settings.customTTSMessage ?? ""
        selectedTTSVoice = manager.settings.ttsVoice
        ttsRate = manager.settings.ttsRate
    }

    private func applySoundSettings() {
        switch soundSourceType {
        case .system:
            manager.settings.soundSource = .system(selectedSystemSound)
            manager.settings.soundName = selectedSystemSound
        case .tts:
            manager.settings.soundSource = .tts(selectedTTSAlarm)
            manager.settings.customTTSMessage = customTTSMessage.isEmpty ? nil : customTTSMessage
            manager.settings.ttsVoice = selectedTTSVoice
            manager.settings.ttsRate = ttsRate
        case .custom:
            if let bookmarkData = customSoundBookmarkData {
                manager.settings.soundSource = .custom(bookmarkData: bookmarkData, name: customSoundName)
            }
        }
    }

    private func previewCurrentSound() {
        switch soundSourceType {
        case .system:
            manager.previewSound(source: .system(selectedSystemSound))
        case .tts:
            manager.previewSound(source: .tts(selectedTTSAlarm))
        case .custom:
            if let bookmarkData = customSoundBookmarkData {
                manager.previewSound(source: .custom(bookmarkData: bookmarkData, name: customSoundName))
            } else {
                manager.playSound(name: SystemSound.glass.rawValue, volume: manager.settings.soundVolume)
            }
        }
    }

    private func selectCustomSoundFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .mp3, .aiff, .wav]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "選擇計時器完成時播放的音效檔案"
        panel.prompt = "選擇"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                customSoundBookmarkData = bookmarkData
                customSoundName = url.lastPathComponent
                applySoundSettings()
            } catch {
                print("Failed to create bookmark: \(error)")
            }
        }
    }

    private func clearCustomSound() {
        customSoundBookmarkData = nil
        customSoundName = ""
        soundSourceType = .system
        applySoundSettings()
    }

    private func addCustomTimer() {
        guard parsedSeconds > 0 else { return }
        manager.addTimer(
            label: newLabel.isEmpty ? "計時器" : newLabel,
            duration: parsedSeconds,
            colorHex: selectedColorHex,
            completionCommand: completionCommand.isEmpty ? nil : completionCommand
        )
        newLabel = ""
        timeInput = "5:00"
        completionCommand = ""
    }

    // MARK: - Existing Timers Section

    private var existingTimersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("已建立的計時器 (\(manager.timers.count))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(spacing: Spacing.xs) {
                ForEach(manager.timers) { timer in
                    existingTimerRow(timer)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func existingTimerRow(_ timer: CountdownTimer) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(Color(hex: timer.colorHex))
                .frame(width: 10, height: 10)

            Text(timer.label.isEmpty ? "計時器" : timer.label)
                .font(.system(size: 12, design: .rounded))
                .lineLimit(1)

            if timer.completionCommand != nil && !timer.completionCommand!.isEmpty {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .help("完成時執行指令")
            }

            Spacer()

            Text(formatDuration(timer.duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            if timer.timerState == .running {
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(ThemeColors.primary)
            } else if timer.timerState == .paused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            }

            Button {
                startEditing(timer)
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.primary)
            }
            .buttonStyle(.plain)

            Button {
                if editingTimerId == timer.id {
                    cancelEdit()
                }
                manager.removeTimer(id: timer.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(
            editingTimerId == timer.id
                ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Edit Functions

    private func startEditing(_ timer: CountdownTimer) {
        editingTimerId = timer.id
        newLabel = timer.label
        selectedColorHex = timer.colorHex
        completionCommand = timer.completionCommand ?? ""
        timeInput = formatSecondsToInput(timer.duration)
    }

    private func cancelEdit() {
        editingTimerId = nil
        newLabel = ""
        timeInput = "5:00"
        selectedColorHex = CountdownColors.blue
        completionCommand = ""
    }

    private func saveEditedTimer() {
        guard let id = editingTimerId, parsedSeconds > 0 else { return }

        manager.updateTimer(
            id: id,
            label: newLabel.isEmpty ? "計時器" : newLabel,
            duration: parsedSeconds,
            colorHex: selectedColorHex,
            completionCommand: completionCommand.isEmpty ? nil : completionCommand
        )

        cancelEdit()
    }
}
