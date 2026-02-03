//
//  CountdownWidgetView.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import SwiftUI

/// Compact countdown widget for inline display (above/below clock)
struct CountdownWidgetView: View {
    @Bindable var manager: CountdownManager
    let namespace: Namespace.ID

    @State private var isCollapsed = false

    private let collapseThreshold = 3

    private var fontScale: CGFloat {
        CountdownManager.shared.settings.fontScale
    }

    private var liquidGlassEnabled: Bool {
        PomodoroTimer.shared.settings.liquidGlassEnabled
    }

    private var shouldShowCollapseOption: Bool {
        manager.timers.count > collapseThreshold
    }

    private var runningCount: Int {
        manager.timers.filter { $0.timerState == .running }.count
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            if manager.timers.isEmpty {
                emptyStateView
            } else if isCollapsed && shouldShowCollapseOption {
                collapsedView
            } else {
                timersList
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .conditionalGlassEffect(enabled: liquidGlassEnabled, in: RoundedRectangle(cornerRadius: 16))
        .glassEffectID("countdownWidget", in: namespace)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        HStack(spacing: Spacing.sm) {
            Text("沒有計時器")
                .font(.system(size: 12 * fontScale, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                NotificationCenter.default.post(name: .showSettings, object: SettingsTab.countdown)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ThemeColors.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.1))
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Collapsed View

    private var collapsedView: some View {
        HStack(spacing: Spacing.sm) {
            // Running indicator dots
            if runningCount > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<min(runningCount, 3), id: \.self) { index in
                        Circle()
                            .fill(ThemeColors.primary)
                            .frame(width: 6, height: 6)
                    }
                    if runningCount > 3 {
                        Text("+")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(ThemeColors.primary)
                    }
                }

                Text("\(runningCount)個進行中")
                    .font(.system(size: 12 * fontScale, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text("\(manager.timers.count)個計時器")
                .font(.system(size: 12 * fontScale, design: .rounded))
                .foregroundStyle(.secondary)

            // Expand button
            Button {
                withAnimation(AnimationPresets.spring) {
                    isCollapsed = false
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.15))

            // Add button
            addButton
        }
    }

    // MARK: - Timers List

    private var timersList: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            // Reference tickCount to trigger updates
            let _ = manager.tickCount

            ForEach(manager.timers) { timer in
                CompactCountdownItemView(
                    timer: timer,
                    fontScale: fontScale,
                    isRecentlyCompleted: manager.recentlyCompletedTimerId == timer.id,
                    onToggle: { manager.toggleStartPause(id: timer.id) },
                    onReset: { manager.reset(id: timer.id) },
                    onAddTime: { seconds in manager.addTime(id: timer.id, seconds: seconds) },
                    onDelete: { manager.removeTimer(id: timer.id) }
                )
            }

            // Footer: Collapse button (if applicable) + Add button
            HStack(spacing: Spacing.sm) {
                if shouldShowCollapseOption {
                    Button {
                        withAnimation(AnimationPresets.spring) {
                            isCollapsed = true
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .contentShape(Circle())
                    }
                    .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.1))
                }

                addButton
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            NotificationCenter.default.post(name: .showSettings, object: SettingsTab.countdown)
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ThemeColors.primary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(InteractiveCircleButtonStyle(backgroundOpacity: 0.1))
    }
}
