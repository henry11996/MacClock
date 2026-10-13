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

    @Test("滑出版面：panel 從瀏海左緣開始、高度與瀏海相同")
    func slideLayout() {
        let layout = OCRToastLayout.notchSlideLayout(notchRect: notch, screenFrame: screen, contentWidth: 260)
        #expect(layout.panelFrame.minX == notch.minX)
        #expect(layout.panelFrame.minY == notch.minY)
        #expect(layout.panelFrame.height == notch.height)
        #expect(layout.toastWidth == 260)
        // 展開後左緣在瀏海右緣往內 overlap 處
        #expect(layout.panelFrame.minX + layout.restX == notch.maxX - OCRToastLayout.notchOverlap)
        #expect(layout.panelFrame.maxX == notch.maxX - OCRToastLayout.notchOverlap + 260)
    }

    @Test("收合時提示右緣藏在瀏海內")
    func slideHiddenInsideNotch() {
        let layout = OCRToastLayout.notchSlideLayout(notchRect: notch, screenFrame: screen, contentWidth: 260)
        let hiddenRightEdge = layout.panelFrame.minX + layout.restX + layout.hiddenOffset + layout.toastWidth
        #expect(hiddenRightEdge <= notch.maxX)
    }

    @Test("往下彈出：與瀏海置中、頂端貼齊螢幕上緣")
    func dropLayout() {
        let layout = OCRToastLayout.notchDropLayout(notchRect: notch)
        #expect(layout.panelFrame.midX == notch.midX)
        #expect(layout.panelFrame.maxY == notch.maxY)
        #expect(layout.panelFrame.width == notch.width + OCRToastLayout.dropExtraWidth * 2)
        #expect(layout.collapsedHeight == notch.height)
        #expect(layout.contentHeight == OCRToastLayout.dropContentHeight)
    }
}
