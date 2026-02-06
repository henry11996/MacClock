//
//  ContentView.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import Combine
import SwiftUI

// MARK: - Design System

/// Theme colors based on UI/UX Pro Max design system
enum ThemeColors {
    static let primary = Color(hex: 0x3B82F6)  // Primary blue
    static let workPhase = Color(hex: 0xEF4444)  // Work red
    static let shortBreak = Color(hex: 0x22C55E)  // Short break green
    static let longBreak = Color(hex: 0x3B82F6)  // Long break blue
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let backgroundOverlay = Color.black.opacity(0.75)
    static let urgencyMedium = Color.orange  // Medium urgency (10-25%)
    static let urgencyHigh = Color(hex: 0xEF4444)  // High urgency (<10%)
}

/// Spacing system tokens
enum Spacing {
    static let xs: CGFloat = 4  // Tight elements
    static let sm: CGFloat = 8  // Button padding
    static let md: CGFloat = 12  // Element spacing
    static let lg: CGFloat = 16  // Section padding
    static let xl: CGFloat = 24  // Block spacing
}

/// Animation presets
enum AnimationPresets {
    static let spring = Animation.spring(duration: 0.3, bounce: 0.2)
    static let microInteraction = Animation.easeOut(duration: 0.15)
    static let progressUpdate = Animation.linear(duration: 0.1)
}

// MARK: - Interactive Button Styles

/// Button style with hover and press visual feedback
struct InteractiveButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : (isHovered ? 0.9 : 1.0))
            .animation(AnimationPresets.microInteraction, value: configuration.isPressed)
            .animation(AnimationPresets.microInteraction, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Circle button style with background opacity feedback
struct InteractiveCircleButtonStyle: ButtonStyle {
    @State private var isHovered = false
    var backgroundOpacity: Double = 0.1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(
                        Color.white.opacity(
                            configuration.isPressed
                                ? backgroundOpacity + 0.15
                                : (isHovered ? backgroundOpacity + 0.1 : backgroundOpacity)
                        ))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationPresets.microInteraction, value: configuration.isPressed)
            .animation(AnimationPresets.microInteraction, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Small quick action button style for +1/+5 buttons
struct QuickActionButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 22, height: 18)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        Color.white.opacity(
                            configuration.isPressed ? 0.25 : (isHovered ? 0.2 : 0.1)
                        ))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationPresets.microInteraction, value: configuration.isPressed)
            .animation(AnimationPresets.microInteraction, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Conditional Glass Effect

extension View {
    /// Apply glass effect conditionally based on user settings
    @ViewBuilder
    func conditionalGlassEffect<S: Shape>(
        enabled: Bool,
        in shape: S
    ) -> some View {
        if enabled {
            self.glassEffect(.clear.interactive(), in: shape)
        } else {
            self.background(Color.black.opacity(0.3))
                .clipShape(shape)
        }
    }
}

struct ContentView: View {
    @State private var currentTime = Date()
    @State private var isExpanded = false
    @State private var expandToRight = false
    @State private var showPomodoroSettings = false
    @State private var isHoveringClock = false
    @State private var isHoveringButtons = false
    @Namespace private var namespace

    var timer = PomodoroTimer.shared
    var countdownManager = CountdownManager.shared
    var scheduleManager = ScheduleManager.shared
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Check if there's enough space on the left to expand leftward
    private func updateExpandDirection() {
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }),
            let screen = window.screen
        else { return }
        let leftSpace = window.frame.minX - screen.visibleFrame.minX
        // Need ~84px for two buttons + spacing
        expandToRight = leftSpace < 84
    }

    private var settingsButton: some View {
        Button {
            NotificationCenter.default.post(name: .showSettings, object: nil)
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(InteractiveButtonStyle())
        .conditionalGlassEffect(enabled: liquidGlassEnabled, in: Circle())
        .glassEffectID("settings", in: namespace)
    }

    private var quitButton: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(InteractiveButtonStyle())
        .conditionalGlassEffect(enabled: liquidGlassEnabled, in: Circle())
        .glassEffectID("quit", in: namespace)
    }

    private var clockFontScale: CGFloat {
        timer.settings.clockFontScale
    }

    private var liquidGlassEnabled: Bool {
        timer.settings.liquidGlassEnabled
    }

    private var clockStyle: ClockStyle {
        timer.settings.clockStyle
    }

    private var clockView: some View {
        VStack(spacing: 2) {
            // Time display based on style
            switch clockStyle {
            case .standard, .timeOnly, .compact:
                Text(currentTime, format: .dateTime.hour().minute())
                    .font(.system(size: 24 * clockFontScale, weight: .medium, design: .rounded))
                    .lineLimit(1)
            case .withSeconds, .timeWithSeconds:
                Text(currentTime, format: .dateTime.hour().minute().second())
                    .font(.system(size: 24 * clockFontScale, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }

            // Date display based on style
            switch clockStyle {
            case .standard, .withSeconds:
                Text(currentTime, format: .dateTime.weekday(.wide).month().day())
                    .font(.system(size: 12 * clockFontScale, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .opacity(0.8)
            case .compact:
                Text(currentTime, format: .dateTime.month(.defaultDigits).day())
                    .font(.system(size: 12 * clockFontScale, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .opacity(0.8)
            case .timeOnly, .timeWithSeconds:
                EmptyView()
            }
        }
        .fixedSize()
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .conditionalGlassEffect(enabled: liquidGlassEnabled, in: Capsule())
        .glassEffectID("clock", in: namespace)
        .onHover { hovering in
            isHoveringClock = hovering
            if hovering {
                updateExpandDirection()
            }
            updateExpansion()
        }
    }

    private var buttonsGroup: some View {
        Group {
            if expandToRight {
                HStack(spacing: 12) {
                    settingsButton
                    quitButton
                }
            } else {
                HStack(spacing: 12) {
                    quitButton
                    settingsButton
                }
            }
        }
        .onHover { hovering in
            isHoveringButtons = hovering
            updateExpansion()
        }
    }

    private func updateExpansion() {
        withAnimation(AnimationPresets.spring) {
            isExpanded = isHoveringClock || isHoveringButtons
        }
    }

    // Width of buttons area: 2 buttons(36*2) + 1 spacing(12) = 72 + 12 = 84
    private let buttonsAreaWidth: CGFloat = 84

    private var compactPomodoroView: some View {
        CompactPomodoroView(
            timer: timer,
            showSettings: $showPomodoroSettings,
            namespace: namespace
        )
    }

    private var compactCountdownView: some View {
        CountdownWidgetView(
            manager: countdownManager,
            namespace: namespace
        )
    }

    private var compactScheduleView: some View {
        ScheduleWidgetView(
            manager: scheduleManager,
            namespace: namespace
        )
    }

    private var clockWithButtons: some View {
        HStack(spacing: 12) {
            if expandToRight {
                // Clock on left, buttons expand to right
                clockView
                if isExpanded {
                    buttonsGroup
                } else {
                    Spacer().frame(width: buttonsAreaWidth)
                }
            } else {
                // Buttons on left, clock stays on right
                if isExpanded {
                    buttonsGroup
                } else {
                    Spacer().frame(width: buttonsAreaWidth)
                }
                clockView
            }
        }
    }


    /// Whether the countdown widget should be visible (accounting for auto-collapse)
    private var shouldShowCountdown: Bool {
        guard countdownManager.settings.isEnabled else { return false }
        guard countdownManager.settings.position != .hidden else { return false }
        if countdownManager.settings.autoCollapseEnabled {
            return countdownManager.isAutoExpanded
        }
        return true
    }

    /// Whether the schedule widget should be visible (accounting for auto-collapse)
    private var shouldShowSchedule: Bool {
        guard scheduleManager.settings.isEnabled else { return false }
        guard scheduleManager.settings.position != .hidden else { return false }
        if scheduleManager.settings.autoCollapseEnabled {
            return scheduleManager.isAutoExpanded
        }
        return true
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            // Widgets above clock
            if timer.settings.pomodoroPosition == .above {
                compactPomodoroView
            }
            if shouldShowCountdown && countdownManager.settings.position == .above {
                compactCountdownView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if shouldShowSchedule && scheduleManager.settings.position == .above {
                compactScheduleView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Clock with hover buttons
            clockWithButtons

            // Widgets below clock
            if timer.settings.pomodoroPosition == .below {
                compactPomodoroView
            }
            if shouldShowCountdown && countdownManager.settings.position == .below {
                compactCountdownView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if shouldShowSchedule && scheduleManager.settings.position == .below {
                compactScheduleView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(AnimationPresets.spring, value: countdownManager.isAutoExpanded)
        .animation(AnimationPresets.spring, value: scheduleManager.isAutoExpanded)
    }

    var body: some View {
        Group {
            if liquidGlassEnabled {
                GlassEffectContainer(spacing: 12) {
                    mainContent
                }
            } else {
                mainContent
            }
        }
        .fixedSize()
        .onReceive(clockTimer) { input in
            currentTime = input
        }
        .onAppear {
            updateExpandDirection()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let enterPomodoroFullScreen = Notification.Name("enterPomodoroFullScreen")
    static let exitPomodoroFullScreen = Notification.Name("exitPomodoroFullScreen")
    static let backgroundRefreshSettingsChanged = Notification.Name("backgroundRefreshSettingsChanged")
    static let showSettings = Notification.Name("showSettings")
}

#Preview {
    ContentView()
}
