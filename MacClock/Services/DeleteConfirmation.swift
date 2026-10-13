//
//  DeleteConfirmation.swift
//  MacClock
//
//  刪除前的確認對話框（設定視窗與浮動小工具共用）
//  使用 NSAlert 而非 SwiftUI 對話框：小工具是 nonactivating panel，SwiftUI 對話框無法可靠顯示
//

import AppKit

enum DeleteConfirmation {
    enum Kind {
        case timer
        case schedule

        var noun: String {
            switch self {
            case .timer: return "計時器"
            case .schedule: return "排程"
            }
        }
    }

    /// 名稱過長時截斷，避免對話框被撐開
    static let maxNameLength = 40

    static func title(for kind: Kind, name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "要刪除這個\(kind.noun)嗎？" }
        let shown = trimmed.count > maxNameLength ? String(trimmed.prefix(maxNameLength)) + "…" : trimmed
        return "要刪除\(kind.noun)「\(shown)」嗎？"
    }

    static let message = "此動作無法復原。"

    /// 顯示確認對話框；使用者按「刪除」才回傳 true
    @MainActor
    static func confirm(_ kind: Kind, name: String) -> Bool {
        // 從浮動小工具觸發時 App 可能不在前景，先啟用才能讓對話框取得焦點
        NSApp.activate()

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title(for: kind, name: name)
        alert.informativeText = message

        let deleteButton = alert.addButton(withTitle: "刪除")
        deleteButton.hasDestructiveAction = true
        // Return 不觸發刪除，避免誤按
        deleteButton.keyEquivalent = ""

        let cancelButton = alert.addButton(withTitle: "取消")
        cancelButton.keyEquivalent = "\u{1b}"

        return alert.runModal() == .alertFirstButtonReturn
    }
}
