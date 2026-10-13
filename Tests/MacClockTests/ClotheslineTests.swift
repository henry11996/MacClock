import CoreGraphics
import Foundation
import Testing
@testable import MacClock

@Suite("Clothesline")
struct ClotheslineTests {
    private func item(_ name: String, source: ClotheslineItem.Source = .screenshot) -> ClotheslineItem {
        ClotheslineItem(fileURL: URL(fileURLWithPath: "/tmp/\(name).png"), source: source)
    }

    // MARK: - List

    @Test("新項目放最前面，超過上限擠掉最舊的")
    func addingTrimsOldest() {
        let a = item("a"), b = item("b"), c = item("c")
        let result = ClotheslineList.adding(c, to: [b, a], maxItems: 2)
        #expect(result.items == [c, b])
        #expect(result.evicted == [a])
    }

    @Test("同一個檔案不重複掛，且不會被列為要刪除")
    func addingDeduplicates() {
        let old = item("a", source: .ocr)
        let new = ClotheslineItem(fileURL: old.fileURL, source: .ocr)
        let result = ClotheslineList.adding(new, to: [old, item("b")], maxItems: 5)
        #expect(result.items.count == 2)
        #expect(result.items.first == new)
        #expect(result.evicted.isEmpty)
    }

    @Test("只有 OCR 畫面屬於 App")
    func ownership() {
        #expect(item("a", source: .ocr).isOwnedByApp)
        #expect(!item("a", source: .screenshot).isOwnedByApp)
    }

    // MARK: - Settings

    @Test("上限夾在範圍內，缺欄位用預設")
    func settingsClamping() throws {
        #expect(ClotheslineSettings.default.with(\.maxItems, 100).maxItems == ClotheslineSettings.maxItemsRange.upperBound)
        #expect(ClotheslineSettings.default.with(\.maxItems, 0).maxItems == ClotheslineSettings.maxItemsRange.lowerBound)
        let decoded = try JSONDecoder().decode(ClotheslineSettings.self, from: Data(#"{"maxItems": 999}"#.utf8))
        #expect(decoded.maxItems == ClotheslineSettings.maxItemsRange.upperBound)
        #expect(decoded.isEnabled == false)
        #expect(decoded.hangOCRCaptures == true)
    }

    // MARK: - File filter

    private let start = Date(timeIntervalSince1970: 1_000)

    @Test("只收啟動後建立的圖片")
    func candidateBasics() {
        #expect(ScreenshotFileFilter.isCandidate(fileName: "Shot.png", createdAt: start.addingTimeInterval(1), fileSize: 100,
                                                 startedAt: start, hasScreenshotTag: false, requiresScreenshotTag: false))
        #expect(!ScreenshotFileFilter.isCandidate(fileName: "Shot.png", createdAt: start.addingTimeInterval(-1), fileSize: 100,
                                                  startedAt: start, hasScreenshotTag: false, requiresScreenshotTag: false))
        #expect(!ScreenshotFileFilter.isCandidate(fileName: "notes.txt", createdAt: start.addingTimeInterval(1), fileSize: 100,
                                                  startedAt: start, hasScreenshotTag: false, requiresScreenshotTag: false))
    }

    @Test("略過隱藏暫存檔與過大檔案")
    func candidateRejectsHiddenAndHuge() {
        #expect(!ScreenshotFileFilter.isCandidate(fileName: ".Screenshot.png", createdAt: start.addingTimeInterval(1), fileSize: 100,
                                                  startedAt: start, hasScreenshotTag: true, requiresScreenshotTag: false))
        #expect(!ScreenshotFileFilter.isCandidate(fileName: "big.png", createdAt: start.addingTimeInterval(1),
                                                  fileSize: ScreenshotFileFilter.maxFileSize + 1,
                                                  startedAt: start, hasScreenshotTag: false, requiresScreenshotTag: false))
    }

    @Test("桌面上只收系統標記為截圖的檔案")
    func desktopRequiresTag() {
        let home = URL(fileURLWithPath: "/Users/test", isDirectory: true)
        #expect(ScreenshotFileFilter.requiresScreenshotTag(folder: home.appendingPathComponent("Desktop"), realHome: home))
        #expect(!ScreenshotFileFilter.requiresScreenshotTag(folder: home.appendingPathComponent("Pictures/Shots"), realHome: home))
        #expect(!ScreenshotFileFilter.isCandidate(fileName: "photo.jpg", createdAt: start.addingTimeInterval(1), fileSize: 1,
                                                  startedAt: start, hasScreenshotTag: false, requiresScreenshotTag: true))
        #expect(ScreenshotFileFilter.isCandidate(fileName: "Screenshot.png", createdAt: start.addingTimeInterval(1), fileSize: 1,
                                                 startedAt: start, hasScreenshotTag: true, requiresScreenshotTag: true))
    }

    @Test("展開 ~ 為真正的家目錄")
    func expandTilde() {
        let home = URL(fileURLWithPath: "/Users/test", isDirectory: true)
        #expect(ScreenshotFileFilter.expandTilde("~/Pictures", realHome: home).path == "/Users/test/Pictures")
        #expect(ScreenshotFileFilter.expandTilde("~", realHome: home).path == "/Users/test")
        #expect(ScreenshotFileFilter.expandTilde("/Volumes/X", realHome: home).path == "/Volumes/X")
    }

    // MARK: - Layout

    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let notch = CGRect(x: 666, y: 950, width: 180, height: 32)

    @Test("面板貼在選單列下方，以瀏海為中心")
    func panelUnderNotch() {
        let frame = ClotheslineLayout.panelFrame(screenFrame: screen, menuBarHeight: 32, centerX: notch.midX, itemCount: 3)
        #expect(frame.maxY == screen.maxY - 32)
        #expect(abs(frame.midX - notch.midX) < 0.5)
        #expect(frame.height == ClotheslineLayout.panelHeight)
    }

    @Test("項目很多時寬度不超過螢幕")
    func panelClampedToScreen() {
        let frame = ClotheslineLayout.panelFrame(screenFrame: screen, menuBarHeight: 32, centerX: notch.midX, itemCount: 30)
        #expect(frame.minX >= screen.minX)
        #expect(frame.maxX <= screen.maxX)
    }

    @Test("滑鼠在面板、瀏海或兩者之間都保持展開")
    func keepsOpen() {
        let panel = ClotheslineLayout.panelFrame(screenFrame: screen, menuBarHeight: 32, centerX: notch.midX, itemCount: 3)
        #expect(ClotheslineLayout.keepsOpen(mouse: CGPoint(x: notch.midX, y: notch.midY), panelFrame: panel, triggerRect: notch))
        #expect(ClotheslineLayout.keepsOpen(mouse: CGPoint(x: panel.midX, y: panel.midY), panelFrame: panel, triggerRect: notch))
        #expect(!ClotheslineLayout.keepsOpen(mouse: CGPoint(x: 10, y: 10), panelFrame: panel, triggerRect: notch))
    }

    @Test("沒有瀏海時觸發區在選單列中央")
    func fallbackTrigger() {
        let trigger = ClotheslineLayout.triggerRect(screenFrame: screen, menuBarHeight: 24, notchRect: nil)
        #expect(trigger.midX == screen.midX)
        #expect(trigger.maxY == screen.maxY)
        #expect(trigger.height == 24)
    }

    // MARK: - Capture file policy

    private let captures = URL(fileURLWithPath: "/tmp/container/MacClock/Captures", isDirectory: true)

    @Test("只允許刪除 Captures 內 App 產生的檔案")
    func ownedCaptureFile() {
        #expect(CaptureFilePolicy.isOwnedCaptureFile(captures.appendingPathComponent("Capture-1.png"), capturesFolder: captures))
    }

    @Test("拒絕繞過路徑檢查的檔案", arguments: [
        "/tmp/container/MacClock/Captures2/Capture-1.png",          // 前綴相同的相鄰資料夾
        "/tmp/container/MacClock/Captures/../secret/Capture-1.png", // ../ 跳出
        "/tmp/container/MacClock/Captures/sub/Capture-1.png",       // 子資料夾
        "/tmp/container/MacClock/Captures/notes.png",               // 檔名不符
        "/tmp/container/MacClock/Captures/Capture-1.txt",           // 副檔名不符
        "/Users/test/Desktop/Capture-1.png",                        // 使用者檔案
    ])
    func rejectsUnsafePaths(path: String) {
        #expect(!CaptureFilePolicy.isOwnedCaptureFile(URL(fileURLWithPath: path), capturesFolder: captures))
    }

    @Test("讀回資料時丟棄被竄改的 OCR 項目，保留截圖項目")
    func sanitizesTamperedItems() {
        let legit = ClotheslineItem(fileURL: captures.appendingPathComponent("Capture-1.png"), source: .ocr)
        let tampered = ClotheslineItem(fileURL: URL(fileURLWithPath: "/Users/test/Documents/thesis.png"), source: .ocr)
        let screenshot = ClotheslineItem(fileURL: URL(fileURLWithPath: "/Users/test/Desktop/Shot.png"), source: .screenshot)
        let result = CaptureFilePolicy.sanitized([legit, tampered, screenshot], capturesFolder: captures)
        #expect(result == [legit, screenshot])
    }
}
