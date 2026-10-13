//
//  ClockSettingsTab.swift
//  MacClock
//

import AppKit
import SwiftUI

struct ClockSettingsTab: View {
    let onClose: () -> Void
    var timer = PomodoroTimer.shared

    @State private var clockStyle: ClockStyle
    @State private var clockFontScale: CGFloat

    private static let dateTimeSettingsURL = "x-apple.systempreferences:com.apple.Date-Time-Settings.extension"
    private let styleColumns = [GridItem(.adaptive(minimum: 140), spacing: Spacing.sm)]

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let settings = PomodoroTimer.shared.settings
        _clockStyle = State(initialValue: settings.clockStyle)
        _clockFontScale = State(initialValue: settings.clockFontScale)
    }

    var body: some View {
        SettingsTabScaffold(onClose: onClose) {
            SettingsCard(title: "時鐘樣式", icon: "clock") {
                LazyVGrid(columns: styleColumns, alignment: .leading, spacing: Spacing.sm) {
                    ForEach(ClockStyle.allCases, id: \.self) { style in
                        styleOption(style)
                    }
                }
            }

            SettingsCard(title: "大小", icon: "textformat.size") {
                FontScaleRow(title: "時鐘字體", icon: "clock", value: $clockFontScale)
            }

            SettingsCard(title: "系統", icon: "gearshape") {
                SettingRow(
                    title: "日期與時間",
                    subtitle: "時區、24 小時制等請在系統設定中調整",
                    icon: "clock.badge.gearshape"
                ) {
                    Button {
                        if let url = URL(string: Self.dateTimeSettingsURL) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("打開", systemImage: "arrow.up.forward.square")
                    }
                    .controlSize(.small)
                }
            }
        }
        .onChange(of: clockStyle) { saveSettings() }
        .onChange(of: clockFontScale) { saveSettings() }
    }

    /// 以實際顯示的範例文字作為選項，所見即所得
    private func styleOption(_ style: ClockStyle) -> some View {
        let isSelected = clockStyle == style
        return Button {
            clockStyle = style
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(style.displayName)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? ThemeColors.primary : Color.secondary)
                }
                Text(style.description)
                    .font(.system(size: 15, weight: .medium, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? ThemeColors.primary.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? ThemeColors.primary.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(style.displayName)，\(style.description)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func saveSettings() {
        var settings = timer.settings
        settings.clockStyle = clockStyle
        settings.clockFontScale = clockFontScale
        timer.settings = settings

        NotificationCenter.default.post(name: .fontScaleChanged, object: nil)
    }
}
