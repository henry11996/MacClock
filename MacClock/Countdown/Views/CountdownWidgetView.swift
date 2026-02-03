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

    private var fontScale: CGFloat {
        CountdownManager.shared.settings.fontScale
    }

    private var liquidGlassEnabled: Bool {
        PomodoroTimer.shared.settings.liquidGlassEnabled
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            if manager.timers.isEmpty {
                emptyStateView
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

    private var timersList: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            // Reference tickCount to trigger updates
            let _ = manager.tickCount

            ForEach(manager.timers) { timer in
                CompactCountdownItemView(
                    timer: timer,
                    fontScale: fontScale,
                    onToggle: { manager.toggleStartPause(id: timer.id) },
                    onReset: { manager.reset(id: timer.id) },
                    onAddTime: { seconds in manager.addTime(id: timer.id, seconds: seconds) },
                    onDelete: { manager.removeTimer(id: timer.id) }
                )
            }

            // Footer: Add button
            HStack(spacing: Spacing.sm) {
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
    }
}
