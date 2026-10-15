//
//  OCRHotKey.swift
//  MacClock
//
//  全域快捷鍵定義（Carbon key code + modifiers）
//

import Foundation

nonisolated struct OCRHotKey: Codable, Equatable, Sendable {
    /// Carbon 虛擬鍵碼（kVK_*）
    let keyCode: UInt32
    /// Carbon modifier 旗標（cmdKey / shiftKey / optionKey / controlKey）
    let carbonModifiers: UInt32
    /// 錄製時記下的按鍵名稱（例如 "2"、"O"、"F5"）
    let keyDisplay: String

    // Carbon modifier 常數（與 Carbon.HIToolbox 相同，避免模型層依賴 Carbon）
    static let commandFlag: UInt32 = 1 << 8   // cmdKey
    static let shiftFlag: UInt32 = 1 << 9     // shiftKey
    static let optionFlag: UInt32 = 1 << 11   // optionKey
    static let controlFlag: UInt32 = 1 << 12  // controlKey

    /// 預設 ⇧⌘2（與 TextSniper 相同，且不與系統截圖 ⇧⌘3/4/5 衝突）
    static let `default` = OCRHotKey(keyCode: 0x13, carbonModifiers: shiftFlag | commandFlag, keyDisplay: "2")
    /// 擷取並翻譯：⇧⌘1
    static let defaultTranslate = OCRHotKey(keyCode: 0x12, carbonModifiers: shiftFlag | commandFlag, keyDisplay: "1")

    /// 需包含 ⌘ / ⌃ / ⌥ 其中之一，避免單獨 Shift 或無修飾鍵搶走一般輸入
    var isValid: Bool {
        carbonModifiers & (Self.commandFlag | Self.controlFlag | Self.optionFlag) != 0 && !keyDisplay.isEmpty
    }

    /// 依 macOS 慣例順序顯示：⌃⌥⇧⌘ + 按鍵
    var displayString: String {
        var symbols = ""
        if carbonModifiers & Self.controlFlag != 0 { symbols += "⌃" }
        if carbonModifiers & Self.optionFlag != 0 { symbols += "⌥" }
        if carbonModifiers & Self.shiftFlag != 0 { symbols += "⇧" }
        if carbonModifiers & Self.commandFlag != 0 { symbols += "⌘" }
        return symbols + keyDisplay
    }

    /// 由 NSEvent 修飾鍵狀態轉換為 Carbon 旗標
    static func carbonModifiers(command: Bool, shift: Bool, option: Bool, control: Bool) -> UInt32 {
        var flags: UInt32 = 0
        if command { flags |= commandFlag }
        if shift { flags |= shiftFlag }
        if option { flags |= optionFlag }
        if control { flags |= controlFlag }
        return flags
    }

    /// 特殊按鍵的顯示名稱（其餘使用鍵盤輸出的字元）
    static func specialKeyName(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 0x31: return "Space"
        case 0x24: return "↩"
        case 0x30: return "⇥"
        case 0x33: return "⌫"
        case 0x7B: return "←"
        case 0x7C: return "→"
        case 0x7D: return "↓"
        case 0x7E: return "↑"
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        default: return nil
        }
    }
}
