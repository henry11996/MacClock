import CoreGraphics
import Testing
@testable import MacClock

@Suite("OCRToastLayout")
struct OCRToastLayoutTests {
    // 14 吋 MacBook Pro：螢幕 1512×982，瀏海寬約 180、高 32
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let notch = CGRect(x: 666, y: 950, width: 180, height: 32)

    @Test("貼齊瀏海右緣（往內重疊）且與選單列同高")
    func notchRightFrame() {
        let frame = OCRToastLayout.notchRightFrame(notchRect: notch, screenFrame: screen, contentWidth: 260)
        #expect(frame == CGRect(x: 846 - OCRToastLayout.notchOverlap, y: 950, width: 260, height: 32))
    }

    @Test("內容太寬時縮短，不超出螢幕右緣")
    func clampsToScreenEdge() {
        let frame = OCRToastLayout.notchRightFrame(notchRect: notch, screenFrame: screen, contentWidth: 2000)
        #expect(frame.maxX == screen.maxX - OCRToastLayout.screenMargin)
    }

    @Test("副螢幕座標（瀏海螢幕不在原點）")
    func offsetScreen() {
        let offsetScreen = screen.offsetBy(dx: -1512, dy: 0)
        let offsetNotch = notch.offsetBy(dx: -1512, dy: 0)
        let frame = OCRToastLayout.notchRightFrame(notchRect: offsetNotch, screenFrame: offsetScreen, contentWidth: 200)
        #expect(frame.minX == offsetNotch.maxX - OCRToastLayout.notchOverlap)
        #expect(frame.maxX <= offsetScreen.maxX)
    }

    @Test("畫面上方置中")
    func topCenter() {
        let origin = OCRToastLayout.topCenterOrigin(
            size: CGSize(width: 340, height: 60),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )
        #expect(origin == CGPoint(x: 330, y: 800 - 60 - OCRToastLayout.topCenterInset))
    }

    @Test("單行預覽：換行轉空白並截斷")
    @MainActor
    func preview() {
        #expect(OCRToastController.preview(of: "a\nb") == "a b")
        let long = String(repeating: "字", count: 200)
        let result = OCRToastController.preview(of: long)
        #expect(result.count == 121)
        #expect(result.hasSuffix("…"))
    }

    @Test("瀏海右側已無空間時寬度為 0")
    func noAvailableSpace() {
        let tightScreen = CGRect(x: 0, y: 0, width: notch.maxX, height: 982)
        let frame = OCRToastLayout.notchRightFrame(notchRect: notch, screenFrame: tightScreen, contentWidth: 200)
        #expect(frame.width == 0)
    }

    @Test("展開後往下延伸、頂端不變")
    func expandedFrame() {
        let base = CGRect(x: 838, y: 950, width: 260, height: 32)
        let frame = OCRToastLayout.expandedNotchFrame(base, extraHeight: 6)
        #expect(frame == CGRect(x: 838, y: 944, width: 260, height: 38))
        #expect(frame.maxY == base.maxY)
    }
}
