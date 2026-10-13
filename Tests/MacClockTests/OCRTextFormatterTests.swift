import CoreGraphics
import Testing
@testable import MacClock

@Suite("OCRTextFormatter")
struct OCRTextFormatterTests {

    /// 建立片段；y 為底部（Vision 座標原點在左下）
    private func fragment(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat = 0.2, height: CGFloat = 0.05)
        -> RecognizedFragment {
        RecognizedFragment(text: text, boundingBox: CGRect(x: x, y: y, width: width, height: height))
    }

    @Test("空輸入回傳空字串")
    func emptyInput() {
        #expect(OCRTextFormatter.format([], keepLineBreaks: true).isEmpty)
    }

    @Test("依上到下排序並保留換行")
    func ordersTopToBottom() {
        let fragments = [
            fragment("second", x: 0.1, y: 0.5),
            fragment("first", x: 0.1, y: 0.8),
            fragment("third", x: 0.1, y: 0.2),
        ]
        #expect(OCRTextFormatter.format(fragments, keepLineBreaks: true) == "first\nsecond\nthird")
    }

    @Test("同一行的片段依左到右合併並加空白")
    func mergesSameLineLeftToRight() {
        let fragments = [
            fragment("World", x: 0.5, y: 0.51),
            fragment("Hello", x: 0.1, y: 0.5),
        ]
        #expect(OCRTextFormatter.format(fragments, keepLineBreaks: true) == "Hello World")
    }

    @Test("中文片段之間不加空白")
    func cjkJoinWithoutSpace() {
        let fragments = [
            fragment("你好", x: 0.1, y: 0.5),
            fragment("世界", x: 0.5, y: 0.5),
        ]
        #expect(OCRTextFormatter.format(fragments, keepLineBreaks: true) == "你好世界")
    }

    @Test("不保留換行時合併成一段，處理英文斷字")
    func mergesLinesAndHyphenation() {
        let fragments = [
            fragment("This is an exam-", x: 0.1, y: 0.8, width: 0.6),
            fragment("ple of text", x: 0.1, y: 0.7, width: 0.6),
        ]
        #expect(OCRTextFormatter.format(fragments, keepLineBreaks: false) == "This is an example of text")
    }

    @Test("連字號後接大寫字母時不合併（例如 Wi-Fi 換行後的專有名詞）")
    func keepsHyphenBeforeUppercase() {
        let fragments = [
            fragment("state-", x: 0.1, y: 0.8),
            fragment("Of", x: 0.1, y: 0.7),
        ]
        #expect(OCRTextFormatter.format(fragments, keepLineBreaks: false) == "state- Of")
    }

    @Test("中文多行合併時不加空白")
    func mergesCJKLines() {
        let fragments = [
            fragment("第一行", x: 0.1, y: 0.8),
            fragment("第二行", x: 0.1, y: 0.7),
        ]
        #expect(OCRTextFormatter.format(fragments, keepLineBreaks: false) == "第一行第二行")
    }

    @Test("略過空白片段")
    func skipsBlankFragments() {
        let fragments = [
            fragment("   ", x: 0.1, y: 0.8),
            fragment("text", x: 0.1, y: 0.5),
        ]
        #expect(OCRTextFormatter.format(fragments, keepLineBreaks: true) == "text")
    }

    @Test("垂直重疊不足時視為不同行")
    func smallOverlapIsDifferentLine() {
        let lines = OCRTextFormatter.groupIntoLines([
            fragment("a", x: 0.1, y: 0.50, height: 0.05),
            fragment("b", x: 0.5, y: 0.46, height: 0.05),  // 只重疊 0.01（20%）
        ])
        #expect(lines.count == 2)
    }

    @Test("CJK 判斷", arguments: [
        ("中", true), ("あ", true), ("한", true), ("，", true), ("A", false), ("1", false), ("é", false),
    ])
    func cjkDetection(character: String, expected: Bool) throws {
        let scalar = try #require(character.unicodeScalars.first)
        #expect(OCRTextFormatter.isCJK(scalar) == expected)
    }

    @Test("中英混合時不在中文旁加空白")
    func mixedSeparator() {
        #expect(OCRTextFormatter.joinFragments(["iPhone", "手機", "Pro"]) == "iPhone手機Pro")
        #expect(OCRTextFormatter.joinFragments(["Mac", "Clock"]) == "Mac Clock")
    }
}
