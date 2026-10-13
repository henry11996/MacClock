//
//  ScreenshotFolderAccess.swift
//  MacClock
//
//  截圖資料夾的存取：讀取系統截圖位置、讓使用者選擇資料夾、保存 security-scoped bookmark
//

import AppKit

enum ScreenshotFolderAccessError: LocalizedError {
    case bookmarkFailed

    var errorDescription: String? {
        switch self {
        case .bookmarkFailed: return "無法記住這個資料夾，請重新選擇"
        }
    }
}

nonisolated enum ScreenshotFolderAccess {
    private static let screencaptureDomainName = "com.apple.screencapture"
    private static var screencaptureDomain: CFString { screencaptureDomainName as CFString }

    /// 使用者真正的家目錄（沙盒內 NSHomeDirectory 會指向 App 容器）
    static var realHomeDirectory: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// 系統截圖存放位置（⌘⇧5 → 選項 中的設定）；讀不到時預設為桌面
    static func systemScreenshotFolder() -> URL {
        CFPreferencesAppSynchronize(screencaptureDomain)
        // 新版 macOS 使用 "location-screenshot"，舊版使用 "location"
        let raw = (CFPreferencesCopyAppValue("location-screenshot" as CFString, screencaptureDomain) as? String)
            ?? (CFPreferencesCopyAppValue("location" as CFString, screencaptureDomain) as? String)
        let home = realHomeDirectory
        if let raw, !raw.isEmpty {
            return ScreenshotFileFilter.expandTilde(raw, realHome: home)
        }
        return home.appendingPathComponent("Desktop", isDirectory: true)
    }

    /// 開啟資料夾選擇視窗，預設定位在系統截圖位置
    @MainActor
    static func chooseFolder() -> URL? {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.title = "選擇截圖資料夾"
        panel.message = "MacClock 會把這個資料夾中新增的截圖掛到晾衣繩上（唯讀，不會修改或刪除你的檔案）"
        panel.prompt = "選擇"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = systemScreenshotFolder()
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func makeBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw ScreenshotFolderAccessError.bookmarkFailed
        }
    }

    /// 解析 bookmark；回傳資料夾與是否需要重新建立 bookmark
    static func resolve(_ bookmark: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return (url, isStale)
    }
}
