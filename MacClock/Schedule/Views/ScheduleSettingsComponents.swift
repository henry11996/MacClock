//
//  ScheduleSettingsComponents.swift
//  MacClock
//
//  排程設定分頁的子元件
//

import SwiftUI

/// 動作類型對應的顏色
extension ScheduleAction {
    var tint: Color {
        switch self {
        case .startPomodoro: return ThemeColors.workPhase
        case .startTimer: return ThemeColors.primary
        case .runCommand: return .purple
        case .notification: return .orange
        }
    }
}

/// 排程清單中的單一列
struct ScheduleListRow: View {
    let schedule: Schedule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(schedule.formattedTime)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .frame(width: 52, alignment: .leading)

            Image(systemName: schedule.action.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(schedule.action.tint)
                .frame(width: 26, height: 26)
                .background(schedule.action.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.label)
                    .font(.system(size: 13, design: .rounded))
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text(schedule.action.displayName)
                    Text("·")
                    Text(schedule.recurrence.displayName)
                }
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            Toggle("啟用 \(schedule.formattedTime) \(schedule.label)", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(ThemeColors.primary)
            }
            .buttonStyle(.plain)
            .help("編輯排程")
            .accessibilityLabel("編輯 \(schedule.formattedTime) \(schedule.label)")

            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("刪除排程")
            .accessibilityLabel("刪除 \(schedule.formattedTime) \(schedule.label)")
        }
        .opacity(schedule.isEnabled ? 1 : 0.55)
        .padding(.vertical, Spacing.xs)
    }
}

/// 沒有排程時的友善提示
struct ScheduleEmptyState: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("尚無排程")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
            Text("點擊右上角「新增排程」，讓 MacClock 在指定時間自動啟動番茄鐘、計時器或發送通知。")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}
