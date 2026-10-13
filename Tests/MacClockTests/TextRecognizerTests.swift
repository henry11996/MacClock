import AppKit
import CoreGraphics
import Testing
@testable import MacClock

/// 整合測試：實際呼叫 Vision 辨識程式繪製的文字（不需要螢幕錄製權限）
@Suite("TextRecognizer")
struct TextRecognizerTests {

    private func renderImage(lines: [String], fontSize: CGFloat = 48) throws -> CGImage {
        let width = 1200
        let lineHeight = Int(fontSize * 1.6)
        let height = lineHeight * lines.count + 40
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.black,
        ]
        for (index, line) in lines.enumerated() {
            let y = CGFloat(height - 20 - lineHeight * (index + 1))
            (line as NSString).draw(at: CGPoint(x: 20, y: y), withAttributes: attributes)
        }
        NSGraphicsContext.restoreGraphicsState()
        return try #require(context.makeImage())
    }

    @Test("辨識英文多行並依閱讀順序輸出")
    func recognizesEnglishLines() async throws {
        let image = try renderImage(lines: ["Hello MacClock", "Second line here"])
        let options = TextRecognitionOptions(languages: ["en-US"], accurate: true, usesLanguageCorrection: true)
        let fragments = try await TextRecognizer.recognize(image, options: options)
        let text = OCRTextFormatter.format(fragments, keepLineBreaks: true)
        let lines = text.split(separator: "\n").map(String.init)

        #expect(lines.count == 2)
        #expect(lines.first?.contains("Hello") == true)
        #expect(lines.last?.contains("Second") == true)
    }

    @Test("辨識繁體中文")
    func recognizesTraditionalChinese() async throws {
        let image = try renderImage(lines: ["繁體中文測試"])
        let options = TextRecognitionOptions(languages: ["zh-Hant", "en-US"], accurate: true, usesLanguageCorrection: true)
        let fragments = try await TextRecognizer.recognize(image, options: options)
        let text = OCRTextFormatter.format(fragments, keepLineBreaks: true)
        #expect(text.contains("中文"))
    }

    @Test("空白圖片回傳空結果")
    func blankImage() async throws {
        let image = try renderImage(lines: [""])
        let options = TextRecognitionOptions(languages: [], accurate: false, usesLanguageCorrection: false)
        let fragments = try await TextRecognizer.recognize(image, options: options)
        #expect(fragments.isEmpty)
    }

    @Test("過濾不支援的語言並維持順序")
    func filtersUnsupportedLanguages() {
        #expect(TextRecognizer.filterSupported(["xx-YY", "en-US", "zh-Hant"], supported: ["zh-Hant", "en-US"])
            == ["en-US", "zh-Hant"])
        #expect(TextRecognizer.filterSupported(["en-US"], supported: []) == ["en-US"])
    }

    @Test("由設定建立辨識選項")
    func optionsFromSettings() {
        let settings = OCRSettings.default.with(\.languages, [.korean, .english]).with(\.accurateMode, false)
        let options = TextRecognitionOptions(settings: settings)
        #expect(options.languages == ["ko-KR", "en-US"])
        #expect(options.accurate == false)
    }
}
