//
//  GlobalHotKeyService.swift
//  MacClock
//
//  以 Carbon RegisterEventHotKey 註冊全域快捷鍵
//  （不需要「輔助使用」權限，且可在 App Sandbox 中運作）
//

import Carbon.HIToolbox
import OSLog

@MainActor
final class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()

    private static let signature: OSType = 0x4D43_4F43  // 'MCOC'
    private static let hotKeyID: UInt32 = 1
    private static let logger = Logger(subsystem: "com.henry.MacClock", category: "HotKey")

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    private init() {}

    /// 註冊（會先取消舊的註冊）
    /// - Returns: 是否成功（失敗通常代表快捷鍵已被其他 App 佔用）
    @discardableResult
    func register(_ hotKey: OCRHotKey, action: @escaping () -> Void) -> Bool {
        unregister()
        guard hotKey.isValid, installHandlerIfNeeded() else { return false }

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: Self.hotKeyID),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            Self.logger.error("RegisterEventHotKey failed: \(status)")
            return false
        }
        hotKeyRef = ref
        self.action = action
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        action = nil
    }

    fileprivate func handle(_ event: EventRef?) -> OSStatus {
        guard let event else { return OSStatus(eventNotHandledErr) }
        var pressedID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressedID
        )
        guard status == noErr, pressedID.signature == Self.signature, pressedID.id == Self.hotKeyID else {
            return OSStatus(eventNotHandledErr)
        }
        action?()
        return noErr
    }

    private func installHandlerIfNeeded() -> Bool {
        guard handlerRef == nil else { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // 單例永不釋放，因此使用 unretained 指標是安全的
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1,
            &eventType,
            userData,
            &handlerRef
        )
        if status != noErr {
            Self.logger.error("InstallEventHandler failed: \(status)")
        }
        return status == noErr
    }
}

/// Carbon 事件於主執行緒派送
nonisolated private func hotKeyEventCallback(
    _ handler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    // 指標只在主執行緒同步使用，不會跨執行緒存取
    nonisolated(unsafe) let servicePointer = userData
    nonisolated(unsafe) let eventRef = event
    return MainActor.assumeIsolated {
        Unmanaged<GlobalHotKeyService>.fromOpaque(servicePointer).takeUnretainedValue().handle(eventRef)
    }
}
