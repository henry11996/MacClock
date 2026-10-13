//
//  ScreenCaptureService.swift
//  MacClock
//
//  使用 ScreenCaptureKit 擷取指定螢幕區域（排除 MacClock 自己的視窗）
//

import AppKit
import ScreenCaptureKit

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case displayNotFound
    case invalidSelection

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "需要「螢幕錄製」權限"
        case .displayNotFound: return "找不到選取區域所在的螢幕"
        case .invalidSelection: return "選取範圍無效"
        }
    }
}

@MainActor
enum ScreenCaptureService {

    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// 觸發系統權限詢問（第一次會跳出系統對話框）
    @discardableResult
    static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        else { return }
        NSWorkspace.shared.open(url)
    }

    /// 擷取 AppKit 全域座標中的矩形區域
    static func capture(appKitRect: CGRect) async throws -> CGImage {
        guard hasPermission else { throw ScreenCaptureError.permissionDenied }
        guard let primaryHeight = NSScreen.screens.first?.frame.height else {
            throw ScreenCaptureError.displayNotFound
        }

        let globalRect = CaptureGeometry.toCoreGraphicsGlobal(appKitRect, primaryScreenHeight: primaryHeight)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let displayIndex = CaptureGeometry.bestMatchingFrame(
            for: globalRect,
            in: content.displays.map(\.frame)
        ) else {
            throw ScreenCaptureError.displayNotFound
        }
        let display = content.displays[displayIndex]

        guard let localRect = CaptureGeometry.displayLocalRect(globalRect, displayFrame: display.frame) else {
            throw ScreenCaptureError.invalidSelection
        }

        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        let configuration = SCStreamConfiguration()
        let pixels = CaptureGeometry.pixelSize(of: localRect, scale: CGFloat(filter.pointPixelScale))
        configuration.sourceRect = localRect
        configuration.width = pixels.width
        configuration.height = pixels.height
        configuration.showsCursor = false
        configuration.captureResolution = .best

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
}
