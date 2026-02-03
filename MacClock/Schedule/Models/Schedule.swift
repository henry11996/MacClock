//
//  Schedule.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import Foundation

/// 排程可執行的動作類型
enum ScheduleAction: Codable, Equatable {
    case startPomodoro
    case startTimer(duration: TimeInterval, label: String)
    case runCommand(command: String)
    case notification(title: String, message: String)

    // MARK: - Display

    var displayName: String {
        switch self {
        case .startPomodoro:
            return "啟動番茄鐘"
        case .startTimer:
            return "啟動計時器"
        case .runCommand:
            return "執行指令"
        case .notification:
            return "發送通知"
        }
    }

    var icon: String {
        switch self {
        case .startPomodoro:
            return "timer"
        case .startTimer:
            return "hourglass"
        case .runCommand:
            return "terminal.fill"
        case .notification:
            return "bell.fill"
        }
    }

    var description: String {
        switch self {
        case .startPomodoro:
            return "啟動番茄鐘"
        case .startTimer(let duration, let label):
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            if minutes > 0 && seconds > 0 {
                return "\(label) (\(minutes)分\(seconds)秒)"
            } else if minutes > 0 {
                return "\(label) (\(minutes)分鐘)"
            } else {
                return "\(label) (\(seconds)秒)"
            }
        case .runCommand(let command):
            let truncated = command.count > 30 ? String(command.prefix(27)) + "..." : command
            return truncated
        case .notification(let title, _):
            return title
        }
    }
}

/// 重複規則
enum RecurrenceRule: Codable, Equatable {
    case none                           // 單次（不重複）
    case daily                          // 每天
    case weekly(weekdays: Set<Int>)     // 每週指定星期 (1=週一...7=週日)
    case interval(hours: Int)           // 每 N 小時

    // MARK: - Display

    var displayName: String {
        switch self {
        case .none:
            return "不重複"
        case .daily:
            return "每天"
        case .weekly(let weekdays):
            if weekdays.count == 7 {
                return "每天"
            } else if weekdays == Set([1, 2, 3, 4, 5]) {
                return "週一至週五"
            } else if weekdays == Set([6, 7]) {
                return "週末"
            } else {
                let names = weekdays.sorted().map { Self.weekdayName($0) }
                return names.joined(separator: "、")
            }
        case .interval(let hours):
            if hours == 24 {
                return "每天"
            } else if hours >= 24 && hours % 24 == 0 {
                return "每 \(hours / 24) 天"
            } else {
                return "每 \(hours) 小時"
            }
        }
    }

    static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "週一"
        case 2: return "週二"
        case 3: return "週三"
        case 4: return "週四"
        case 5: return "週五"
        case 6: return "週六"
        case 7: return "週日"
        default: return ""
        }
    }

    static func weekdayShortName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "一"
        case 2: return "二"
        case 3: return "三"
        case 4: return "四"
        case 5: return "五"
        case 6: return "六"
        case 7: return "日"
        default: return ""
        }
    }
}

/// 排程資料模型
struct Schedule: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    var action: ScheduleAction
    var time: DateComponents           // 時:分
    var recurrence: RecurrenceRule
    var isEnabled: Bool
    var lastTriggeredAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        action: ScheduleAction,
        time: DateComponents,
        recurrence: RecurrenceRule = .none,
        isEnabled: Bool = true,
        lastTriggeredAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.action = action
        self.time = time
        self.recurrence = recurrence
        self.isEnabled = isEnabled
        self.lastTriggeredAt = lastTriggeredAt
        self.createdAt = createdAt
    }

    /// 格式化的時間字串 (HH:mm)
    var formattedTime: String {
        let hour = time.hour ?? 0
        let minute = time.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }

    /// 下次觸發的日期時間（供參考）
    func nextTriggerDate(from now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let nowHour = nowComponents.hour ?? 0
        let nowMinute = nowComponents.minute ?? 0

        let scheduleHour = time.hour ?? 0
        let scheduleMinute = time.minute ?? 0

        // 判斷今天是否還能觸發
        let todayAlreadyPassed = (nowHour > scheduleHour) ||
            (nowHour == scheduleHour && nowMinute >= scheduleMinute)

        switch recurrence {
        case .none:
            // 單次排程 - 如果已觸發過則返回 nil
            if lastTriggeredAt != nil {
                return nil
            }
            // 否則返回今天或明天的觸發時間
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = scheduleHour
            components.minute = scheduleMinute
            components.second = 0
            guard var triggerDate = calendar.date(from: components) else { return nil }
            if todayAlreadyPassed {
                triggerDate = calendar.date(byAdding: .day, value: 1, to: triggerDate) ?? triggerDate
            }
            return triggerDate

        case .daily:
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = scheduleHour
            components.minute = scheduleMinute
            components.second = 0
            guard var triggerDate = calendar.date(from: components) else { return nil }
            if todayAlreadyPassed {
                triggerDate = calendar.date(byAdding: .day, value: 1, to: triggerDate) ?? triggerDate
            }
            return triggerDate

        case .weekly(let weekdays):
            guard !weekdays.isEmpty else { return nil }
            // 從今天開始找下一個符合的星期
            for dayOffset in 0..<8 {
                guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let weekday = calendar.component(.weekday, from: checkDate)
                // Calendar.weekday: 1=Sunday, 2=Monday... 轉換為 1=Monday...7=Sunday
                let adjustedWeekday = weekday == 1 ? 7 : weekday - 1

                if weekdays.contains(adjustedWeekday) {
                    // 如果是今天，檢查時間是否已過
                    if dayOffset == 0 && todayAlreadyPassed {
                        continue
                    }
                    var components = calendar.dateComponents([.year, .month, .day], from: checkDate)
                    components.hour = scheduleHour
                    components.minute = scheduleMinute
                    components.second = 0
                    return calendar.date(from: components)
                }
            }
            return nil

        case .interval(let hours):
            // 如果有上次觸發時間，從那時候往後算
            if let lastTriggered = lastTriggeredAt {
                return calendar.date(byAdding: .hour, value: hours, to: lastTriggered)
            }
            // 否則從設定的時間開始
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = scheduleHour
            components.minute = scheduleMinute
            components.second = 0
            guard var triggerDate = calendar.date(from: components) else { return nil }
            if todayAlreadyPassed {
                triggerDate = calendar.date(byAdding: .hour, value: hours, to: triggerDate) ?? triggerDate
            }
            return triggerDate
        }
    }
}
