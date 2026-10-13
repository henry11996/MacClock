//
//  ClotheslineSettingsTab.swift
//  MacClock
//
//  截圖晾衣繩設定分頁
//

import AppKit
import SwiftUI

struct ClotheslineSettingsTab: View {
    let onClose: () -> Void
    var store = ClotheslineStore.shared

    private var settings: ClotheslineSettings { store.settings }
    private let hasNotch = NotchGeometry.hasNotch

    var body: some View {
        SettingsTabScaffold(onClose: onClose) {
            SettingsHeader(
                title: "截圖晾衣繩",
                subtitle: hasNotch
                    ? "新截圖會掛在瀏海下方的繩子上；滑鼠停在瀏海就會展開。"
                    : "新截圖會掛在選單列下方的繩子上；滑鼠停在選單列中央就會展開。",
                icon: "photo.on.rectangle.angled"
            ) {
                Toggle("啟用晾衣繩", isOn: enabledBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(settings.folderBookmark == nil)
            }

            folderCard
            lineCard
            usageCard
        }
    }

    // MARK: - Cards

    private var folderCard: some View {
        SettingsCard(title: "截圖資料夾", icon: "folder") {
            SettingRow(
                title: settings.folderPath.map { ($0 as NSString).abbreviatingWithTildeInPath } ?? "尚未選擇",
                subtitle: folderSubtitle,
                icon: "folder.badge.gearshape",
                iconColor: store.folderError == nil ? ThemeColors.primary : .orange
            ) {
                Button(settings.folderBookmark == nil ? "選擇資料夾…" : "更換…") {
                    store.chooseFolder()
                }
            }

            if let error = store.folderError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.orange)
            }

            SettingsFootnote(text: "預設帶入系統截圖位置（⌘⇧5 →「選項」）。選桌面時只會掛上系統截圖，不會掛其他圖片。MacClock 只讀取這個資料夾，不會修改或刪除你的檔案。")
        }
    }

    private var folderSubtitle: String {
        if settings.folderBookmark == nil {
            return "選擇後才能啟用"
        }
        return store.watchedFolder == nil ? "未在監看" : "監看中"
    }

    private var lineCard: some View {
        SettingsCard(title: "繩子", icon: "line.diagonal") {
            SettingRow(title: "最多掛幾張", subtitle: "超過時會拿下最舊的", icon: "square.stack.3d.down.right") {
                Stepper(value: binding(\.maxItems), in: ClotheslineSettings.maxItemsRange) {
                    Text("\(settings.maxItems) 張")
                        .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                        .frame(minWidth: 44, alignment: .trailing)
                }
                .accessibilityLabel("最多掛幾張")
                .accessibilityValue("\(settings.maxItems) 張")
            }

            SettingToggleRow(
                title: "掛上文字辨識的畫面",
                subtitle: "OCR 框選的畫面會存在本機（App 專屬資料夾），從繩子拿下時一併刪除",
                icon: "text.viewfinder",
                isOn: binding(\.hangOCRCaptures)
            )

            Divider()

            SettingRow(title: "目前掛著 \(store.items.count) 張", icon: "photo.stack") {
                Button("全部拿下", role: .destructive) {
                    store.clear()
                }
                .disabled(store.items.isEmpty)
            }
            SettingsFootnote(text: "從繩子拿下不會刪除你的截圖檔案。")
        }
    }

    private var usageCard: some View {
        SettingsCard(title: "操作方式", icon: "hand.tap") {
            usageRow("點一下", "複製圖片", icon: "doc.on.doc")
            usageRow("點兩下", "用預覽程式打開", icon: "eye")
            usageRow("拖曳", "放到其他 App 或資料夾", icon: "arrow.up.and.down.and.arrow.left.and.right")
            usageRow("滑過後按 ✕", "從繩子拿下", icon: "xmark.circle")
            usageRow("右鍵", "更多選項（在 Finder 中顯示）", icon: "contextualmenu.and.cursorarrow")
        }
    }

    private func usageRow(_ gesture: String, _ effect: String, icon: String) -> some View {
        SettingRow(title: gesture, icon: icon) {
            Text(effect)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Bindings

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { store.settings.isEnabled },
            set: { store.update(store.settings.with(\.isEnabled, $0)) }
        )
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ClotheslineSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { store.update(store.settings.with(keyPath, $0)) }
        )
    }
}
