//
//  CountdownSettingsComponents.swift
//  MacClock
//
//  計時器設定分頁的子元件與時間解析
//

import SwiftUI

// MARK: - Time Input Parsing

/// 時間輸入的解析與格式化（純函式，方便測試）
enum CountdownTimeInput {
    /// 單一欄位上限，避免整數溢位
    private static let maxPart = 99_999

    /// 解析 "分"、"分:秒"、"時:分:秒"；任何欄位不是非負整數時回傳 0
    static func parse(_ input: String) -> TimeInterval {
        let tokens = input
            .trimmingCharacters(in: .whitespaces)
            .split(separator: ":", omittingEmptySubsequences: false)
        let parts = tokens.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == tokens.count,
              parts.allSatisfy({ $0 >= 0 && $0 <= maxPart }) else { return 0 }

        switch parts.count {
        case 1: return TimeInterval(parts[0] * 60)
        case 2: return TimeInterval(parts[0] * 60 + parts[1])
        case 3: return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        default: return 0
        }
    }

    /// 轉為輸入框格式：m:ss 或 h:mm:ss
    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// 列表顯示格式：mm:ss 或 h:mm:ss
    static func formatDisplay(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Quick Add Chips

struct CountdownQuickChips: View {
    let selectedSeconds: TimeInterval
    let onSelect: (TimeInterval) -> Void

    private static let presets: [(label: String, seconds: Int)] = [
        ("1 分", 60), ("3 分", 180), ("5 分", 300), ("10 分", 600),
        ("15 分", 900), ("25 分", 1500), ("30 分", 1800), ("1 小時", 3600)
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Self.presets, id: \.seconds) { preset in
                    let isSelected = selectedSeconds == TimeInterval(preset.seconds)
                    Button {
                        onSelect(TimeInterval(preset.seconds))
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("快速設定 \(preset.label)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Color Picker

struct CountdownColorPicker: View {
    @Binding var selectedHex: UInt

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(CountdownColors.all.enumerated()), id: \.element) { index, hex in
                let isSelected = selectedHex == hex
                Button {
                    selectedHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 2 : 0))
                        .shadow(color: isSelected ? Color(hex: hex).opacity(0.5) : .clear, radius: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("顏色 \(index + 1)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Timer Row

struct CountdownTimerRow: View {
    let timer: CountdownTimer
    let isEditing: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var displayLabel: String { timer.label.isEmpty ? "計時器" : timer.label }
    private var hasCommand: Bool { !(timer.completionCommand ?? "").isEmpty }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(Color(hex: timer.colorHex))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Text(displayLabel)
                .font(.system(size: 12, design: .rounded))
                .lineLimit(1)

            if hasCommand {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .help("完成時會執行指令")
                    .accessibilityLabel("完成時會執行指令")
            }

            Spacer()

            Text(CountdownTimeInput.formatDisplay(timer.duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            if timer.timerState == .running {
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(ThemeColors.primary)
                    .accessibilityLabel("執行中")
            } else if timer.timerState == .paused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .accessibilityLabel("已暫停")
            }

            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("編輯 \(displayLabel)")

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("刪除 \(displayLabel)")
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.sm)
        .background(isEditing ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
