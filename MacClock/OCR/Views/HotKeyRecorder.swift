//
//  HotKeyRecorder.swift
//  MacClock
//
//  快捷鍵錄製按鈕
//

import AppKit
import SwiftUI

// MARK: - Hot Key Recorder

/// 點擊後按下新的組合鍵即可錄製；Esc 取消
struct HotKeyRecorder: View {
    let hotKey: OCRHotKey
    let onChange: (OCRHotKey) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var hint: String?

    private static let escapeKeyCode: UInt16 = 0x35

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(isRecording ? "請按下組合鍵…" : hotKey.displayString)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? ThemeColors.primary : nil)

            if let hint {
                Text(hint)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.orange)
            }
        }
        .onDisappear { stopRecording() }
        // 設定視窗直接關閉時 onDisappear 不一定會觸發，確保移除 monitor 並恢復快捷鍵
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            stopRecording()
        }
    }

    private func startRecording() {
        guard monitor == nil else { return }
        hint = nil
        isRecording = true
        OCRCoordinator.shared.suspendHotKey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil  // 吞掉按鍵，避免觸發其他動作
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        let wasRecording = isRecording
        monitor = nil
        isRecording = false
        if wasRecording {
            OCRCoordinator.shared.resumeHotKey()
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            stopRecording()
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyName = OCRHotKey.specialKeyName(for: event.keyCode)
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? ""
        let candidate = OCRHotKey(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: OCRHotKey.carbonModifiers(
                command: flags.contains(.command),
                shift: flags.contains(.shift),
                option: flags.contains(.option),
                control: flags.contains(.control)
            ),
            keyDisplay: keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard candidate.isValid else {
            hint = "需包含 ⌘、⌃ 或 ⌥"
            return
        }
        hint = nil
        // 先更新設定再恢復註冊，才會註冊到新的組合鍵
        onChange(candidate)
        stopRecording()
    }
}
