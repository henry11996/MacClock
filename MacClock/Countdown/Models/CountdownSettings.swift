//
//  CountdownSettings.swift
//  MacClock
//
//  Created by Claude on 2026/2/3.
//

import Foundation

/// Display position for countdown timers relative to the clock
enum CountdownPosition: String, Codable {
    case hidden
    case above
    case below
}

/// Language detection for localized display names
private enum AppLanguage {
    case english
    case chineseTraditional
    case chineseSimplified
    case japanese
    case korean
    case french
    case german
    case spanish

    static var current: AppLanguage {
        guard let langCode = Locale.current.language.languageCode?.identifier else {
            return .english
        }
        switch langCode {
        case "zh":
            // 區分繁體/簡體
            let region = Locale.current.region?.identifier ?? ""
            if region == "TW" || region == "HK" || region == "MO" {
                return .chineseTraditional
            }
            return .chineseSimplified
        case "ja": return .japanese
        case "ko": return .korean
        case "fr": return .french
        case "de": return .german
        case "es": return .spanish
        default: return .english
        }
    }
}

/// Available system sounds for timer completion
enum SystemSound: String, Codable, CaseIterable {
    case glass = "Glass"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case tink = "Tink"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case hero = "Hero"
    case morse = "Morse"
    case basso = "Basso"

    var displayName: String {
        switch AppLanguage.current {
        case .chineseTraditional, .chineseSimplified:
            return chineseName
        case .japanese:
            return japaneseName
        case .korean:
            return koreanName
        case .french:
            return frenchName
        case .german:
            return germanName
        case .spanish:
            return spanishName
        case .english:
            return rawValue
        }
    }

    private var chineseName: String {
        switch self {
        case .glass: return "玻璃聲"
        case .ping: return "叮聲"
        case .pop: return "氣泡聲"
        case .purr: return "震動聲"
        case .sosumi: return "經典音效"
        case .submarine: return "潛水艇"
        case .tink: return "輕敲聲"
        case .blow: return "吹氣聲"
        case .bottle: return "瓶子聲"
        case .frog: return "青蛙聲"
        case .funk: return "放克聲"
        case .hero: return "英雄聲"
        case .morse: return "摩斯密碼"
        case .basso: return "低音聲"
        }
    }

    private var japaneseName: String {
        switch self {
        case .glass: return "ガラス"
        case .ping: return "ピン"
        case .pop: return "ポップ"
        case .purr: return "ゴロゴロ"
        case .sosumi: return "ソスミ"
        case .submarine: return "潜水艦"
        case .tink: return "チンク"
        case .blow: return "ブロー"
        case .bottle: return "ボトル"
        case .frog: return "カエル"
        case .funk: return "ファンク"
        case .hero: return "ヒーロー"
        case .morse: return "モールス"
        case .basso: return "バッソ"
        }
    }

    private var koreanName: String {
        switch self {
        case .glass: return "유리"
        case .ping: return "핑"
        case .pop: return "팝"
        case .purr: return "가르랑"
        case .sosumi: return "소수미"
        case .submarine: return "잠수함"
        case .tink: return "팅크"
        case .blow: return "불기"
        case .bottle: return "병"
        case .frog: return "개구리"
        case .funk: return "펑크"
        case .hero: return "영웅"
        case .morse: return "모스"
        case .basso: return "바소"
        }
    }

    private var frenchName: String {
        switch self {
        case .glass: return "Verre"
        case .ping: return "Ping"
        case .pop: return "Pop"
        case .purr: return "Ronron"
        case .sosumi: return "Sosumi"
        case .submarine: return "Sous-marin"
        case .tink: return "Tintement"
        case .blow: return "Souffle"
        case .bottle: return "Bouteille"
        case .frog: return "Grenouille"
        case .funk: return "Funk"
        case .hero: return "Héros"
        case .morse: return "Morse"
        case .basso: return "Basse"
        }
    }

    private var germanName: String {
        switch self {
        case .glass: return "Glas"
        case .ping: return "Ping"
        case .pop: return "Pop"
        case .purr: return "Schnurren"
        case .sosumi: return "Sosumi"
        case .submarine: return "U-Boot"
        case .tink: return "Klingeln"
        case .blow: return "Blasen"
        case .bottle: return "Flasche"
        case .frog: return "Frosch"
        case .funk: return "Funk"
        case .hero: return "Held"
        case .morse: return "Morse"
        case .basso: return "Bass"
        }
    }

    private var spanishName: String {
        switch self {
        case .glass: return "Cristal"
        case .ping: return "Ping"
        case .pop: return "Pop"
        case .purr: return "Ronroneo"
        case .sosumi: return "Sosumi"
        case .submarine: return "Submarino"
        case .tink: return "Tintineo"
        case .blow: return "Soplo"
        case .bottle: return "Botella"
        case .frog: return "Rana"
        case .funk: return "Funk"
        case .hero: return "Héroe"
        case .morse: return "Morse"
        case .basso: return "Bajo"
        }
    }
}

/// Global settings for countdown timers
struct CountdownSettings: Codable {
    var position: CountdownPosition
    var maxVisibleTimers: Int
    var defaultDuration: TimeInterval
    var soundName: SystemSound
    var soundVolume: Float
    var fontScale: CGFloat

    static var `default`: CountdownSettings {
        CountdownSettings(
            position: .hidden,
            maxVisibleTimers: 15,
            defaultDuration: 5 * 60,  // 5 minutes
            soundName: .glass,
            soundVolume: 0.7,
            fontScale: 1.0
        )
    }
}

// MARK: - UserDefaults persistence
extension CountdownSettings {
    private static let settingsKey = "countdownSettings"

    static func load() -> CountdownSettings {
        guard let data = UserDefaults.standard.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(CountdownSettings.self, from: data)
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
