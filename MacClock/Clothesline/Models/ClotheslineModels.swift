//
//  ClotheslineModels.swift
//  MacClock
//
//  截圖晾衣繩：資料模型與純邏輯
//  靈感來自 Tendedero（https://github.com/alejandrobujan/tendedero，MIT License）
//

import Foundation

/// 掛在繩子上的一張圖
nonisolated struct ClotheslineItem: Identifiable, Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable {
        /// 使用者資料夾中的截圖（不屬於 MacClock，移除時不刪檔）
        case screenshot
        /// OCR 框選時保存的畫面（存在 App 自己的資料夾，移除時一併刪檔）
        case ocr
    }

    let id: UUID
    let fileURL: URL
    let addedAt: Date
    let source: Source

    init(id: UUID = UUID(), fileURL: URL, addedAt: Date = Date(), source: Source) {
        self.id = id
        self.fileURL = fileURL
        self.addedAt = addedAt
        self.source = source
    }

    /// 是否為 MacClock 自己建立的檔案
    var isOwnedByApp: Bool { source == .ocr }
}

nonisolated struct ClotheslineSettings: Codable, Equatable, Sendable {
    static let maxItemsRange: ClosedRange<Int> = 3...30

    var isEnabled: Bool
    var maxItems: Int
    var hangOCRCaptures: Bool
    /// 使用者選擇的截圖資料夾（security-scoped bookmark）
    var folderBookmark: Data?
    /// 顯示用的資料夾路徑
    var folderPath: String?

    static var `default`: ClotheslineSettings {
        ClotheslineSettings(isEnabled: false, maxItems: 12, hangOCRCaptures: true, folderBookmark: nil, folderPath: nil)
    }

    init(isEnabled: Bool, maxItems: Int, hangOCRCaptures: Bool, folderBookmark: Data?, folderPath: String?) {
        self.isEnabled = isEnabled
        self.maxItems = Self.clampedMaxItems(maxItems)
        self.hangOCRCaptures = hangOCRCaptures
        self.folderBookmark = folderBookmark
        self.folderPath = folderPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = ClotheslineSettings.default
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? fallback.isEnabled
        maxItems = Self.clampedMaxItems(
            try container.decodeIfPresent(Int.self, forKey: .maxItems) ?? fallback.maxItems
        )
        hangOCRCaptures = try container.decodeIfPresent(Bool.self, forKey: .hangOCRCaptures) ?? fallback.hangOCRCaptures
        folderBookmark = try container.decodeIfPresent(Data.self, forKey: .folderBookmark)
        folderPath = try container.decodeIfPresent(String.self, forKey: .folderPath)
    }

    static func clampedMaxItems(_ value: Int) -> Int {
        min(max(value, maxItemsRange.lowerBound), maxItemsRange.upperBound)
    }

    func with<Value>(_ keyPath: WritableKeyPath<ClotheslineSettings, Value>, _ value: Value) -> ClotheslineSettings {
        var copy = self
        copy[keyPath: keyPath] = value
        copy.maxItems = Self.clampedMaxItems(copy.maxItems)
        return copy
    }
}

/// 繩子上項目的增減（純函式，方便測試）
nonisolated enum ClotheslineList {
    /// 新項目放在最前面（最靠近瀏海）；同一個檔案不重複掛；超過上限時移除最舊的
    /// - Returns: 新清單，以及被擠掉的項目（呼叫端負責刪除 App 自己的檔案）
    static func adding(
        _ item: ClotheslineItem,
        to items: [ClotheslineItem],
        maxItems: Int
    ) -> (items: [ClotheslineItem], evicted: [ClotheslineItem]) {
        // 同檔案的舊項目直接被取代；它與新項目指向同一個檔案，所以不能列為 evicted（否則會刪掉新項目的檔案）
        let deduped = items.filter { $0.fileURL.standardizedFileURL != item.fileURL.standardizedFileURL }
        return trimmed([item] + deduped, maxItems: maxItems)
    }

    static func trimmed(_ items: [ClotheslineItem], maxItems: Int) -> (items: [ClotheslineItem], evicted: [ClotheslineItem]) {
        let limit = max(1, maxItems)
        return (Array(items.prefix(limit)), Array(items.dropFirst(limit)))
    }
}

/// App 自己保存的 OCR 畫面檔：只有符合這個規則的檔案才允許刪除
nonisolated enum CaptureFilePolicy {
    static let filePrefix = "Capture-"
    static let fileExtension = "png"

    /// 路徑必須在 Captures 資料夾內（標準化、解析捷徑後比對，含結尾斜線，避免 Captures2/ 或 ../ 繞過），
    /// 且檔名符合 App 產生的格式
    static func isOwnedCaptureFile(_ url: URL, capturesFolder: URL) -> Bool {
        let file = url.standardizedFileURL.resolvingSymlinksInPath()
        let folder = capturesFolder.standardizedFileURL.resolvingSymlinksInPath().path
        let folderPrefix = folder.hasSuffix("/") ? folder : folder + "/"
        guard file.path.hasPrefix(folderPrefix) else { return false }
        // 只允許直接位於 Captures 底下，不接受子資料夾
        guard !file.path.dropFirst(folderPrefix.count).contains("/") else { return false }
        return file.lastPathComponent.hasPrefix(filePrefix) && file.pathExtension.lowercased() == fileExtension
    }

    /// 讀回持久化資料時驗證：宣稱是 OCR 畫面但路徑不符的項目一律丟棄（防止被竄改後誤刪檔案）
    static func sanitized(_ items: [ClotheslineItem], capturesFolder: URL) -> [ClotheslineItem] {
        items.filter { $0.source != .ocr || isOwnedCaptureFile($0.fileURL, capturesFolder: capturesFolder) }
    }
}

/// 判斷資料夾中的檔案是否為要掛上的截圖
nonisolated enum ScreenshotFileFilter {
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tif", "tiff", "gif", "webp"]
    /// 系統截圖會帶的延伸屬性
    static let screenshotAttribute = "com.apple.metadata:kMDItemIsScreenCapture"
    /// 超過此大小不處理（避免讀取異常大的檔案）
    static let maxFileSize = 200 * 1024 * 1024

    static func isCandidate(
        fileName: String,
        createdAt: Date?,
        fileSize: Int?,
        startedAt: Date,
        hasScreenshotTag: Bool,
        requiresScreenshotTag: Bool
    ) -> Bool {
        // 系統寫入時會先用隱藏的暫存檔名
        guard !fileName.hasPrefix(".") else { return false }
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard imageExtensions.contains(ext) else { return false }
        guard let createdAt, createdAt >= startedAt else { return false }
        if let fileSize, fileSize > maxFileSize { return false }
        return !requiresScreenshotTag || hasScreenshotTag
    }

    /// 桌面上檔案很雜，只收系統標記為截圖的；專用資料夾則收所有圖片
    static func requiresScreenshotTag(folder: URL, realHome: URL) -> Bool {
        folder.standardizedFileURL.path == realHome.appendingPathComponent("Desktop").standardizedFileURL.path
    }

    /// 將 "~/..." 展開成實際的家目錄（沙盒內的 NSHomeDirectory 指向容器，不能用）
    static func expandTilde(_ path: String, realHome: URL) -> URL {
        if path == "~" { return realHome }
        if path.hasPrefix("~/") {
            return realHome.appendingPathComponent(String(path.dropFirst(2)), isDirectory: true)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
