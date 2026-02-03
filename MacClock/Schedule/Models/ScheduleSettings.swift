//
//  ScheduleSettings.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import Foundation

/// Display position for schedule widget relative to the clock
enum SchedulePosition: String, Codable {
    case hidden
    case above
    case below
}

/// Global settings for schedules
struct ScheduleSettings: Codable {
    var position: SchedulePosition
    var maxVisibleSchedules: Int
    var fontScale: CGFloat

    static var `default`: ScheduleSettings {
        ScheduleSettings(
            position: .below,
            maxVisibleSchedules: 3,
            fontScale: 1.0
        )
    }
}

// MARK: - UserDefaults persistence
extension ScheduleSettings {
    private static let settingsKey = "scheduleSettings"

    static func load() -> ScheduleSettings {
        guard let data = UserDefaults.standard.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(ScheduleSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }
}
