//
//  TranslationService.swift
//  MacClock
//
//  使用 macOS 內建 Translation 框架翻譯 OCR 文字（本機處理，語言包需事先下載）
//  原文語言以 NaturalLanguage 自動偵測
//

import Foundation
import NaturalLanguage
import Translation

/// 可選的翻譯目標語言
nonisolated enum TranslationLanguage: String, CaseIterable, Codable, Sendable {
    case traditionalChinese = "zh-Hant"
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case thai = "th"
    case vietnamese = "vi"

    static let defaultTarget: TranslationLanguage = .traditionalChinese

    /// 同一語言族群（繁簡中文視為同一族群）
    var family: String {
        switch self {
        case .traditionalChinese, .simplifiedChinese: return "zh"
        default: return rawValue
        }
    }

    var displayName: String {
        switch self {
        case .traditionalChinese: return "繁體中文"
        case .simplifiedChinese: return "簡體中文"
        case .english: return "英文"
        case .japanese: return "日文"
        case .korean: return "韓文"
        case .french: return "法文"
        case .german: return "德文"
        case .spanish: return "西班牙文"
        case .italian: return "義大利文"
        case .portuguese: return "葡萄牙文"
        case .russian: return "俄文"
        case .thai: return "泰文"
        case .vietnamese: return "越南文"
        }
    }

    /// 由語言代碼取得（容忍地區碼，例如 "en-US" → .english、"pt-BR" → .portuguese）
    static func from(code: String) -> TranslationLanguage? {
        if let exact = TranslationLanguage(rawValue: code) { return exact }
        let base = code.split(separator: "-").first.map(String.init) ?? code
        switch base {
        case "zh": return code.contains("Hans") || code.contains("CN") ? .simplifiedChinese : .traditionalChinese
        default: return TranslationLanguage(rawValue: base)
        }
    }
}

nonisolated struct TranslationResult: Equatable, Sendable {
    let original: String
    let translated: String
    let source: TranslationLanguage?
    let sourceCode: String
    let target: TranslationLanguage
}

nonisolated enum TranslationFailure: Error, Equatable, Sendable {
    case nothingToTranslate
    case unknownLanguage
    case unsupported(source: String, target: TranslationLanguage)
    /// 語言包尚未下載
    case notInstalled(source: String, target: TranslationLanguage)
    case timedOut
    case failed(String)

    var message: String {
        switch self {
        case .nothingToTranslate:
            return "沒有可翻譯的文字"
        case .unknownLanguage:
            return "無法判斷原文語言"
        case let .unsupported(source, target):
            return "系統不支援從「\(TranslationService.displayName(forCode: source))」翻譯成「\(target.displayName)」"
        case let .notInstalled(source, target):
            return "需要先下載「\(TranslationService.displayName(forCode: source))」與「\(target.displayName)」的翻譯語言包"
        case .timedOut:
            return "翻譯逾時，請重試"
        case let .failed(reason):
            return "翻譯失敗：\(reason)"
        }
    }

    var canDownloadLanguages: Bool {
        if case .notInstalled = self { return true }
        return false
    }
}

nonisolated enum TranslationService {
    /// 系統設定 →「語言與地區」（翻譯語言在此頁面下方）
    static let languageSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")

    /// 偵測主要語言；文字太短或無法判斷時回傳 nil
    static func detectLanguageCode(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        return language.rawValue
    }

    /// 翻譯逾時
    static let timeout: Duration = .seconds(30)

    /// 決定翻譯方向：原文已是目標語言時改翻成備用語言（目標是英文時備用繁中，否則備用英文）
    /// 繁簡中文視為同一語言（系統不支援繁簡互轉），中文原文搭配中文目標時改翻英文
    static func resolveTarget(sourceCode: String, preferred: TranslationLanguage) -> TranslationLanguage {
        guard let source = TranslationLanguage.from(code: sourceCode), source.family == preferred.family else {
            return preferred
        }
        return preferred == .english ? .traditionalChinese : .english
    }

    static func displayName(forCode code: String) -> String {
        if let language = TranslationLanguage.from(code: code) { return language.displayName }
        return Locale.current.localizedString(forIdentifier: code) ?? code
    }

    static func translate(_ text: String, preferredTarget: TranslationLanguage) async -> Result<TranslationResult, TranslationFailure> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.nothingToTranslate) }
        guard let sourceCode = detectLanguageCode(trimmed) else { return .failure(.unknownLanguage) }

        let target = resolveTarget(sourceCode: sourceCode, preferred: preferredTarget)
        let sourceLanguage = Locale.Language(identifier: sourceCode)
        let targetLanguage = Locale.Language(identifier: target.rawValue)

        switch await LanguageAvailability().status(from: sourceLanguage, to: targetLanguage) {
        case .unsupported:
            return .failure(.unsupported(source: sourceCode, target: target))
        case .supported:
            return .failure(.notInstalled(source: sourceCode, target: target))
        case .installed:
            break
        @unknown default:
            break
        }

        do {
            let translated = try await withTimeout(timeout) {
                let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
                return try await session.translate(trimmed).targetText
            }
            return .success(TranslationResult(
                original: trimmed,
                translated: translated,
                source: TranslationLanguage.from(code: sourceCode),
                sourceCode: sourceCode,
                target: target
            ))
        } catch is TimeoutError {
            return .failure(.timedOut)
        } catch {
            if TranslationError.notInstalled ~= error {
                return .failure(.notInstalled(source: sourceCode, target: target))
            }
            return .failure(.failed(error.localizedDescription))
        }
    }
}

nonisolated struct TimeoutError: Error {}

/// 執行 operation，超過時間則取消並拋出 TimeoutError
nonisolated func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: duration)
            throw TimeoutError()
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw TimeoutError() }
        return first
    }
}
