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
                        namespace: namespace
                    )
                }
            }
        }
    }
}

/// 單一排程項目視圖
struct ScheduleItemView: View {
    let schedule: Schedule
    let fontScale: CGFloat
    let liquidGlassEnabled: Bool
    var namespace: Namespace.ID

    @State private var isHovered = false

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
            // 動作圖示
            Image(systemName: schedule.action.icon)
                .font(.system(size: 10 * fontScale, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            // 標籤
            Text(schedule.label)
                .font(.system(size: 11 * fontScale, weight: .medium, design: .rounded))
                .lineLimit(1)

            // 下次觸發時間
            Text(nextTriggerText)
                .font(.system(size: 10 * fontScale, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            // 相對時間（突出顯示）
            if let relativeText = relativeTimeText {
                Text(relativeText)
                    .font(.system(size: 10 * fontScale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // 重複規則指示
            if case .none = schedule.recurrence {
                // 單次不顯示
            } else {
                Image(systemName: "repeat")
                    .font(.system(size: 8 * fontScale))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .conditionalGlassEffect(enabled: liquidGlassEnabled, in: Capsule())
        .glassEffectID("schedule-\(schedule.id)", in: namespace)
        .opacity(isHovered ? 0.8 : 1.0)
        .onHover { hovering in
            withAnimation(AnimationPresets.microInteraction) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            // 點擊打開排程設定
            NotificationCenter.default.post(name: .showSettings, object: SettingsTab.schedule)
        }
    }
}
