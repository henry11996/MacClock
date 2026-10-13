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

    // 直接綁定 manager.settings：變更即存檔（didSet），也不會與外部變更（例如觸發時自動改位置）脫節
    private var isEnabled: Binding<Bool> {
        Binding(get: { manager.settings.isEnabled }, set: { manager.settings.isEnabled = $0 })
    }
    private var position: Binding<SchedulePosition> {
        Binding(get: { manager.settings.position }, set: { manager.settings.position = $0 })
    }
    private var fontScale: Binding<CGFloat> {
        Binding(get: { manager.settings.fontScale }, set: { manager.settings.fontScale = $0 })
    }
    private var autoCollapse: Binding<Bool> {
        Binding(get: { manager.settings.autoCollapseEnabled }, set: { manager.settings.autoCollapseEnabled = $0 })
    }
    private var maxVisible: Binding<Int> {
        Binding(get: { manager.settings.maxVisibleSchedules }, set: { manager.settings.maxVisibleSchedules = $0 })
    }

    private var isAtLimit: Bool { manager.schedules.count >= ScheduleManager.maxScheduleCount }
    private var enabledCount: Int { manager.schedules.filter(\.isEnabled).count }

    var body: some View {
        SettingsTabScaffold(onClose: onClose) {
            header
            schedulesCard
            displayCard
        }
        .sheet(isPresented: $showAddSheet) {
            ScheduleEditSheet(
                schedule: nil,
                onSave: { schedule in
                    manager.addSchedule(schedule)
                    showAddSheet = false
                },
                onCancel: { showAddSheet = false }
            )
        }
        .sheet(item: $editingSchedule) { schedule in
            ScheduleEditSheet(
                schedule: schedule,
                onSave: { updated in
                    manager.updateSchedule(updated)
                    editingSchedule = nil
                },
                onCancel: { editingSchedule = nil }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        SettingsHeader(
            title: "排程",
            subtitle: "已啟用 \(enabledCount) / 共 \(manager.schedules.count) 個（上限 \(ScheduleManager.maxScheduleCount)）",
            icon: "calendar.badge.clock"
        ) {
            Button {
                showAddSheet = true
            } label: {
                Label("新增排程", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAtLimit)
            .help(isAtLimit ? "已達排程數量上限" : "新增排程")
        }
    }

    // MARK: - Schedules

    private var schedulesCard: some View {
        SettingsCard(title: "排程清單", icon: "list.bullet") {
            SettingToggleRow(
                title: "啟用排程",
                subtitle: "關閉後所有排程都不會自動執行",
                icon: "power",
                isOn: isEnabled
            )

            Divider()

            if manager.schedules.isEmpty {
                ScheduleEmptyState()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(manager.schedules.enumerated()), id: \.element.id) { index, schedule in
                        if index > 0 { Divider() }
                        ScheduleListRow(
                            schedule: schedule,
                            onToggle: { manager.toggleEnabled(id: schedule.id) },
                            onEdit: { editingSchedule = schedule },
                            onDelete: {
                                guard DeleteConfirmation.confirm(.schedule, name: schedule.label) else { return }
                                manager.removeSchedule(id: schedule.id)
                            }
                        )
                    }
                }
            }

            if isAtLimit {
                SettingsFootnote(text: "已達上限 \(ScheduleManager.maxScheduleCount) 個，請先刪除不需要的排程。")
            }
        }
    }

    // MARK: - Display

    private var displayCard: some View {
        SettingsCard(title: "顯示", icon: "rectangle.on.rectangle") {
            SettingRow(title: "位置", icon: "square.stack") {
                Picker("排程位置", selection: position) {
                    Text("隱藏").tag(SchedulePosition.hidden)
                    Text("時鐘上方").tag(SchedulePosition.above)
                    Text("時鐘下方").tag(SchedulePosition.below)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            Divider()

            SettingRow(
                title: "最多顯示數",
                subtitle: "小工具同時顯示的排程數量",
                icon: "list.number"
            ) {
                Stepper(value: maxVisible, in: 1...ScheduleManager.maxScheduleCount) {
                    Text("\(manager.settings.maxVisibleSchedules)")
                        .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                }
                .accessibilityLabel("最多顯示排程數")
                .accessibilityValue("\(manager.settings.maxVisibleSchedules)")
            }

            Divider()

            FontScaleRow(title: "字體大小", icon: "textformat.size", value: fontScale)

            Divider()

            SettingToggleRow(
                title: "觸發時才顯示",
                subtitle: "排程觸發時展開列表，10 秒後自動收起",
                icon: "eye.slash",
                isOn: autoCollapse
            )
        }
    }
}
