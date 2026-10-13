import Foundation
import Testing
@testable import MacClock

@Suite("OCRSettings & OCRHotKey")
struct OCRSettingsTests {
    private let defaults: UserDefaults
    private let suiteName = "MacClockTests.OCRSettings.\(UUID().uuidString)"

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    @Test("沒有資料時回傳預設值")
    func loadsDefault() {
        #expect(OCRSettings.load(from: defaults) == .default)
    }

    @Test("存檔後可完整讀回")
    func roundTrip() {
        let settings = OCRSettings.default
            .with(\.languages, [.japanese])
            .with(\.keepLineBreaks, false)
            .with(\.hotKey, OCRHotKey(keyCode: 0x1F, carbonModifiers: OCRHotKey.controlFlag, keyDisplay: "O"))
        settings.save(to: defaults)
        #expect(OCRSettings.load(from: defaults) == settings)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("缺少欄位的舊資料以預設值補齊")
    func decodesPartialData() throws {
        let json = Data(#"{"keepLineBreaks": false}"#.utf8)
        let settings = try JSONDecoder().decode(OCRSettings.self, from: json)
        #expect(settings.keepLineBreaks == false)
        #expect(settings.languages == OCRSettings.default.languages)
        #expect(settings.hotKey == .default)
    }

    @Test("損毀資料時回傳預設值")
    func corruptedDataFallsBack() {
        defaults.set(Data("not json".utf8), forKey: OCRSettings.settingsKey)
        #expect(OCRSettings.load(from: defaults) == .default)
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("with 回傳新副本且不改動原值")
    func withIsImmutable() {
        let original = OCRSettings.default
        let changed = original.with(\.playSound, false)
        #expect(original.playSound == true)
        #expect(changed.playSound == false)
    }

    @Test("預設快捷鍵為 ⇧⌘2")
    func defaultHotKeyDisplay() {
        #expect(OCRHotKey.default.displayString == "⇧⌘2")
        #expect(OCRHotKey.default.isValid)
    }

    @Test("修飾鍵依 ⌃⌥⇧⌘ 順序顯示")
    func modifierOrder() {
        let flags = OCRHotKey.carbonModifiers(command: true, shift: true, option: true, control: true)
        let hotKey = OCRHotKey(keyCode: 0x1F, carbonModifiers: flags, keyDisplay: "O")
        #expect(hotKey.displayString == "⌃⌥⇧⌘O")
    }

    @Test("必須包含 ⌘/⌃/⌥", arguments: [
        (OCRHotKey.shiftFlag, false),
        (UInt32(0), false),
        (OCRHotKey.optionFlag, true),
        (OCRHotKey.controlFlag | OCRHotKey.shiftFlag, true),
    ])
    func validity(modifiers: UInt32, expected: Bool) {
        #expect(OCRHotKey(keyCode: 0x13, carbonModifiers: modifiers, keyDisplay: "2").isValid == expected)
    }

    @Test("空白按鍵名稱無效")
    func emptyKeyDisplayInvalid() {
        #expect(!OCRHotKey(keyCode: 0x13, carbonModifiers: OCRHotKey.commandFlag, keyDisplay: "").isValid)
    }

    @Test("特殊按鍵名稱")
    func specialKeys() {
        #expect(OCRHotKey.specialKeyName(for: 0x31) == "Space")
        #expect(OCRHotKey.specialKeyName(for: 0x60) == "F5")
        #expect(OCRHotKey.specialKeyName(for: 0x13) == nil)
    }
}
