//
//  TextRecognizer.swift
//  MacClock
//
//  使用 macOS 內建 Vision 框架進行文字辨識（完全離線，不上傳任何資料）
//

import CoreGraphics
import Foundation
import Vision

nonisolated struct TextRecognitionOptions: Equatable, Sendable {
    let languages: [String]
    let accurate: Bool
    let usesLanguageCorrection: Bool

    init(settings: OCRSettings) {
        languages = settings.languages.map(\.rawValue)
        accurate = settings.accurateMode
        usesLanguageCorrection = settings.usesLanguageCorrection
    }

    init(languages: [String], accurate: Bool, usesLanguageCorrection: Bool) {
        self.languages = languages
        self.accurate = accurate
        self.usesLanguageCorrection = usesLanguageCorrection
    }
}

nonisolated enum TextRecognizer {

    /// 執行 OCR；Vision 的 perform 為同步阻塞呼叫，因此丟到背景執行緒避免卡住 UI
    static func recognize(_ image: CGImage, options: TextRecognitionOptions) async throws -> [RecognizedFragment] {
        try await Task.detached(priority: .userInitiated) {
            try recognizeSync(image, options: options)
        }.value
    }

    static func recognizeSync(_ image: CGImage, options: TextRecognitionOptions) throws -> [RecognizedFragment] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = options.accurate ? .accurate : .fast
        request.usesLanguageCorrection = options.usesLanguageCorrection

        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let languages = filterSupported(options.languages, supported: supported)
        if languages.isEmpty {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = languages
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedFragment(text: candidate.string, boundingBox: observation.boundingBox)
        }
    }

    /// 只保留 Vision 支援的語言，維持使用者設定的優先順序
    static func filterSupported(_ requested: [String], supported: [String]) -> [String] {
        guard !supported.isEmpty else { return requested }
        let supportedSet = Set(supported)
        return requested.filter { supportedSet.contains($0) }
    }
}
