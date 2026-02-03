//
//  PomodoroFullScreenView.swift
//  MacClock
//
//  Created by 吳阜紘 on 2026/2/2.
//

import SwiftUI

/// Full-screen button style with hover brightness effect
struct FullScreenButtonStyle: ButtonStyle {
    @State private var isHovered = false
    var size: CGFloat = 72
    var backgroundOpacity: Double = 0.2

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color.white.opacity(
                        configuration.isPressed ? backgroundOpacity + 0.2 :
                        (isHovered ? backgroundOpacity + 0.15 : backgroundOpacity)
                    ))
            )
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
            .animation(AnimationPresets.microInteraction, value: configuration.isPressed)
            .animation(AnimationPresets.microInteraction, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct PomodoroFullScreenView: View {
    @Bindable var timer: PomodoroTimer
    var onExit: () -> Void

    @State private var isHovering = false

    // Ring dimensions
    private let ringSize: CGFloat = 280
    private let ringLineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            // Semi-transparent dark overlay
            ThemeColors.backgroundOverlay
                .ignoresSafeArea()
                .onTapGesture {
                    onExit()
                }

            // Center content
            VStack(spacing: 40) {
                // Progress ring with time
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: ringLineWidth)
                        .frame(width: ringSize, height: ringSize)

                    // Progress ring with gradient
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    phaseColor.opacity(0.7),
                                    phaseColor
                                ]),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(AnimationPresets.progressUpdate, value: timer.progress)

                    // Glow effect on progress end
                    Circle()
                        .fill(phaseColor)
                        .frame(width: ringLineWidth + 4, height: ringLineWidth + 4)
                        .blur(radius: 4)
                        .offset(y: -ringSize / 2)
                        .rotationEffect(.degrees(360 * timer.progress - 90))
                        .opacity(timer.progress > 0.01 ? 0.8 : 0)
                        .animation(AnimationPresets.progressUpdate, value: timer.progress)

                    // Time display
                    VStack(spacing: Spacing.sm) {
                        Text(timer.formattedTime)
                            .font(.system(size: 72, weight: .light, design: .monospaced))
                            .foregroundColor(ThemeColors.textPrimary)
                            .contentTransition(.numericText())

                        // Phase badge
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: phaseIcon)
                                .font(.system(size: 16, weight: .medium))
                            Text(timer.phase.displayName)
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(phaseColor)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(phaseColor.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                // Control buttons
                HStack(spacing: Spacing.xl + Spacing.sm) {
                    // Play/Pause button (primary - 72px)
                    Button {
                        timer.toggleStartPause()
                    } label: {
                        Image(systemName: timer.timerState == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                    .buttonStyle(FullScreenButtonStyle(size: 72, backgroundOpacity: 0.2))

                    // Skip button (secondary - 56px)
                    Button {
                        timer.skip()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 24))
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                    .buttonStyle(FullScreenButtonStyle(size: 56, backgroundOpacity: 0.15))
                }

                // Bottom info
                HStack(spacing: 40) {
                    // Pomodoro count
                    HStack(spacing: Spacing.sm) {
                        ForEach(0..<timer.settings.pomodorosUntilLongBreak, id: \.self) { index in
                            Circle()
                                .fill(index < currentCycleProgress ? ThemeColors.workPhase : Color.white.opacity(0.3))
                                .frame(width: 12, height: 12)
                                .animation(AnimationPresets.spring, value: currentCycleProgress)
                        }
                        Text("\(timer.completedPomodoros)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(ThemeColors.textSecondary)
                    }

                    // Divider
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 4, height: 4)

                    // Focus time
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(ThemeColors.textSecondary)
                        Text(timer.formattedFocusTime)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(ThemeColors.textPrimary)
                    }
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }

            // ESC hint at bottom
            VStack {
                Spacer()
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "escape")
                        .font(.system(size: 10))
                    Text("按 ESC 或點擊背景退出")
                }
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(Color.white.opacity(0.4))
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .padding(.bottom, 40)
            }
        }
        .onKeyPress(.escape) {
            onExit()
            return .handled
        }
    }

    private var currentCycleProgress: Int {
        let count = timer.completedPomodoros % timer.settings.pomodorosUntilLongBreak
        // If we just completed a cycle, show all filled
        if timer.completedPomodoros > 0 && count == 0 {
            return timer.settings.pomodorosUntilLongBreak
        }
        return count
    }

    private var phaseIcon: String {
        switch timer.phase {
        case .work: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "figure.walk"
        }
    }

    private var phaseColor: Color {
        switch timer.phase {
        case .work: return ThemeColors.workPhase
        case .shortBreak: return ThemeColors.shortBreak
        case .longBreak: return ThemeColors.longBreak
        }
    }
}
