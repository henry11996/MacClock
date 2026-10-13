//
//  SettingsComponents.swift
//  MacClock
//
//  所有設定分頁共用的版面元件，確保字級、間距、對齊一致
//

import SwiftUI

/// 卡片式設定區塊：上方小標題 + 圓角底色內容
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ThemeColors.primary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 2)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                content()
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// 統一的設定列：左側圖示 + 標題 + 說明，右側控制項
struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    let icon: String
    var iconColor: Color = ThemeColors.primary
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Spacing.sm)
            trailing()
        }
    }
}

/// 開關列：SettingRow + 右側 switch
struct SettingToggleRow: View {
    let title: String
    var subtitle: String?
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(title: title, subtitle: subtitle, icon: icon) {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

/// 卡片底部的說明小字
struct SettingsFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 字體大小滑桿列（時鐘、番茄鐘、計時器、排程共用）
struct FontScaleRow: View {
    let title: String
    let icon: String
    @Binding var value: CGFloat
    var range: ClosedRange<CGFloat> = 0.8...5.0

    private var percentText: String { "\(Int((value * 100).rounded()))%" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SettingRow(title: title, icon: icon) {
                Text(percentText)
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range, step: 0.1) {
                EmptyView()
            } minimumValueLabel: {
                Image(systemName: "textformat.size.smaller").font(.system(size: 10))
            } maximumValueLabel: {
                Image(systemName: "textformat.size.larger").font(.system(size: 12))
            }
            .controlSize(.small)
            .accessibilityLabel("\(title)字體大小")
            .accessibilityValue(percentText)
        }
    }
}

/// 分頁的共用骨架：可捲動內容 + 底部關閉列（左側可放額外動作）
struct SettingsTabScaffold<Content: View, Leading: View>: View {
    let onClose: () -> Void
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let content: () -> Content

    init(
        onClose: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onClose = onClose
        self.leading = leading
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                content()
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    leading()
                    Spacer()
                    Button("關閉", action: onClose)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .background(.regularMaterial)
        }
    }
}

/// 分頁頂部的功能摘要
struct SettingsHeader<Accessory: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    var tint: Color = ThemeColors.primary
    @ViewBuilder let accessory: () -> Accessory

    init(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color = ThemeColors.primary,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.sm)
            accessory()
        }
        .padding(Spacing.md)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
