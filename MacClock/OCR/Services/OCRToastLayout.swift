//
//  OCRToastLayout.swift
//  MacClock
//
//  辨識結果提示的位置計算（AppKit 全域座標）
//

import CoreGraphics

nonisolated enum OCRToastLayout {
    /// 與瀏海面板一致：往瀏海內側重疊一點，避免出現縫隙
    static let notchOverlap: CGFloat = 8
    /// 與螢幕邊緣保留的距離
    static let screenMargin: CGFloat = 8
    /// 畫面上方模式與可視區頂端的距離
    static let topCenterInset: CGFloat = 24

    /// 貼齊瀏海右側、與選單列同高；寬度超出螢幕時縮短
    static func notchRightFrame(notchRect: CGRect, screenFrame: CGRect, contentWidth: CGFloat) -> CGRect {
        let x = notchRect.maxX - notchOverlap
        let available = max(0, screenFrame.maxX - screenMargin - x)
        return CGRect(
            x: x,
            y: notchRect.minY,
            width: min(contentWidth, available),
            height: notchRect.height
        )
    }

    /// 由瀏海右側的基本位置往下延伸 extraHeight（頂端維持貼齊螢幕上緣）
    static func expandedNotchFrame(_ base: CGRect, extraHeight: CGFloat) -> CGRect {
        CGRect(x: base.minX, y: base.minY - extraHeight, width: base.width, height: base.height + extraHeight)
    }

    /// 顯示在可視區上方中央
    static func topCenterOrigin(size: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - size.height - topCenterInset
        )
    }
}
