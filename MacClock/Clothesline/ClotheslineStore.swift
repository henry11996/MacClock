//
//  ClotheslineStore.swift
//  MacClock
//
//  截圖晾衣繩的狀態與動作：監看資料夾、增減項目、複製、開啟
//

import AppKit
import ImageIO
import OSLog
import UniformTypeIdentifiers

@MainActor
@Observable
final class ClotheslineStore {
    static let shared = ClotheslineStore()

    private static let settingsKey = "clotheslineSettings"
    private static let itemsKey = "clotheslineItems"
    private static let logger = Logger(subsystem: "com.henry.MacClock", category: "Clothesline")

    /// OCR 框選畫面的保存位置（App 容器內）
    nonisolated static let capturesFolder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MacClock/Captures", isDirectory: true)
    }()

    private(set) var settings: ClotheslineSettings
    private(set) var items: [ClotheslineItem] = []
    /// 目前監看中的資料夾（nil 代表未設定或無法存取）
    private(set) var watchedFolder: URL?
    private(set) var folderError: String?
    /// 新項目掛上時遞增，讓面板短暫展開
    private(set) var arrivalCount = 0

    private var watcher: ScreenshotWatcher?
    private var accessedFolder: URL?

    private init() {
        settings = Self.loadSettings()
        items = Self.loadItems()
    }

    // MARK: - Lifecycle

    func start() {
        applyWatching()
        dropMissingCaptures()
        removeOrphanCaptures()
    }

    func update(_ newSettings: ClotheslineSettings) {
        guard newSettings != settings else { return }
        let folderChanged = newSettings.folderBookmark != settings.folderBookmark
        let watchingChanged = newSettings.isEnabled != settings.isEnabled || folderChanged
        settings = newSettings
        if folderChanged {
            // 舊資料夾的截圖已失去存取權（縮圖、複製都會失敗），換資料夾時一併拿下
            replaceItems(items.filter { $0.source == .ocr }, evicted: [])
        }
        saveSettings()
        if items.count > settings.maxItems {
            let result = ClotheslineList.trimmed(items, maxItems: settings.maxItems)
            replaceItems(result.items, evicted: result.evicted)
        }
        if watchingChanged {
            applyWatching()
        }
    }

    /// 讓使用者選擇截圖資料夾並開始監看
    func chooseFolder() {
        guard let url = ScreenshotFolderAccess.chooseFolder() else { return }
        do {
            let bookmark = try ScreenshotFolderAccess.makeBookmark(for: url)
            update(settings
                .with(\.folderBookmark, bookmark)
                .with(\.folderPath, url.path)
                .with(\.isEnabled, true))
        } catch {
            folderError = error.localizedDescription
        }
    }

    // MARK: - Items

    func add(_ url: URL, source: ClotheslineItem.Source) {
        let item = ClotheslineItem(fileURL: url, source: source)
        let result = ClotheslineList.adding(item, to: items, maxItems: settings.maxItems)
        replaceItems(result.items, evicted: result.evicted)
        arrivalCount += 1
    }

    /// 從繩子上拿下；使用者的截圖不會被刪除，只有 App 自己保存的 OCR 畫面會刪檔
    func remove(_ item: ClotheslineItem) {
        ThumbnailLoader.evict(item.fileURL)
        replaceItems(items.filter { $0.id != item.id }, evicted: [item])
    }

    func clear() {
        replaceItems([], evicted: items)
    }

    /// 複製圖片到剪貼簿（同時提供檔案，貼到 Finder 時會是檔案）
    /// 檔案在背景讀取；讀取成功後才清空剪貼簿，失敗時保留使用者原本的內容
    @discardableResult
    func copy(_ item: ClotheslineItem) async -> Bool {
        let url = item.fileURL
        let data = await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= ScreenshotFileFilter.maxFileSize
            else { return nil }
            return try? Data(contentsOf: url, options: .mappedIfSafe)
        }.value
        guard let data, let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) else {
            return false
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type.identifier))
        pasteboard.setString(url.absoluteString, forType: .fileURL)
        return true
    }

    /// 用「預覽程式」開啟
    func open(_ item: ClotheslineItem) {
        let configuration = NSWorkspace.OpenConfiguration()
        if let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
            NSWorkspace.shared.open([item.fileURL], withApplicationAt: preview, configuration: configuration)
        } else {
            NSWorkspace.shared.open(item.fileURL)
        }
    }

    func revealInFinder(_ item: ClotheslineItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }

    /// 保存 OCR 框選的畫面並掛上繩子
    func hangCapture(_ image: CGImage) {
        guard settings.isEnabled, settings.hangOCRCaptures else { return }
        let folder = Self.capturesFolder
        let fileURL = folder.appendingPathComponent(
            "\(CaptureFilePolicy.filePrefix)\(Self.timestamp()).\(CaptureFilePolicy.fileExtension)"
        )
        Task {
            let saved = await Task.detached(priority: .utility) {
                Self.writePNG(image, to: fileURL, folder: folder)
            }.value
            if saved {
                add(fileURL, source: .ocr)
            } else {
                Self.logger.error("Failed to save OCR capture")
            }
        }
    }

    // MARK: - Watching

    private func applyWatching() {
        watcher?.stop()
        watcher = nil
        accessedFolder?.stopAccessingSecurityScopedResource()
        accessedFolder = nil
        watchedFolder = nil
        folderError = nil

        guard settings.isEnabled, let bookmark = settings.folderBookmark else { return }
        guard let resolved = ScreenshotFolderAccess.resolve(bookmark) else {
            folderError = "找不到之前選擇的資料夾，請重新選擇"
            return
        }
        guard resolved.url.startAccessingSecurityScopedResource() else {
            folderError = "沒有權限讀取資料夾，請重新選擇"
            return
        }
        accessedFolder = resolved.url
        if resolved.isStale, let fresh = try? ScreenshotFolderAccess.makeBookmark(for: resolved.url) {
            settings = settings.with(\.folderBookmark, fresh)
            saveSettings()
        }

        let requiresTag = ScreenshotFileFilter.requiresScreenshotTag(
            folder: resolved.url,
            realHome: ScreenshotFolderAccess.realHomeDirectory
        )
        let newWatcher = ScreenshotWatcher(folder: resolved.url, requiresScreenshotTag: requiresTag) { [weak self] url in
            self?.add(url, source: .screenshot)
        }
        newWatcher.start()
        watcher = newWatcher
        watchedFolder = resolved.url
    }

    // MARK: - Persistence

    private func replaceItems(_ newItems: [ClotheslineItem], evicted: [ClotheslineItem]) {
        items = newItems
        saveItems()
        let stillUsed = Set(newItems.map { $0.fileURL.standardizedFileURL })
        let ownedFiles = evicted
            .filter { $0.isOwnedByApp && !stillUsed.contains($0.fileURL.standardizedFileURL) }
            .map(\.fileURL)
        guard !ownedFiles.isEmpty else { return }
        let folder = Self.capturesFolder
        Task.detached(priority: .utility) {
            for url in ownedFiles where CaptureFilePolicy.isOwnedCaptureFile(url, capturesFolder: folder) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    /// 只檢查 App 自己的 OCR 畫面是否還在。使用者資料夾的截圖在沙盒中需要資料夾權限才能確認，
    /// 沒有權限時 fileExists 會回傳 false，不能據此拿下
    private func dropMissingCaptures() {
        let existing = items.filter { $0.source != .ocr || FileManager.default.fileExists(atPath: $0.fileURL.path) }
        if existing.count != items.count {
            items = existing
            saveItems()
        }
    }

    /// 清掉 Captures 資料夾中已不在繩子上的檔案（例如 App 異常結束留下的）
    private func removeOrphanCaptures() {
        let folder = Self.capturesFolder
        let inUse = Set(items.filter { $0.source == .ocr }.map { $0.fileURL.standardizedFileURL.path })
        Task.detached(priority: .utility) {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files
            where !inUse.contains(file.standardizedFileURL.path)
                && CaptureFilePolicy.isOwnedCaptureFile(file, capturesFolder: folder) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private static func loadSettings() -> ClotheslineSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(ClotheslineSettings.self, from: data)
        else { return .default }
        return settings
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    private static func loadItems() -> [ClotheslineItem] {
        guard let data = UserDefaults.standard.data(forKey: itemsKey),
              let items = try? JSONDecoder().decode([ClotheslineItem].self, from: data)
        else { return [] }
        return CaptureFilePolicy.sanitized(items, capturesFolder: capturesFolder)
    }

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.itemsKey)
        }
    }

    // MARK: - Helpers

    nonisolated private static func writePNG(_ image: CGImage, to url: URL, folder: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return false
        }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: Date())
    }
}
