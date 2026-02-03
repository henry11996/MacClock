//
//  PomodoroIntent.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import AppIntents

enum PomodoroAction: String, AppEnum {
    case start, pause, reset

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Pomodoro Action")
    static let caseDisplayRepresentations: [PomodoroAction: DisplayRepresentation] = [
        .start: "Start",
        .pause: "Pause",
        .reset: "Reset"
    ]
}

struct PomodoroIntent: AppIntent {
    static let title: LocalizedStringResource = "Control Pomodoro"
    static let description = IntentDescription("Control the Pomodoro timer in MacClock")

    @Parameter(title: "Action")
    var action: PomodoroAction

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$action) Pomodoro timer")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let pomodoro = PomodoroTimer.shared

        switch action {
        case .start:
            pomodoro.start()
            return .result(value: "番茄鐘已啟動")
        case .pause:
            pomodoro.pause()
            return .result(value: "番茄鐘已暫停")
        case .reset:
            pomodoro.reset()
            return .result(value: "番茄鐘已重置")
        }
    }
}
