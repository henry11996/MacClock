import CoreGraphics
import Foundation
import Testing
@testable import MacClock

@Suite("Translation")
struct TranslationTests {

    @Test("語言代碼對應（容忍地區碼）", arguments: [
        ("zh-Hant", TranslationLanguage.traditionalChinese),
        ("zh-Hans", .simplifiedChinese),
        ("zh-TW", .traditionalChinese),
        ("zh-CN", .simplifiedChinese),
        ("en", .english),
        ("en-US", .english),
        ("ja", .japanese),
        ("pt-BR", .portuguese),
    ])
    func languageFromCode(code: String, expected: TranslationLanguage) {
        #expect(TranslationLanguage.from(code: code) == expected)
    }

    @Test("不支援的代碼回傳 nil")
    func unknownCode() {
        #expect(TranslationLanguage.from(code: "xx") == nil)
    }

    @Test("原文已是目標語言時改翻成備用語言")
    func resolveTarget() {
        #expect(TranslationService.resolveTarget(sourceCode: "en", preferred: .traditionalChinese) == .traditionalChinese)
        #expect(TranslationService.resolveTarget(sourceCode: "zh-Hant", preferred: .traditionalChinese) == .english)
        #expect(TranslationService.resolveTarget(sourceCode: "en", preferred: .english) == .traditionalChinese)
        // 繁簡中文視為同一語言：簡中原文搭配繁中目標時改翻英文
        #expect(TranslationService.resolveTarget(sourceCode: "zh-Hans", preferred: .traditionalChinese) == .english)
        #expect(TranslationService.resolveTarget(sourceCode: "zh-Hant", preferred: .simplifiedChinese) == .english)
        #expect(TranslationService.resolveTarget(sourceCode: "ja", preferred: .simplifiedChinese) == .simplifiedChinese)
    }

    @Test("偵測常見語言", arguments: [
        ("The quick brown fox jumps over the lazy dog.", "en"),
        ("今天天氣很好，我們一起去公園散步吧。", "zh-Hant"),
        ("これは日本語の文章です。今日はいい天気ですね。", "ja"),
    ])
    func detectsLanguage(text: String, expected: String) {
        #expect(TranslationService.detectLanguageCode(text) == expected)
    }

    @Test("空白文字不翻譯")
    func emptyText() async {
        let result = await TranslationService.translate("   \n", preferredTarget: .english)
        #expect(result == .failure(.nothingToTranslate))
    }

    @Test("只有語言包未下載時提供下載按鈕")
    func downloadAffordance() {
        #expect(TranslationFailure.notInstalled(source: "en", target: .traditionalChinese).canDownloadLanguages)
        #expect(!TranslationFailure.unknownLanguage.canDownloadLanguages)
        #expect(TranslationFailure.notInstalled(source: "en", target: .traditionalChinese).message.contains("英文"))
    }

    @Test("設定：預設 ⇧⌘1、繁中、自動複製；舊資料缺欄位或未知語言用預設")
    func settingsDefaults() throws {
        let defaults = OCRSettings.default
        #expect(defaults.translateHotKey.displayString == "⇧⌘1")
        #expect(defaults.translationTarget == "zh-Hant")
        #expect(defaults.autoCopyTranslation)
        let old = try JSONDecoder().decode(OCRSettings.self, from: Data("{}".utf8))
        #expect(old.translateHotKey == .defaultTranslate)
        let unknown = try JSONDecoder().decode(OCRSettings.self, from: Data(#"{"translationTarget": "klingon"}"#.utf8))
        #expect(unknown.translationTarget == "zh-Hant")
    }

    @Test("卡片位置：貼在選單列下方、以瀏海為中心、不超出螢幕")
    func cardLayout() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = TranslationCardLayout.frame(screenFrame: screen, menuBarHeight: 32, centerX: 756, contentHeight: 200)
        #expect(frame.maxY == screen.maxY - 32 - TranslationCardLayout.topGap)
        #expect(frame.midX == 756)
        #expect(frame.height == 200)

        let tall = TranslationCardLayout.frame(screenFrame: screen, menuBarHeight: 32, centerX: 756, contentHeight: 2000)
        #expect(tall.height == TranslationCardLayout.maxHeight)

        let nearEdge = TranslationCardLayout.frame(screenFrame: screen, menuBarHeight: 32, centerX: 20, contentHeight: 100)
        #expect(nearEdge.minX >= screen.minX + TranslationCardLayout.screenMargin)
    }

    @Test("逾時會拋出 TimeoutError")
    func timeoutThrows() async {
        await #expect(throws: TimeoutError.self) {
            try await withTimeout(.milliseconds(50)) {
                try await Task.sleep(for: .seconds(5))
                return 1
            }
        }
    }

    @Test("在時間內完成時回傳結果")
    func timeoutPassesThrough() async throws {
        let value = try await withTimeout(.seconds(5)) { 42 }
        #expect(value == 42)
    }
}
