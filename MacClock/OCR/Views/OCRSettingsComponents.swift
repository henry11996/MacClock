//
//  OCRSettingsComponents.swift
//  MacClock
//
//  文字辨識設定頁使用的小元件
//

import SwiftUI

/// 語言選擇：可多選的膠囊按鈕
struct OCRLanguageChips: View {
    let selected: [OCRLanguage]
    let onToggle: (OCRLanguage) -> Void

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: Spacing.sm)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
            ForEach(OCRLanguage.allCases, id: \.self) { language in
                chip(language)
            }
        }
    }

    private func chip(_ language: OCRLanguage) -> some View {
        let isOn = selected.contains(language)
        return Button {
            onToggle(language)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                Text(language.displayName)
                    .font(.system(size: 12, weight: isOn ? .semibold : .regular, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isOn ? ThemeColors.primary : Color.primary)
            .background(
                Capsule().fill(isOn ? ThemeColors.primary.opacity(0.15) : Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule().strokeBorder(isOn ? ThemeColors.primary.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.displayName)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// 遮罩深淺預覽：外圍套用遮罩、中間為選取區
struct OCRDimPreview: View {
    let opacity: Double

    private static let selectionSize = CGSize(width: 120, height: 28)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ThemeColors.primary.opacity(0.6), Color.orange.opacity(0.6)],
                startPoint: .leading, endPoint: .trailing
            )
            Color.black.opacity(opacity)
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: 2)
                                .frame(width: Self.selectionSize.width, height: Self.selectionSize.height)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white, lineWidth: 1)
                .frame(width: Self.selectionSize.width, height: Self.selectionSize.height)
            Text("範例文字")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}
