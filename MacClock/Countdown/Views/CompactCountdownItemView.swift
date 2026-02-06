//
//  CompactCountdownItemView.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import SwiftUI

// MARK: - Urgency Level

enum UrgencyLevel {
    case normal   // >25%
    case medium   // 10-25%
    case high     // <10%
    case critical // ≤10 seconds

    var timeColor: Color {
        switch self {
        case .normal: return .white
        case .medium: return ThemeColors.urgencyMedium
        case .high, .critical: return ThemeColors.urgencyHigh
        }
    }

    static func from(progress: Double, remainingSeconds: TimeInterval) -> UrgencyLevel {
        if remainingSeconds <= 10 {
            return .critical
        } else if progress < 0.10 {
            return .high
        } else if progress < 0.25 {
            return .medium
        }
        return .normal
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let isCompleted: Bool

    @State private var completionScale: CGFloat = 1.0
    @State private var completionOpacity: Double = 1.0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 2)
                .frame(width: 16, height: 16)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(-90))
                .animation(AnimationPresets.progressUpdate, value: progress)

            // Center dot
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            // Completion flash effect
            if isCompleted {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .scaleEffect(completionScale)
                    .opacity(completionOpacity)
            }
        }
        .frame(width: 16, height: 16)
        .onChange(of: isCompleted) { _, newValue in
            if newValue {
                // Trigger completion animation
                withAnimation(.easeOut(duration: 0.6)) {
                    completionScale = 2.0
                    completionOpacity = 0.0
                }
                // Reset after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    completionScale = 1.0
                    completionOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Compact Countdown Item View

/// Single countdown timer row for compact display
struct CompactCountdownItemView: View {
    let timer: CountdownTimer
    let fontScale: CGFloat
    let isRecentlyCompleted: Bool
    let onToggle: () -> Void
    let onReset: () -> Void
    let onAddTime: (TimeInterval) -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var bounceOffset: CGFloat = 0
    @State private var bounceCount: Int = 0

    private var timerColor: Color {
        Color(hex: timer.colorHex)
    }

    private var urgencyLevel: UrgencyLevel {
        guard timer.timerState == .running else { return .normal }
        let remaining = timer.currentRemainingSeconds()
        return UrgencyLevel.from(progress: timer.progress, remainingSeconds: remaining)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Circular progress indicator
            CircularProgressView(
                progress: timer.progress,
                color: timerColor,
                isCompleted: isRecentlyCompleted
            )

            // Label
            Text(timer.label.isEmpty ? "計時器" : timer.label)
                .font(.system(size: 12 * fontScale, weight: .medium, design: .rounded))
                .lineLimit(1)
                .frame(minWidth: 40, maxWidth: 80, alignment: .leading)

            // Time display with urgency color
            Text(timer.formattedTime)
                .font(.system(size: 14 * fontScale, weight: .medium, design: .monospaced))
                .foregroundStyle(urgencyLevel.timeColor)
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText())
                .scaleEffect(pulseScale)
                .onChange(of: urgencyLevel) { _, newLevel in
                    if newLevel == .critical {
                        startPulseAnimation()
                    } else {
                        stopPulseAnimation()
                    }
                }
                .onAppear {
                    if urgencyLevel == .critical {
                        startPulseAnimation()
                    }
                }

            // Quick action buttons (visible on hover)
            if isHovered {
                HStack(spacing: 4) {
                    Button {
                        onReset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(QuickActionButtonStyle())

                    Button {
                        onAddTime(60)
                    } label: {
                        Text("+1")
                    }
                    .buttonStyle(QuickActionButtonStyle())

                    Button {
                        onAddTime(300)
                    } label: {
                        Text("+5")
                    }
                    .buttonStyle(QuickActionButtonStyle())
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // Play/Pause button
            Button {
                onToggle()
            } label: {
                Image(systemName: timer.timerState == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.15))
        }
        .fixedSize(horizontal: true, vertical: false)
        .onHover { hovering in
            withAnimation(AnimationPresets.microInteraction) {
                isHovered = hovering
            }
        }
        .offset(y: bounceOffset)
        .onChange(of: isRecentlyCompleted) { _, newValue in
            if newValue {
                startBounceAnimation()
            }
        }
        .contextMenu {
            Button {
                onReset()
            } label: {
                Label("重置", systemImage: "arrow.counterclockwise")
            }

            Divider()

            Button {
                onAddTime(60)
            } label: {
                Label("+1 分鐘", systemImage: "plus.circle")
            }

            Button {
                onAddTime(300)
            } label: {
                Label("+5 分鐘", systemImage: "plus.circle")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    // MARK: - Bounce Animation

    private func startBounceAnimation() {
        bounceCount = 0
        performBounce()
    }

    private func performBounce() {
        guard bounceCount < 5 else {
            bounceOffset = 0
            return
        }

        // 向上跳
        withAnimation(.spring(duration: 0.2, bounce: 0.5)) {
            bounceOffset = -8
        }

        // 彈回
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(duration: 0.2, bounce: 0.3)) {
                bounceOffset = 0
            }

            // 下一次跳動
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                bounceCount += 1
                performBounce()
            }
        }
    }

    // MARK: - Pulse Animation

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 0.5)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.05
        }
    }

    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            pulseScale = 1.0
        }
    }
}
