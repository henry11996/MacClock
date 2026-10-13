//
//  ScreenshotWatcher.swift
//  MacClock
//
//  監看截圖資料夾，回報新出現的截圖
//  MacClock 不自己截圖：使用者照常用 ⌘⇧3/4/5 或其他截圖工具，這裡只負責撿起新檔案
//  做法參考 Tendedero（https://github.com/alejandrobujan/tendedero，MIT License）
//

import Foundation
import OSLog

@MainActor
final class ScreenshotWatcher {
    /// 資料夾變動後等待一下再掃描，合併連續的寫入事件
    private static let debounceInterval: TimeInterval = 0.3
    private static let logger = Logger(subsystem: "com.henry.MacClock", category: "Clothesline")

    let folder: URL
    private let requiresScreenshotTag: Bool
    private let onNew: (URL) -> Void
    private let startedAt = Date()

    private var source: DispatchSourceFileSystemObject?
    private var pendingScan: DispatchWorkItem?
    private var known: Set<String> = []
    private var isScanning = false
    private var rescanNeeded = false
    private var isStopped = false

    init(folder: URL, requiresScreenshotTag: Bool, onNew: @escaping (URL) -> Void) {
        self.folder = folder
        self.requiresScreenshotTag = requiresScreenshotTag
        self.onNew = onNew
    }

    /// 開啟資料夾可能會等待系統權限詢問，所以在背景執行緒進行
    func start() {
        isStopped = false
        guard source == nil else { return }
        let path = folder.path
        Task.detached(priority: .utility) { [weak self] in
            let fd = open(path, O_EVTONLY)
            await self?.watch(fileDescriptor: fd)
        }
    }

    func stop() {
        isStopped = true
        pendingScan?.cancel()
        pendingScan = nil
        source?.cancel()
        source = nil
    }

    private func watch(fileDescriptor fd: Int32) {
        guard fd >= 0 else {
            Self.logger.error("Cannot open screenshot folder (errno \(errno))")
            return
        }
        guard !isStopped, source == nil else {
            close(fd)
            return
        }
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .extend],
            queue: .main
        )
        newSource.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleScan() }
        }
        newSource.setCancelHandler { close(fd) }
        newSource.resume()
        source = newSource
        scheduleScan()
    }

    private func scheduleScan() {
        pendingScan?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.scan() }
        }
        pendingScan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceInterval, execute: work)
    }

    /// 掃描在背景進行；掃描期間又有變動時，結束後再掃一次
    private func scan() {
        guard !isStopped else { return }
        guard !isScanning else {
            rescanNeeded = true
            return
        }
        isScanning = true
        let folder = folder
        let startedAt = startedAt
        let requiresTag = requiresScreenshotTag
        let known = known
        Task.detached(priority: .utility) { [weak self] in
            let found = Self.findNewScreenshots(
                in: folder,
                startedAt: startedAt,
                requiresTag: requiresTag,
                excluding: known
            )
            await self?.finishScan(found)
        }
    }

    private func finishScan(_ found: [URL]) {
        isScanning = false
        guard !isStopped else { return }
        for url in found {
            known.insert(url.lastPathComponent)
            onNew(url)
        }
        if rescanNeeded {
            rescanNeeded = false
            scheduleScan()
        }
    }

    /// 依建立時間排序（舊到新），讓最新的最後掛上、出現在最前面
    nonisolated private static func findNewScreenshots(
        in folder: URL,
        startedAt: Date,
        requiresTag: Bool,
        excluding known: Set<String>
    ) -> [URL] {
        let keys: [URLResourceKey] = [.creationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants]
        ) else { return [] }

        return urls
            .filter { !known.contains($0.lastPathComponent) }
            .compactMap { url -> (URL, Date)? in
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      ScreenshotFileFilter.isCandidate(
                        fileName: url.lastPathComponent,
                        createdAt: values.creationDate,
                        fileSize: values.fileSize,
                        startedAt: startedAt,
                        hasScreenshotTag: requiresTag ? hasScreenshotTag(url) : false,
                        requiresScreenshotTag: requiresTag
                      ),
                      let created = values.creationDate
                else { return nil }
                return (url, created)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    nonisolated private static func hasScreenshotTag(_ url: URL) -> Bool {
        getxattr(url.path, ScreenshotFileFilter.screenshotAttribute, nil, 0, 0, 0) >= 0
    }
}
