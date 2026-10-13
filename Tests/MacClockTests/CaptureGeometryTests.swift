import CoreGraphics
import Testing
@testable import MacClock

@Suite("CaptureGeometry")
struct CaptureGeometryTests {

    @Test("任意拖曳方向都產生正寬高矩形")
    func normalizesDragDirection() {
        let rect = CaptureGeometry.rect(from: CGPoint(x: 100, y: 200), to: CGPoint(x: 40, y: 50))
        #expect(rect == CGRect(x: 40, y: 50, width: 60, height: 150))
    }

    @Test("過小或空的選取無效")
    func validation() {
        #expect(!CaptureGeometry.isValidSelection(.null))
        #expect(!CaptureGeometry.isValidSelection(CGRect(x: 0, y: 0, width: 3, height: 100)))
        #expect(CaptureGeometry.isValidSelection(CGRect(x: 0, y: 0, width: 4, height: 4)))
    }

    @Test("AppKit 座標轉 CoreGraphics 座標（翻轉 Y 軸）")
    func flipsToCoreGraphics() {
        // 主螢幕高 1000，AppKit 中距底部 100、高 50 → CG 中距頂部 850
        let rect = CaptureGeometry.toCoreGraphicsGlobal(
            CGRect(x: 10, y: 100, width: 200, height: 50),
            primaryScreenHeight: 1000
        )
        #expect(rect == CGRect(x: 10, y: 850, width: 200, height: 50))
    }

    @Test("轉換到第二螢幕的區域座標")
    func displayLocalOnSecondaryDisplay() throws {
        let secondary = CGRect(x: 1440, y: -200, width: 1920, height: 1080)
        let local = try #require(CaptureGeometry.displayLocalRect(
            CGRect(x: 1500, y: 0, width: 100, height: 100),
            displayFrame: secondary
        ))
        #expect(local == CGRect(x: 60, y: 200, width: 100, height: 100))
    }

    @Test("跨越螢幕邊界時裁切到螢幕內")
    func clipsToDisplay() throws {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let local = try #require(CaptureGeometry.displayLocalRect(
            CGRect(x: 900, y: 700, width: 300, height: 300),
            displayFrame: display
        ))
        #expect(local == CGRect(x: 900, y: 700, width: 100, height: 100))
    }

    @Test("不相交時回傳 nil")
    func nonIntersecting() {
        #expect(CaptureGeometry.displayLocalRect(
            CGRect(x: 2000, y: 0, width: 10, height: 10),
            displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 800)
        ) == nil)
    }

    @Test("依縮放倍率計算像素尺寸，最少 1px")
    func pixelSize() {
        let retina = CaptureGeometry.pixelSize(of: CGRect(x: 0, y: 0, width: 100.4, height: 50), scale: 2)
        #expect(retina.width == 201)
        #expect(retina.height == 100)

        let tiny = CaptureGeometry.pixelSize(of: CGRect(x: 0, y: 0, width: 0.1, height: 0.1), scale: 0)
        #expect(tiny.width == 1)
        #expect(tiny.height == 1)
    }

    @Test("選出相交面積最大的螢幕")
    func bestMatchingDisplay() {
        let frames = [
            CGRect(x: 0, y: 0, width: 1000, height: 800),
            CGRect(x: 1000, y: 0, width: 1000, height: 800),
        ]
        #expect(CaptureGeometry.bestMatchingFrame(for: CGRect(x: 950, y: 0, width: 200, height: 10), in: frames) == 1)
        #expect(CaptureGeometry.bestMatchingFrame(for: CGRect(x: 5000, y: 0, width: 10, height: 10), in: frames) == nil)
    }

    @Test("超大選取等比縮小到長邊上限")
    func capsPixelSize() {
        let size = CaptureGeometry.pixelSize(of: CGRect(x: 0, y: 0, width: 6016, height: 3384), scale: 2)
        #expect(size.width == 8192)
        #expect(size.height == 4608)
    }

    @Test("副螢幕在主螢幕上方與左方（負座標）")
    func negativeCoordinateDisplays() throws {
        // AppKit：主螢幕高 1000；上方副螢幕 AppKit y=1000..2080 → CG y=-1080..0
        let above = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        let cg = CaptureGeometry.toCoreGraphicsGlobal(
            CGRect(x: 100, y: 1500, width: 200, height: 100), primaryScreenHeight: 1000
        )
        #expect(cg == CGRect(x: 100, y: -600, width: 200, height: 100))
        let local = try #require(CaptureGeometry.displayLocalRect(cg, displayFrame: above))
        #expect(local == CGRect(x: 100, y: 480, width: 200, height: 100))

        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let leftLocal = try #require(CaptureGeometry.displayLocalRect(
            CGRect(x: -100, y: 10, width: 50, height: 50), displayFrame: left
        ))
        #expect(leftLocal == CGRect(x: 1820, y: 10, width: 50, height: 50))
    }
}
