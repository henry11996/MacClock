//
//  ScheduleWidgetView.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import SwiftUI

/// 排程小工具視圖 - 顯示即將觸發的排程
struct ScheduleWidgetView: View {
    var manager: ScheduleManager
    var namespace: Namespace.ID

    private var liquidGlassEnabled: Bool {
        PomodoroTimer.shared.settings.liquidGlassEnabled
    }

    private var fontScale: CGFloat {
        manager.settings.fontScale
    }

    /// 過濾掉已完成的單次排程
    private var activeSchedules: [Schedule] {
        manager.visibleSchedules.filter { schedule in
            // 單次排程如果已執行過就不顯示
            if case .none = schedule.recurrence {
                return schedule.lastTriggeredAt == nil
            }
            return true
        }
    }

    var body: some View {
        if activeSchedules.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                ForEach(activeSchedules.prefix(manager.settings.maxVisibleSchedules)) { schedule in
                    ScheduleItemView(
                        schedule: schedule,
                        fontScale: fontScale,
                        liquidGlassEnabled: liquidGlassEnabled,
                        isRecentlyTriggered: manager.recentlyTriggeredScheduleId == schedule.id,
                        namespace: namespace
                    )
                }
            }
        }
    }
}

// MARK: - Schedule Indicator Dot

/// 彩色指示圓點，依動作類型顯示不同顏色
struct ScheduleIndicatorDot: View {
    let color: Color
    let isEnabled: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(color.opacity(isEnabled ? 0.3 : 0.15), lineWidth: 1)
                .frame(width: 10, height: 10)
            Circle()
                .fill(color.opacity(isEnabled ? 1.0 : 0.4))
                .frame(width: 6, height: 6)
        }
        .frame(width: 10, height: 10)
    }
}

// MARK: - Schedule Item View

/// 單一排程項目視圖
struct ScheduleItemView: View {
    let schedule: Schedule
    let fontScale: CGFloat
    let liquidGlassEnabled: Bool
    let isRecentlyTriggered: Bool
    var namespace: Namespace.ID

    @State private var isHovered = false
    @State private var bounceOffset: CGFloat = 0
    @State private var bounceCount: Int = 0
    @State private var highlightOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Action Accent Color

    private var actionColor: Color {
        switch schedule.action {
        case .startPomodoro:    return ThemeColors.workPhase
        case .startTimer:       return ThemeColors.primary
        case .runCommand:       return .purple
        case .notification:     return ThemeColors.urgencyMedium
        }
    }

    // MARK: - Approaching Urgency

    private var isApproaching: Bool {
        guard schedule.isEnabled,
              let next = schedule.nextTriggerDate() else { return false }
        let diff = next.timeIntervalSince(Date())
        return diff > 0 && diff <= 300
    }

    /// 計算下次執行的相對時間文字
    private var relativeTimeText: String? {
        guard let nextTrigger = schedule.nextTriggerDate() else { return nil }

        let now = Date()
        let diff = nextTrigger.timeIntervalSince(now)

        guard diff > 0 else { return nil }

        let minutes = Int(diff / 60)
        let hours = minutes / 60
        let days = hours / 24

        if minutes < 1 {
            return "即將執行"
        } else if minutes < 60 {
            return "\(minutes)分鐘後"
        } else if hours < 24 {
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                return "\(hours)小時\(remainingMinutes)分後"
            }
            return "\(hours)小時後"
        } else {
            return "\(days)天後"
        }
    }

    private var nextTriggerText: String {
        // 如果有下次觸發時間
        if let nextTrigger = schedule.nextTriggerDate() {
            let calendar = Calendar.current

            // 如果是今天
            if calendar.isDateInToday(nextTrigger) {
                return "今天 \(schedule.formattedTime)"
            }

            // 如果是明天
            if calendar.isDateInTomorrow(nextTrigger) {
                return "明天 \(schedule.formattedTime)"
            }

            // 其他情況顯示星期
            let weekday = calendar.component(.weekday, from: nextTrigger)
            let weekdayName = RecurrenceRule.weekdayName(weekday == 1 ? 7 : weekday - 1)
            return "\(weekdayName) \(schedule.formattedTime)"
        }

        // 沒有下次觸發時間時，根據重複規則顯示
        switch schedule.recurrence {
        case .none:
            return schedule.formattedTime
        case .daily:
            return "每天 \(schedule.formattedTime)"
        case .weekly:
            return schedule.formattedTime
        case .interval(let hours):
            return "每\(hours)時"
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // 彩色指示圓點
            ScheduleIndicatorDot(color: actionColor, isEnabled: schedule.isEnabled)

            // 動作圖示
            Image(systemName: schedule.action.icon)
                .font(.system(size: 10 * fontScale, weight: .medium))
                .foregroundStyle(actionColor.opacity(schedule.isEnabled ? 0.85 : 0.4))

            // 標籤
            Text(schedule.label)
                .font(.system(size: 11 * fontScale, weight: .medium, design: .rounded))
                .lineLimit(1)
                .opacity(schedule.isEnabled ? 1.0 : 0.5)

            // 下次觸發時間
            Text(nextTriggerText)
                .font(.system(size: 10 * fontScale, design: .rounded))
                .foregroundStyle(.white.opacity(schedule.isEnabled ? 0.6 : 0.35))

            // 相對時間（突出顯示）
            if let relativeText = relativeTimeText {
                Text(relativeText)
                    .font(.system(size: 10 * fontScale, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        (isApproaching ? ThemeColors.urgencyMedium : .white)
                            .opacity(0.9)
                    )
            }

            // 重複規則指示
            if case .none = schedule.recurrence {
                // 單次不顯示
            } else {
                Image(systemName: "repeat")
                    .font(.system(size: 8 * fontScale))
                    .foregroundStyle(.white.opacity(schedule.isEnabled ? 0.5 : 0.3))
            }

            // 懸停時顯示啟用/停用按鈕
            if isHovered {
                Button {
                    ScheduleManager.shared.toggleEnabled(id: schedule.id)
                } label: {
                    Image(systemName: schedule.isEnabled ? "pause.fill" : "play.fill")
                        .font(.system(size: 10 * fontScale, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(InteractiveCircleButtonStyle())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .overlay(
            Capsule()
                .fill(Color.white.opacity(highlightOpacity))
        )
        .conditionalGlassEffect(enabled: liquidGlassEnabled, in: Capsule())
        .glassEffectID("schedule-\(schedule.id)", in: namespace)
        .opacity(isHovered ? 0.8 : 1.0)
        .onHover { hovering in
            withAnimation(AnimationPresets.microInteraction) {
                isHovered = hovering
            }
        }
        .offset(y: bounceOffset)
        .onChange(of: isRecentlyTriggered) { _, newValue in
            if newValue {
                startBounceAnimation()
                withAnimation(.easeIn(duration: 0.2)) {
                    highlightOpacity = 0.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 2.0)) {
                        highlightOpacity = 0
                    }
                }
            }
        }
        .onTapGesture {
            // 點擊打開排程設定
            NotificationCenter.default.post(name: .showSettings, object: SettingsTab.schedule)
        }
        .contextMenu {
            Button {
                ScheduleManager.shared.toggleEnabled(id: schedule.id)
            } label: {
                Label(schedule.isEnabled ? "停用" : "啟用",
                      systemImage: schedule.isEnabled ? "pause.circle" : "play.circle")
            }
            Divider()
            Button {
                NotificationCenter.default.post(name: .showSettings, object: SettingsTab.schedule)
            } label: {
                Label("編輯", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                ScheduleManager.shared.removeSchedule(id: schedule.id)
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    // MARK: - Bounce Animation

    private func startBounceAnimation() {
        guard !reduceMotion else { return }
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
}
