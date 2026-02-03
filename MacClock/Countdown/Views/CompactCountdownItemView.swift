//
//  CompactCountdownItemView.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import SwiftUI

/// Single countdown timer row for compact display
struct CompactCountdownItemView: View {
    let timer: CountdownTimer
    let fontScale: CGFloat
    let onToggle: () -> Void
    let onReset: () -> Void
    let onAddTime: (TimeInterval) -> Void
    let onDelete: () -> Void

    @State private var displayedRemaining: TimeInterval = 0

    private var timerColor: Color {
        Color(hex: timer.colorHex)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Color indicator
            Circle()
                .fill(timerColor)
                .frame(width: 8, height: 8)

            // Label
            Text(timer.label.isEmpty ? "計時器" : timer.label)
                .font(.system(size: 12 * fontScale, weight: .medium, design: .rounded))
                .lineLimit(1)
                .frame(minWidth: 40, maxWidth: 80, alignment: .leading)

            // Time display
            Text(timer.formattedTime)
                .font(.system(size: 14 * fontScale, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText())

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(timerColor)
                        .frame(width: geo.size.width * timer.progress, height: 4)
                        .animation(AnimationPresets.progressUpdate, value: timer.progress)
                }
            }
            .frame(width: 40, height: 4)

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
}
