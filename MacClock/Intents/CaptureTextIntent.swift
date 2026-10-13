//
//  CaptureTextIntent.swift
//  MacClock
//
//  Shortcuts / Siri：框選螢幕區域並辨識文字
//

import AppIntents

struct CaptureTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Text from Screen"
    static let description = IntentDescription("Select a screen region and copy the recognized text to the clipboard")

    @MainActor
    func perform() async throws -> some IntentResult {
        OCRCoordinator.shared.startCapture()
        return .result()
    }
}
