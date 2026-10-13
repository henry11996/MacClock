//
//  OCRSettings.swift
//  MacClock
//
//  螢幕文字辨識（OCR）設定
//

import Foundation

/// 可選的辨識語言（Vision 語言代碼）
nonisolated enum OCRLanguage: String, Codable, CaseIterable, Sendable {
    case traditionalChinese = "zh-Hant"
    case simplifiedChinese = "zh-Hans"
    case english = "en-US"
    case japanese = "ja-JP"
    case korean = "ko-KR"

    var displayName: String {
        switch self {
        case .traditionalChinese: return "繁體中文"
        case .simplifiedChinese: return "簡體中文"
        case .english: return "英文"
        case .japanese: return "日文"
        case .korean: return "韓文"
        }
    }
}

nonisolated struct OCRSettings: Codable, Equatable, Sendable {
    var hotKeyEnabled: Bool
    var hotKey: OCRHotKey
    /// 依優先順序排列；空陣列代表自動偵測
    var languages: [OCRLanguage]
    /// true = 精準模式（較慢）；false = 快速模式
    var accurateMode: Bool
    var usesLanguageCorrection: Bool
    var keepLineBreaks: Bool
    var showResultToast: Bool
    var playSound: Bool
    /// 框選時遮罩的深淺（0 = 不變暗，上限見 maxOverlayDimOpacity）
    var overlayDimOpacity: Double

    static let defaultOverlayDimOpacity: Double = 0.28
    static let maxOverlayDimOpacity: Double = 0.6
    /// 完全透明的視窗會讓滑鼠點擊穿透，因此實際繪製時至少保留肉眼不可見的 1%
    static let minimumDrawnDimOpacity: Double = 0.01

    static func clampedDimOpacity(_ value: Double) -> Double {
        guard value.isFinite else { return defaultOverlayDimOpacity }
        return min(max(value, 0), maxOverlayDimOpacity)
    }

    /// 遮罩實際繪製的透明度
    var drawnDimOpacity: Double {
        max(Self.clampedDimOpacity(overlayDimOpacity), Self.minimumDrawnDimOpacity)
    }

    static var `default`: OCRSettings {
        OCRSettings(
            hotKeyEnabled: true,
            hotKey: .default,
            languages: [.traditionalChinese, .english],
            accurateMode: true,
            usesLanguageCorrection: true,
            keepLineBreaks: true,
            showResultToast: true,
            playSound: true,
            overlayDimOpacity: defaultOverlayDimOpacity
        )
    }

    /// 解碼時容忍缺少欄位（未來新增設定時舊資料仍可讀取）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = OCRSettings.default
        hotKeyEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotKeyEnabled) ?? fallback.hotKeyEnabled
        hotKey = try container.decodeIfPresent(OCRHotKey.self, forKey: .hotKey) ?? fallback.hotKey
        languages = try container.decodeIfPresent([OCRLanguage].self, forKey: .languages) ?? fallback.languages
        accurateMode = try container.decodeIfPresent(Bool.self, forKey: .accurateMode) ?? fallback.accurateMode
        usesLanguageCorrection = try container.decodeIfPresent(Bool.self, forKey: .usesLanguageCorrection)
            ?? fallback.usesLanguageCorrection
        keepLineBreaks = try container.decodeIfPresent(Bool.self, forKey: .keepLineBreaks) ?? fallback.keepLineBreaks
        showResultToast = try container.decodeIfPresent(Bool.self, forKey: .showResultToast) ?? fallback.showResultToast
        playSound = try container.decodeIfPresent(Bool.self, forKey: .playSound) ?? fallback.playSound
        overlayDimOpacity = Self.clampedDimOpacity(
            try container.decodeIfPresent(Double.self, forKey: .overlayDimOpacity) ?? fallback.overlayDimOpacity
        )
    }

    init(
        hotKeyEnabled: Bool,
        hotKey: OCRHotKey,
        languages: [OCRLanguage],
        accurateMode: Bool,
        usesLanguageCorrection: Bool,
        keepLineBreaks: Bool,
        showResultToast: Bool,
        playSound: Bool,
        overlayDimOpacity: Double
    ) {
        self.hotKeyEnabled = hotKeyEnabled
        self.hotKey = hotKey
        self.languages = languages
        self.accurateMode = accurateMode
        self.usesLanguageCorrection = usesLanguageCorrection
        self.keepLineBreaks = keepLineBreaks
        self.showResultToast = showResultToast
        self.playSound = playSound
        self.overlayDimOpacity = Self.clampedDimOpacity(overlayDimOpacity)
    }

    /// 回傳修改過的新副本
    func with<Value>(_ keyPath: WritableKeyPath<OCRSettings, Value>, _ value: Value) -> OCRSettings {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

// MARK: - UserDefaults persistence
extension OCRSettings {
    static let settingsKey = "ocrSettings"

    static func load(from defaults: UserDefaults = .standard) -> OCRSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(OCRSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.settingsKey)
        }
    }
}

extension Notification.Name {
    static let ocrSettingsChanged = Notification.Name("ocrSettingsChanged")
}
