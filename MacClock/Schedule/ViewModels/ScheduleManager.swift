//
//  ScheduleManager.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import AppKit
import Combine
import Foundation
import UserNotifications

/// 排程管理器 - 管理所有排程的 CRUD、觸發判斷與執行
@MainActor
@Observable
final class ScheduleManager {
    // MARK: - Singleton
    static let shared = ScheduleManager()

    // MARK: - Constants
    static let maxScheduleCount = 20

    // MARK: - State
    private(set) var schedules: [Schedule] = []
    private(set) var recentlyTriggeredScheduleId: UUID?

    // Auto-expand state for auto-collapse mode
    private(set) var isAutoExpanded: Bool = false

    // MARK: - Settings
    var settings: ScheduleSettings = .default {
        didSet {
            settings.save()
        }
    }

    // MARK: - Private
    private var checkTimer: AnyCancellable?
    private var lastCheckMinute: Int = -1
    private var autoCollapseTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// 啟用中的排程
    var enabledSchedules: [Schedule] {
        schedules.filter { $0.isEnabled }
    }

    /// 可見的排程（根據設定數量限制）
    var visibleSchedules: [Schedule] {
        Array(enabledSchedules.prefix(settings.maxVisibleSchedules))
    }

    /// 即將觸發的排程（按下次觸發時間排序）
    var upcomingSchedules: [Schedule] {
        enabledSchedules
            .compactMap { schedule -> (Schedule, Date)? in
                guard let nextTrigger = schedule.nextTriggerDate() else { return nil }
                return (schedule, nextTrigger)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }

    // MARK: - Initialization

    private init() {
        load()
        requestNotificationPermission()
        startCheckTimer()
        // 啟動時立即檢查一次
        checkAndExecute()
    }

    /// 檢查是否可以使用通知
    private var canUseNotifications: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    /// 請求通知權限
    private func requestNotificationPermission() {
        guard canUseNotifications else {
            print("[ScheduleManager] 無法使用通知（缺少 bundle identifier）")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[ScheduleManager] 通知權限請求錯誤: \(error)")
            }
            print("[ScheduleManager] 通知權限: \(granted ? "已授權" : "未授權")")
        }
    }

    // MARK: - CRUD Operations

    /// 新增排程
    @discardableResult
    func addSchedule(_ schedule: Schedule) -> Bool {
        guard schedules.count < Self.maxScheduleCount else { return false }
        schedules.append(schedule)
        save()
        return true
    }

    /// 更新排程
    func updateSchedule(_ schedule: Schedule) {
        guard let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        schedules[index] = schedule
        save()
    }

    /// 移除排程
    func removeSchedule(id: UUID) {
        schedules.removeAll { $0.id == id }
        save()
    }

    /// 切換啟用狀態
    func toggleEnabled(id: UUID) {
        guard let index = schedules.firstIndex(where: { $0.id == id }) else { return }
        schedules[index].isEnabled.toggle()
        save()
    }

    /// 取得排程
    func getSchedule(id: UUID) -> Schedule? {
        schedules.first { $0.id == id }
    }

    // MARK: - Timer Loop

    /// 啟動每分鐘檢查的 Timer
    func startCheckTimer() {
        // 每 10 秒檢查一次，確保不會錯過觸發時間
        checkTimer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkAndExecute()
                }
            }
    }

    /// 停止檢查 Timer
    func stopCheckTimer() {
        checkTimer?.cancel()
        checkTimer = nil
    }

    /// 檢查並執行排程
    func checkAndExecute() {
        guard settings.isEnabled else { return }

        // Pre-trigger auto-expand: show widget before schedule fires
        if settings.autoCollapseEnabled, !isAutoExpanded {
            let threshold = Date().addingTimeInterval(15)
            for schedule in enabledSchedules {
                if let nextTrigger = schedule.nextTriggerDate(), nextTrigger <= threshold {
                    isAutoExpanded = true
                    autoCollapseTask?.cancel()
                    break
                }
            }
        }

        let now = Date()
        let calendar = Calendar.current
        let currentMinute = calendar.component(.minute, from: now)
        let currentHour = calendar.component(.hour, from: now)

        // 避免同一分鐘重複檢查
        guard currentMinute != lastCheckMinute else { return }
        lastCheckMinute = currentMinute

        print("[ScheduleManager] 檢查排程 \(String(format: "%02d:%02d", currentHour, currentMinute))，共 \(schedules.count) 個排程")

        var hasTriggered = false
        for index in schedules.indices {
            guard schedules[index].isEnabled else { continue }

            if shouldTrigger(schedules[index], now: now) {
                print("[ScheduleManager] 觸發排程: \(schedules[index].label)")

                // 設定最近觸發的排程 ID（用於動畫）
                let triggeredId = schedules[index].id
                recentlyTriggeredScheduleId = triggeredId

                // 3 秒後清除
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    if self?.recentlyTriggeredScheduleId == triggeredId {
                        self?.recentlyTriggeredScheduleId = nil
                    }
                }

                // Auto-expand widget if auto-collapse mode is enabled
                if settings.autoCollapseEnabled {
                    isAutoExpanded = true
                    autoCollapseTask?.cancel()
                    autoCollapseTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(10))
                        guard !Task.isCancelled else { return }
                        self.isAutoExpanded = false
                    }
                }

                execute(schedules[index])

                // 更新 lastTriggeredAt
                schedules[index].lastTriggeredAt = now

                // 如果是單次排程，執行後停用
                if case .none = schedules[index].recurrence {
                    schedules[index].isEnabled = false
                }
                hasTriggered = true
            }
        }

        if hasTriggered {
            save()
        }
    }

    // MARK: - Trigger Logic

    /// 判斷排程是否應該觸發
    func shouldTrigger(_ schedule: Schedule, now: Date) -> Bool {
        let calendar = Calendar.current

        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        let scheduleHour = schedule.time.hour ?? 0
        let scheduleMinute = schedule.time.minute ?? 0

        // 首先檢查時間是否符合（只比較時、分）
        let timeMatches = (currentHour == scheduleHour && currentMinute == scheduleMinute)

        print("[ScheduleManager] 檢查 \(schedule.label): 現在 \(String(format: "%02d:%02d", currentHour, currentMinute)), 排程 \(String(format: "%02d:%02d", scheduleHour, scheduleMinute)), 符合=\(timeMatches), 規則=\(schedule.recurrence.displayName), lastTriggered=\(schedule.lastTriggeredAt?.description ?? "nil")")

        guard timeMatches else { return false }

        // 檢查是否今天已經觸發過
        if let lastTriggered = schedule.lastTriggeredAt {
            let lastTriggeredDay = calendar.startOfDay(for: lastTriggered)
            let today = calendar.startOfDay(for: now)

            // 對於每日重複或單次，同一天不重複觸發
            if lastTriggeredDay == today {
                // interval 規則例外，需要檢查小時間隔
                if case .interval(let hours) = schedule.recurrence {
                    let hoursSinceLastTrigger = calendar.dateComponents([.hour], from: lastTriggered, to: now).hour ?? 0
                    print("[ScheduleManager] → interval 檢查: 距上次 \(hoursSinceLastTrigger) 小時，需要 \(hours) 小時")
                    return hoursSinceLastTrigger >= hours
                }
                print("[ScheduleManager] → 今天已觸發過，跳過")
                return false
            }
        }

        // 根據重複規則判斷
        switch schedule.recurrence {
        case .none:
            // 單次排程 - 只要時間符合且未觸發過即可
            let shouldFire = schedule.lastTriggeredAt == nil
            print("[ScheduleManager] → 單次排程，lastTriggeredAt=\(schedule.lastTriggeredAt?.description ?? "nil")，觸發=\(shouldFire)")
            return shouldFire

        case .daily:
            // 每天 - 時間符合即可
            print("[ScheduleManager] → 每日排程，觸發=true")
            return true

        case .weekly(let weekdays):
            // 每週 - 檢查今天是否在指定的星期內
            let weekday = calendar.component(.weekday, from: now)
            // Calendar.weekday: 1=Sunday, 2=Monday... 轉換為 1=Monday...7=Sunday
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            let shouldFire = weekdays.contains(adjustedWeekday)
            print("[ScheduleManager] → 每週排程，今天=\(adjustedWeekday)，設定=\(weekdays)，觸發=\(shouldFire)")
            return shouldFire

        case .interval(let hours):
            // 間隔 - 檢查距離上次觸發是否已過指定小時數
            if let lastTriggered = schedule.lastTriggeredAt {
                let hoursSinceLastTrigger = calendar.dateComponents([.hour], from: lastTriggered, to: now).hour ?? 0
                let shouldFire = hoursSinceLastTrigger >= hours
                print("[ScheduleManager] → 間隔排程，距上次 \(hoursSinceLastTrigger) 小時，需要 \(hours) 小時，觸發=\(shouldFire)")
                return shouldFire
            }
            // 如果從未觸發過，只要時間符合就觸發
            print("[ScheduleManager] → 間隔排程（首次），觸發=true")
            return true
        }
    }

    // MARK: - Execution

    /// 執行排程動作
    func execute(_ schedule: Schedule) {
        switch schedule.action {
        case .startPomodoro:
            PomodoroTimer.shared.start()

        case .startTimer(let duration, let label):
            let manager = CountdownManager.shared
            if manager.timers.count < CountdownManager.maxTimerCount {
                manager.addTimer(label: label, duration: duration)
                if let timer = manager.timers.last {
                    manager.start(id: timer.id)
                }
                // 如果計時器是隱藏的，自動顯示
                if manager.settings.position == .hidden {
                    manager.settings.position = .below
                }
            }

        case .runCommand(let command):
            print("[ScheduleManager] 執行指令: \(command)")
            executeShellCommand(command)

        case .notification(let title, let message):
            sendNotification(title: title, message: message)
        }

        // 記錄執行
        print("[ScheduleManager] 執行排程：\(schedule.label) - \(schedule.action.displayName)")
    }

    /// 執行 Shell 指令
    private func executeShellCommand(_ command: String) {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    print("[ScheduleManager] 指令輸出: \(output)")
                }
                print("[ScheduleManager] 指令完成，退出碼: \(process.terminationStatus)")
            } catch {
                print("[ScheduleManager] 指令執行錯誤: \(error)")
            }
        }
    }

    /// 發送系統通知
    private func sendNotification(title: String, message: String) {
        guard canUseNotifications else {
            print("[ScheduleManager] 無法發送通知（缺少 bundle identifier）: \(title)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[ScheduleManager] 通知發送錯誤: \(error)")
            } else {
                print("[ScheduleManager] 通知已發送: \(title)")
            }
        }
    }

    // MARK: - Persistence

    private static let schedulesKey = "schedules"

    func load() {
        settings = .load()

        guard let data = UserDefaults.standard.data(forKey: Self.schedulesKey),
              let loaded = try? JSONDecoder().decode([Schedule].self, from: data)
        else {
            return
        }
        schedules = loaded
    }

    func save() {
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: Self.schedulesKey)
        }
    }
}
