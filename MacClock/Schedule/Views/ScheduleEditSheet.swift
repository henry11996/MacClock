//
//  ScheduleEditSheet.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import SwiftUI

/// 新增/編輯排程的 Sheet 表單
struct ScheduleEditSheet: View {
    // 傳入的排程（如果是編輯模式）
    let schedule: Schedule?
    let onSave: (Schedule) -> Void
    let onCancel: () -> Void

    // MARK: - State

    @State private var label: String = ""
    @State private var hour: Int = 9
    @State private var minute: Int = 0

    // 動作選擇
    @State private var actionType: ActionType = .startPomodoro
    @State private var timerDuration: TimeInterval = 5 * 60
    @State private var timerLabel: String = "計時器"
    @State private var command: String = ""
    @State private var notificationTitle: String = ""
    @State private var notificationMessage: String = ""

    // 重複規則
    @State private var recurrenceType: RecurrenceType = .none
    @State private var selectedWeekdays: Set<Int> = []
    @State private var intervalHours: Int = 24

    // MARK: - Types

    enum ActionType: String, CaseIterable {
        case startPomodoro = "pomodoro"
        case startTimer = "timer"
        case runCommand = "command"
        case notification = "notification"

        var displayName: String {
            switch self {
            case .startPomodoro: return "啟動番茄鐘"
            case .startTimer: return "啟動計時器"
            case .runCommand: return "執行指令"
            case .notification: return "發送通知"
            }
        }

        var icon: String {
            switch self {
            case .startPomodoro: return "timer"
            case .startTimer: return "hourglass"
            case .runCommand: return "terminal.fill"
            case .notification: return "bell.fill"
            }
        }
    }

    enum RecurrenceType: String, CaseIterable {
        case none = "none"
        case daily = "daily"
        case weekly = "weekly"
        case interval = "interval"

        var displayName: String {
            switch self {
            case .none: return "不重複"
            case .daily: return "每天"
            case .weekly: return "每週..."
            case .interval: return "自訂..."
            }
        }
    }

    // MARK: - Initialization

    init(schedule: Schedule?, onSave: @escaping (Schedule) -> Void, onCancel: @escaping () -> Void) {
        self.schedule = schedule
        self.onSave = onSave
        self.onCancel = onCancel

        // 如果是編輯模式，初始化狀態
        if let s = schedule {
            _label = State(initialValue: s.label)
            _hour = State(initialValue: s.time.hour ?? 9)
            _minute = State(initialValue: s.time.minute ?? 0)

            // 解析動作類型
            switch s.action {
            case .startPomodoro:
                _actionType = State(initialValue: .startPomodoro)
            case .startTimer(let duration, let timerLbl):
                _actionType = State(initialValue: .startTimer)
                _timerDuration = State(initialValue: duration)
                _timerLabel = State(initialValue: timerLbl)
            case .runCommand(let cmd):
                _actionType = State(initialValue: .runCommand)
                _command = State(initialValue: cmd)
            case .notification(let title, let message):
                _actionType = State(initialValue: .notification)
                _notificationTitle = State(initialValue: title)
                _notificationMessage = State(initialValue: message)
            }

            // 解析重複規則
            switch s.recurrence {
            case .none:
                _recurrenceType = State(initialValue: .none)
            case .daily:
                _recurrenceType = State(initialValue: .daily)
            case .weekly(let weekdays):
                _recurrenceType = State(initialValue: .weekly)
                _selectedWeekdays = State(initialValue: weekdays)
            case .interval(let hours):
                _recurrenceType = State(initialValue: .interval)
                _intervalHours = State(initialValue: hours)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 標題列
            HStack {
                Text(schedule == nil ? "新增排程" : "編輯排程")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // 名稱
                    labelSection

                    // 時間
                    timeSection

                    // 動作
                    actionSection

                    // 重複規則
                    recurrenceSection
                }
                .padding(Spacing.lg)
            }

            Divider()

            // 按鈕列
            HStack {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("儲存") {
                    saveSchedule()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(Spacing.md)
        }
        .frame(width: 360, height: 520)
    }

    // MARK: - Sections

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("名稱")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            TextField("排程名稱", text: $label)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("時間")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: Spacing.sm) {
                Picker("", selection: $hour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 70)
                .labelsHidden()

                Text(":")
                    .font(.system(size: 16, weight: .medium))

                Picker("", selection: $minute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 70)
                .labelsHidden()

                Spacer()
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("動作")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Picker("", selection: $actionType) {
                ForEach(ActionType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            // 根據動作類型顯示額外欄位
            switch actionType {
            case .startPomodoro:
                Text("執行時會啟動番茄鐘工作階段")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)

            case .startTimer:
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("標籤")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        TextField("計時器", text: $timerLabel)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("時長")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        timerDurationPicker
                    }
                }

            case .runCommand:
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    TextField("例如：say \"該開始工作了\"", text: $command)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    Text("將執行的 Shell 指令")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

            case .notification:
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    TextField("通知標題", text: $notificationTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("通知內容", text: $notificationMessage)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(Spacing.sm)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var timerDurationPicker: some View {
        let hours = Int(timerDuration) / 3600
        let minutes = (Int(timerDuration) % 3600) / 60
        let seconds = Int(timerDuration) % 60

        return HStack(spacing: Spacing.xs) {
            Picker("", selection: Binding(
                get: { hours },
                set: { timerDuration = TimeInterval($0 * 3600 + minutes * 60 + seconds) }
            )) {
                ForEach(0..<24, id: \.self) { h in
                    Text("\(h)").tag(h)
                }
            }
            .frame(width: 50)
            .labelsHidden()
            Text("時")
                .font(.system(size: 10, design: .rounded))

            Picker("", selection: Binding(
                get: { minutes },
                set: { timerDuration = TimeInterval(hours * 3600 + $0 * 60 + seconds) }
            )) {
                ForEach(0..<60, id: \.self) { m in
                    Text("\(m)").tag(m)
                }
            }
            .frame(width: 50)
            .labelsHidden()
            Text("分")
                .font(.system(size: 10, design: .rounded))

            Picker("", selection: Binding(
                get: { seconds },
                set: { timerDuration = TimeInterval(hours * 3600 + minutes * 60 + $0) }
            )) {
                ForEach(0..<60, id: \.self) { s in
                    Text("\(s)").tag(s)
                }
            }
            .frame(width: 50)
            .labelsHidden()
            Text("秒")
                .font(.system(size: 10, design: .rounded))
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("重複")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Picker("", selection: $recurrenceType) {
                ForEach(RecurrenceType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            // 根據重複類型顯示額外選項
            switch recurrenceType {
            case .none:
                Text("排程只會執行一次")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)

            case .daily:
                Text("每天在指定時間執行")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)

            case .weekly:
                weekdaySelector

            case .interval:
                intervalSelector
            }
        }
        .padding(Spacing.sm)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var weekdaySelector: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("選擇星期")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.tertiary)

            HStack(spacing: Spacing.xs) {
                ForEach(1...7, id: \.self) { day in
                    weekdayButton(day)
                }
            }

            // 快捷選擇
            HStack(spacing: Spacing.sm) {
                Button("工作日") {
                    selectedWeekdays = Set([1, 2, 3, 4, 5])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("週末") {
                    selectedWeekdays = Set([6, 7])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("每天") {
                    selectedWeekdays = Set(1...7)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func weekdayButton(_ day: Int) -> some View {
        let isSelected = selectedWeekdays.contains(day)

        return Button {
            if isSelected {
                selectedWeekdays.remove(day)
            } else {
                selectedWeekdays.insert(day)
            }
        } label: {
            Text(RecurrenceRule.weekdayShortName(day))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(width: 30, height: 30)
                .background(isSelected ? ThemeColors.primary : Color.primary.opacity(0.08))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var intervalSelector: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("每")
                    .font(.system(size: 12, design: .rounded))

                Picker("", selection: $intervalHours) {
                    ForEach([1, 2, 3, 4, 6, 8, 12, 24, 48, 72], id: \.self) { h in
                        Text("\(h)").tag(h)
                    }
                }
                .frame(width: 60)
                .labelsHidden()

                Text("小時執行一次")
                    .font(.system(size: 12, design: .rounded))

                Spacer()
            }

            if intervalHours >= 24 && intervalHours % 24 == 0 {
                Text("相當於每 \(intervalHours / 24) 天")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        // 標籤不能為空
        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        // 根據動作類型驗證
        switch actionType {
        case .startPomodoro:
            return true
        case .startTimer:
            return timerDuration > 0
        case .runCommand:
            return !command.trimmingCharacters(in: .whitespaces).isEmpty
        case .notification:
            return !notificationTitle.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Save

    private func saveSchedule() {
        // 建立動作
        let action: ScheduleAction
        switch actionType {
        case .startPomodoro:
            action = .startPomodoro
        case .startTimer:
            action = .startTimer(duration: timerDuration, label: timerLabel.isEmpty ? "計時器" : timerLabel)
        case .runCommand:
            action = .runCommand(command: command)
        case .notification:
            action = .notification(title: notificationTitle, message: notificationMessage)
        }

        // 建立重複規則
        let recurrence: RecurrenceRule
        switch recurrenceType {
        case .none:
            recurrence = .none
        case .daily:
            recurrence = .daily
        case .weekly:
            recurrence = selectedWeekdays.isEmpty ? .none : .weekly(weekdays: selectedWeekdays)
        case .interval:
            recurrence = .interval(hours: intervalHours)
        }

        // 建立時間
        var time = DateComponents()
        time.hour = hour
        time.minute = minute

        // 建立或更新排程
        let newSchedule = Schedule(
            id: schedule?.id ?? UUID(),
            label: label.trimmingCharacters(in: .whitespaces),
            action: action,
            time: time,
            recurrence: recurrence,
            isEnabled: schedule?.isEnabled ?? true,
            lastTriggeredAt: schedule?.lastTriggeredAt,
            createdAt: schedule?.createdAt ?? Date()
        )

        onSave(newSchedule)
    }
}
