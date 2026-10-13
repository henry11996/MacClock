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

    @Test("遮罩深淺預設 28%，舊資料缺欄位時使用預設")
    func dimOpacityDefault() throws {
        #expect(OCRSettings.default.overlayDimOpacity == 0.28)
        let settings = try JSONDecoder().decode(OCRSettings.self, from: Data("{}".utf8))
        #expect(settings.overlayDimOpacity == OCRSettings.defaultOverlayDimOpacity)
    }

    @Test("遮罩深淺限制在 0~上限", arguments: [
        (-0.5, 0.0), (0.3, 0.3), (2.0, OCRSettings.maxOverlayDimOpacity), (Double.nan, OCRSettings.defaultOverlayDimOpacity),
    ])
    func dimOpacityClamping(input: Double, expected: Double) {
        #expect(OCRSettings.clampedDimOpacity(input) == expected)
        #expect(OCRSettings.default.with(\.overlayDimOpacity, input).drawnDimOpacity
            == max(expected, OCRSettings.minimumDrawnDimOpacity))
    }

    @Test("解碼時夾住超出範圍的值")
    func dimOpacityDecodeClamps() throws {
        let settings = try JSONDecoder().decode(OCRSettings.self, from: Data(#"{"overlayDimOpacity": 5}"#.utf8))
        #expect(settings.overlayDimOpacity == OCRSettings.maxOverlayDimOpacity)
    }

    @Test("設為 0 時實際仍繪製 1% 以避免點擊穿透")
    func zeroOpacityStillCapturesClicks() {
        let settings = OCRSettings.default.with(\.overlayDimOpacity, 0)
        #expect(settings.overlayDimOpacity == 0)
        #expect(settings.drawnDimOpacity == OCRSettings.minimumDrawnDimOpacity)
    }

    @Test("提示位置預設為瀏海右側，舊資料缺欄位或未知值時使用預設")
    func toastPositionDecoding() throws {
        #expect(OCRSettings.default.toastPosition == .notchRight)
        let missing = try JSONDecoder().decode(OCRSettings.self, from: Data("{}".utf8))
        #expect(missing.toastPosition == .notchRight)
        let unknown = try JSONDecoder().decode(OCRSettings.self, from: Data(#"{"toastPosition": "bottomLeft"}"#.utf8))
        #expect(unknown.toastPosition == .notchRight)
        let saved = try JSONDecoder().decode(OCRSettings.self, from: Data(#"{"toastPosition": "topCenter"}"#.utf8))
        #expect(saved.toastPosition == .topCenter)
    }

    @Test("切換語言時維持 allCases 順序")
    func languageToggleOrder() {
        #expect(OCRLanguage.toggled(.traditionalChinese, isOn: true, in: [.english]) == [.traditionalChinese, .english])
        #expect(OCRLanguage.toggled(.english, isOn: false, in: [.traditionalChinese, .english]) == [.traditionalChinese])
        #expect(OCRLanguage.toggled(.english, isOn: true, in: [.english]) == [.english])
        #expect(OCRLanguage.toggled(.korean, isOn: false, in: []).isEmpty)
    }

    @Test("瀏海下方樣式可存取")
    func notchBelowDecoding() throws {
        let saved = try JSONDecoder().decode(OCRSettings.self, from: Data(#"{"toastPosition": "notchBelow"}"#.utf8))
        #expect(saved.toastPosition == .notchBelow)
        #expect(OCRToastPosition.notchBelow.usesNotch)
        #expect(!OCRToastPosition.topCenter.usesNotch)
    }
}
