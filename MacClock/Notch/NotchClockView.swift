//
//  NotchClockView.swift
//  MacClock
//
//  Created by Claude on 2026/2/12.
//

import Combine
import SwiftUI

/// Left notch panel: displays time and Pomodoro status
struct NotchClockView: View {
    @State private var currentTime = Date()
    var timer = PomodoroTimer.shared

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var clockStyle: ClockStyle {
        timer.settings.clockStyle
    }

    private var clockFont: Font {
        let baseSize: CGFloat = 13
        let scale = timer.settings.clockFontScale
        return .system(size: baseSize * scale, weight: .medium, design: .default)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Time display
            clockView
                .font(clockFont)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
        .background(.black)
        .clipShape(.rect(bottomLeadingRadius: 10))
        .onReceive(clockTimer) { input in
            currentTime = input
        }
        .onTapGesture {
            NotificationCenter.default.post(name: .showSettings, object: SettingsTab.clock)
        }
        .contextMenu {
            Button("關閉瀏海模式") {
                NotificationCenter.default.post(name: .notchModeChanged, object: false)
            }
            Divider()
            Button("設定...") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }
        }
    }

    @ViewBuilder
    private var clockView: some View {
        switch clockStyle {
        case .standard:
            // 週五 2月13日 12:34
            Text("\(currentTime, format: .dateTime.weekday()) \(currentTime, format: .dateTime.month().day()) \(currentTime, format: .dateTime.hour().minute())")
        case .withSeconds:
            // 週五 2月13日 12:34:56
            Text("\(currentTime, format: .dateTime.weekday()) \(currentTime, format: .dateTime.month().day()) \(currentTime, format: .dateTime.hour().minute().second())")
        case .timeOnly:
            // 12:34
            Text(currentTime, format: .dateTime.hour().minute())
        case .timeWithSeconds:
            // 12:34:56
            Text(currentTime, format: .dateTime.hour().minute().second())
        case .compact:
            // 12:34 1/1
            Text("\(currentTime, format: .dateTime.hour().minute()) \(currentTime, format: .dateTime.month(.defaultDigits).day())")
        }
    }
}
