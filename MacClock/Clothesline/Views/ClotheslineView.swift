//
//  ClotheslineView.swift
//  MacClock
//
//  繩子與掛在上面的截圖
//

import AppKit
import ImageIO
import SwiftUI

/// 面板的展開狀態（由 controller 以動畫切換）
@MainActor
@Observable
final class ClotheslinePresentation {
    var isRevealed = false
}

struct ClotheslineView: View {
    let store: ClotheslineStore
    let presentation: ClotheslinePresentation

    private static let ropeY: CGFloat = 12

    var body: some View {
        let revealed = presentation.isRevealed
        ZStack(alignment: .top) {
            RopeShape(sag: 10)
                .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                .frame(height: 30)
                .offset(y: Self.ropeY - 6)

            if store.items.isEmpty {
                emptyHint
            } else {
                HStack(alignment: .top, spacing: ClotheslineLayout.itemSpacing) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        PeggedPhotoView(item: item, store: store, tilt: Self.tilt(for: index))
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.6).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.top, Self.ropeY)
                .padding(.horizontal, ClotheslineLayout.horizontalMargin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 從選單列（瀏海）往下降：收合時整條繩子藏在面板上緣之外
        .offset(y: revealed ? 0 : -ClotheslineLayout.panelHeight)
        .opacity(revealed ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: store.items.map(\.id))
    }

    private var emptyHint: some View {
        Label("截圖後會掛在這裡", systemImage: "photo.on.rectangle.angled")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.75), in: Capsule())
            .padding(.top, Self.ropeY + 14)
    }

    /// 每張照片微微歪一點，看起來像真的晾在繩子上
    static func tilt(for index: Int) -> Double {
        let pattern: [Double] = [-2.2, 1.6, -0.8, 2.4, -1.5, 0.9]
        return pattern[index % pattern.count]
    }
}

/// 略微下垂的繩子
private struct RopeShape: Shape {
    let sag: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + sag * 2)
        )
        return path
    }
}

/// 一張用夾子夾在繩子上的截圖
private struct PeggedPhotoView: View {
    let item: ClotheslineItem
    let store: ClotheslineStore
    let tilt: Double

    @State private var thumbnail: CGImage?
    @State private var isHovering = false
    @State private var justCopied = false

    private static let maxSize = CGSize(width: ClotheslineLayout.itemMaxWidth, height: 92)

    var body: some View {
        VStack(spacing: -4) {
            clothespin
                .zIndex(1)
            photo
        }
        .rotationEffect(.degrees(isHovering ? 0 : tilt), anchor: .top)
        .scaleEffect(isHovering ? 1.06 : 1, anchor: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { isHovering = $0 }
        .task(id: item.fileURL) {
            thumbnail = await ThumbnailLoader.thumbnail(for: item.fileURL, maxPixelSize: 300, retries: 3)
        }
        .contextMenu { contextMenu }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.source == .ocr ? "文字辨識畫面" : "截圖 \(item.fileURL.lastPathComponent)")
        .accessibilityHint("點一下複製，點兩下用預覽程式開啟")
        .accessibilityAddTraits(.isButton)
    }

    private var clothespin: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.75)], startPoint: .top, endPoint: .bottom))
            .frame(width: 8, height: 18)
            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
    }

    private var photo: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let thumbnail {
                    Image(decorative: thumbnail, scale: 2)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.white.opacity(0.15)
                        .frame(width: Self.maxSize.width * 0.8, height: Self.maxSize.height * 0.7)
                }
            }
            .frame(maxWidth: Self.maxSize.width, maxHeight: Self.maxSize.height)
            .padding(3)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .overlay {
                if justCopied {
                    Label("已複製", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.75), in: Capsule())
                        .transition(.opacity)
                }
            }
            .onTapGesture(count: 2) { store.open(item) }
            .onTapGesture { copy() }
            .onDrag { NSItemProvider(contentsOf: item.fileURL) ?? NSItemProvider() }

            if isHovering {
                Button {
                    store.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .offset(x: 7, y: -7)
                .accessibilityLabel("從繩子拿下")
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("複製") { copy() }
        Button("用預覽程式打開") { store.open(item) }
        Button("在 Finder 中顯示") { store.revealInFinder(item) }
        Divider()
        Button("從繩子拿下") { store.remove(item) }
    }

    private func copy() {
        Task {
            guard await store.copy(item) else { return }
            withAnimation { justCopied = true }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation { justCopied = false }
        }
    }
}

/// 縮圖在背景產生並快取，避免繩子展開時卡頓
enum ThumbnailLoader {
    private struct CacheKey: Hashable {
        let url: URL
        /// 同名檔案被覆寫時修改時間會變，避免顯示舊圖
        let modified: Date?
    }

    @MainActor private static var cache: [CacheKey: CGImage] = [:]
    private static let maxCacheCount = 60
    /// 檔案可能還在寫入，讀取失敗時稍等再試
    private static let retryDelay: Duration = .milliseconds(500)

    @MainActor
    static func thumbnail(for url: URL, maxPixelSize: Int, retries: Int = 0) async -> CGImage? {
        for attempt in 0...max(retries, 0) {
            if attempt > 0 {
                try? await Task.sleep(for: retryDelay)
                if Task.isCancelled { return nil }
            }
            let key = CacheKey(url: url, modified: modificationDate(of: url))
            if let cached = cache[key] { return cached }
            if let image = await Task.detached(priority: .utility, operation: {
                makeThumbnail(url: url, maxPixelSize: maxPixelSize)
            }).value {
                if cache.count >= maxCacheCount { cache.removeAll() }
                cache[key] = image
                return image
            }
        }
        return nil
    }

    @MainActor
    static func evict(_ url: URL) {
        cache = cache.filter { $0.key.url != url }
    }

    nonisolated private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    nonisolated private static func makeThumbnail(url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
