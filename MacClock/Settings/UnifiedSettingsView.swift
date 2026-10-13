//
//  UnifiedSettingsView.swift
//  MacClock
//

import SwiftUI

/// Unified settings view with tabs for all settings
struct UnifiedSettingsView: View {
    @State var selectedTab: SettingsTab
    let onClose: () -> Void

    init(initialTab: SettingsTab = .general, onClose: @escaping () -> Void) {
        _selectedTab = State(initialValue: initialTab)
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selectedTab: $selectedTab)
            Divider()

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab(onClose: onClose)
                case .clock:
                    ClockSettingsTab(onClose: onClose)
                case .pomodoro:
                    PomodoroSettingsTab(onClose: onClose)
                case .countdown:
                    CountdownSettingsTab(onClose: onClose)
                case .schedule:
                    ScheduleSettingsTab(onClose: onClose)
                case .ocr:
                    OCRSettingsTab(onClose: onClose)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 520, minHeight: 400)
    }
}

/// 系統設定風格的分頁列：圖示在上、文字在下
private struct SettingsTabBar: View {
    @Binding var selectedTab: SettingsTab

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? ThemeColors.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? ThemeColors.primary.opacity(0.12) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
