//
//  ScheduleSettingsTab.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import SwiftUI

/// 排程設定頁籤
struct ScheduleSettingsTab: View {
    let onClose: () -> Void
    var manager = ScheduleManager.shared

    @State private var showAddSheet = false
    @State private var editingSchedule: Schedule?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // 說明卡片
                infoCard

                // 排程列表
                schedulesSection

                Spacer()
            }
            .padding(Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "plus.circle.fill")
                            Text("新增排程")
                        }
                        .font(.system(size: 12, design: .rounded))
                    }
                    .buttonStyle(.bordered)

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
        .sheet(isPresented: $showAddSheet) {
            ScheduleEditSheet(
                schedule: nil,
                onSave: { schedule in
                    manager.addSchedule(schedule)
                    showAddSheet = false
                },
                onCancel: {
                    showAddSheet = false
                }
            )
        }
        .sheet(item: $editingSchedule) { schedule in
            ScheduleEditSheet(
                schedule: schedule,
                onSave: { updated in
                    manager.updateSchedule(updated)
                    editingSchedule = nil
                },
                onCancel: {
                    editingSchedule = nil
                }
            )
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(ThemeColors.primary)
                Text("排程功能")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }

            Text("設定排程在指定時間自動執行動作，例如啟動番茄鐘或發送提醒通知。")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Schedules Section

    private var schedulesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("已排程項目")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("(\(manager.schedules.count)/\(ScheduleManager.maxScheduleCount))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            if manager.schedules.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(manager.schedules) { schedule in
                        scheduleRow(schedule)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("尚無排程")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)

            Text("點擊「新增排程」開始設定")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    private func scheduleRow(_ schedule: Schedule) -> some View {
        HStack(spacing: Spacing.sm) {
            // 啟用開關
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in manager.toggleEnabled(id: schedule.id) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)

            // 時間
            Text(schedule.formattedTime)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(schedule.isEnabled ? .primary : .secondary)

            // 標籤
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.label)
                    .font(.system(size: 12, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(schedule.isEnabled ? .primary : .secondary)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: schedule.action.icon)
                        .font(.system(size: 9))
                    Text(schedule.action.description)
                        .font(.system(size: 10, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // 重複規則
            Text(schedule.recurrence.displayName)
                .font(.system(size: 10, design: .rounded))
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .clipShape(Capsule())
                .foregroundStyle(.secondary)

            // 編輯按鈕
            Button {
                editingSchedule = schedule
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.primary)
            }
            .buttonStyle(.plain)

            // 刪除按鈕
            Button {
                manager.removeSchedule(id: schedule.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.sm)
        .background(schedule.isEnabled ? Color.primary.opacity(0.03) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
