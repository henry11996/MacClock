//
//  GeneralSettingsTab.swift
//  MacClock
//

import OSLog
import ServiceManagement
import SwiftUI

struct GeneralSettingsTab: View {
    let onClose: () -> Void
    var timer = PomodoroTimer.shared

    @State private var liquidGlassEnabled: Bool
    @State private var backgroundUpdateFPS: BackgroundUpdateFPS
    @State private var launchAtLogin: Bool
    @State private var launchAtLoginError: String?
    @State private var notchModeEnabled: Bool

    private static let logger = Logger(subsystem: "com.henry.MacClock", category: "Settings")
    private let hasNotch = NotchGeometry.hasNotch

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let settings = PomodoroTimer.shared.settings
        _liquidGlassEnabled = State(initialValue: settings.liquidGlassEnabled)
        _backgroundUpdateFPS = State(initialValue: settings.backgroundUpdateFPS)
        _launchAtLogin = State(initialValue: Self.isLaunchAtLoginRegistered)
        _notchModeEnabled = State(initialValue: settings.notchModeEnabled)
    }

    var body: some View {
        SettingsTabScaffold(onClose: onClose) {
            SettingsHeader(
                title: "MacClock",
                subtitle: "浮動時鐘、番茄鐘、計時器與螢幕文字辨識。",
                icon: "clock.fill"
            )

            systemCard

            if hasNotch {
                displayModeCard
            }

            if !notchModeEnabled {
                visualEffectsCard
            }
        }
        .onAppear { updateApprovalHint() }
        .onChange(of: liquidGlassEnabled) { saveSettings() }
        .onChange(of: backgroundUpdateFPS) { saveSettings() }
        .onChange(of: notchModeEnabled) { _, newValue in
            if newValue {
                liquidGlassEnabled = false
            }
            saveSettings()
            NotificationCenter.default.post(name: .notchModeChanged, object: newValue)
        }
    }

    // MARK: - Cards

    private var systemCard: some View {
        SettingsCard(title: "系統", icon: "gearshape") {
            SettingToggleRow(
                title: "開機時啟動",
                subtitle: "登入時自動啟動 MacClock",
                icon: "power",
                isOn: $launchAtLogin
            )
            .onChange(of: launchAtLogin) { _, newValue in
                setLaunchAtLogin(newValue)
            }

            if let launchAtLoginError {
                HStack {
                    Label(launchAtLoginError, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.orange)
                    Spacer()
                    Button("打開登入項目") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    /// 瀏海模式：以兩個可點選的卡片切換，比單一開關更直觀
    private var displayModeCard: some View {
        SettingsCard(title: "顯示模式", icon: "macwindow") {
            HStack(spacing: Spacing.sm) {
                displayModeOption(
                    title: "浮動視窗",
                    subtitle: "可拖曳到任意位置",
                    icon: "macwindow.on.rectangle",
                    isSelected: !notchModeEnabled
                ) { notchModeEnabled = false }
                displayModeOption(
                    title: "瀏海模式",
                    subtitle: "顯示在瀏海兩側",
                    icon: "menubar.rectangle",
                    isSelected: notchModeEnabled
                ) { notchModeEnabled = true }
            }
            SettingsFootnote(text: "瀏海模式下會關閉 Liquid Glass 效果。")
        }
    }

    private func displayModeOption(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? ThemeColors.primary : Color.secondary)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
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
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var visualEffectsCard: some View {
        SettingsCard(title: "視覺效果", icon: "sparkles") {
            SettingToggleRow(
                title: "Liquid Glass 效果",
                subtitle: "玻璃質感背景，會反映後方畫面",
                icon: "drop.fill",
                isOn: $liquidGlassEnabled
            )

            if liquidGlassEnabled {
                SettingRow(
                    title: "背景更新頻率",
                    subtitle: "FPS 越高越即時，但較耗電",
                    icon: "arrow.triangle.2.circlepath"
                ) {
                    Picker("背景更新頻率", selection: $backgroundUpdateFPS) {
                        ForEach(BackgroundUpdateFPS.allCases, id: \.self) { fps in
                            Text(fps.displayName).tag(fps)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    // MARK: - Helpers

    private func saveSettings() {
        var settings = timer.settings
        settings.liquidGlassEnabled = liquidGlassEnabled
        settings.backgroundUpdateFPS = backgroundUpdateFPS
        settings.notchModeEnabled = notchModeEnabled
        timer.settings = settings

        NotificationCenter.default.post(name: .backgroundRefreshSettingsChanged, object: nil)
    }

    /// 已註冊（含等待使用者在系統設定核准）都視為開啟
    private static var isLaunchAtLoginRegistered: Bool {
        [.enabled, .requiresApproval].contains(SMAppService.mainApp.status)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        // 狀態已一致時不重複呼叫（例如失敗後回復開關值觸發的 onChange）
        guard enabled != Self.isLaunchAtLoginRegistered else {
            updateApprovalHint()
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            updateApprovalHint()
        } catch {
            Self.logger.error("Launch at login update failed: \(error.localizedDescription, privacy: .public)")
            launchAtLoginError = "無法變更開機啟動設定，請到「系統設定 → 一般 → 登入項目」確認"
            launchAtLogin = Self.isLaunchAtLoginRegistered
        }
    }

    private func updateApprovalHint() {
        launchAtLoginError = SMAppService.mainApp.status == .requiresApproval
            ? "需要在「系統設定 → 一般 → 登入項目」允許 MacClock"
            : nil
    }
}
