//
//  GlobalHotKeyService.swift
//  MacClock
//
//  以 Carbon RegisterEventHotKey 註冊全域快捷鍵（可同時註冊多組）
//  （不需要「輔助使用」權限，且可在 App Sandbox 中運作）
//

import Carbon.HIToolbox
import OSLog

/// 每組快捷鍵的用途；rawValue 即 Carbon EventHotKeyID.id
enum HotKeySlot: UInt32, CaseIterable {
    case captureText = 1
    case translate = 2
}

@MainActor
final class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()

    private static let signature: OSType = 0x4D43_4F43  // 'MCOC'
    private static let logger = Logger(subsystem: "com.henry.MacClock", category: "HotKey")

    private struct Registration {
        let ref: EventHotKeyRef
        let action: () -> Void
    }

    private var registrations: [HotKeySlot: Registration] = [:]
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// 註冊（會先取消同一組的舊註冊）
    /// - Returns: 是否成功（失敗通常代表快捷鍵已被其他 App 或另一組設定佔用）
    @discardableResult
    func register(_ hotKey: OCRHotKey, for slot: HotKeySlot, action: @escaping () -> Void) -> Bool {
        unregister(slot)
        guard hotKey.isValid, installHandlerIfNeeded() else { return false }

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: slot.rawValue),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            Self.logger.error("RegisterEventHotKey failed for slot \(slot.rawValue): \(status)")
            return false
        }
        registrations[slot] = Registration(ref: ref, action: action)
        return true
    }

    func unregister(_ slot: HotKeySlot) {
        if let registration = registrations.removeValue(forKey: slot) {
            UnregisterEventHotKey(registration.ref)
        }
    }

    func unregisterAll() {
        HotKeySlot.allCases.forEach(unregister)
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
        guard status == noErr, pressedID.signature == Self.signature,
              let slot = HotKeySlot(rawValue: pressedID.id),
              let registration = registrations[slot]
        else {
            return OSStatus(eventNotHandledErr)
        }
        registration.action()
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
