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

    /// 從瀏海內滑出的版面
    /// - panelFrame: 左緣延伸到瀏海內側（實體瀏海為黑色，畫在其中不可見），右緣到提示展開後的位置
    /// - restX: 提示展開後在 panel 內的 x（即瀏海右緣往內 notchOverlap）
    /// - hiddenOffset: 收合時的水平位移，讓提示的右緣剛好藏在瀏海右緣內
    struct NotchSlideLayout: Equatable {
        let panelFrame: CGRect
        let toastWidth: CGFloat
        let restX: CGFloat
        var hiddenOffset: CGFloat { -toastWidth }
    }

    static func notchSlideLayout(notchRect: CGRect, screenFrame: CGRect, contentWidth: CGFloat) -> NotchSlideLayout {
        let visible = notchRightFrame(notchRect: notchRect, screenFrame: screenFrame, contentWidth: contentWidth)
        let panelFrame = CGRect(
            x: notchRect.minX,
            y: notchRect.minY,
            width: visible.maxX - notchRect.minX,
            height: notchRect.height
        )
        return NotchSlideLayout(
            panelFrame: panelFrame,
            toastWidth: visible.width,
            restX: visible.minX - notchRect.minX
        )
    }

    /// 從瀏海往下彈出的版面：與瀏海同寬置中，收合時高度等於瀏海（完全藏在瀏海後方）
    struct NotchDropLayout: Equatable {
        let panelFrame: CGRect
        let collapsedHeight: CGFloat
        var contentHeight: CGFloat { panelFrame.height - collapsedHeight }
    }

    /// 往下彈出時左右各比瀏海寬出的距離（0 = 與瀏海同寬，避免蓋到兩側的瀏海面板）
    static let dropExtraWidth: CGFloat = 0
    /// 往下彈出時內容列的高度
    static let dropContentHeight: CGFloat = 40

    static func notchDropLayout(notchRect: CGRect) -> NotchDropLayout {
        let width = notchRect.width + dropExtraWidth * 2
        let height = notchRect.height + dropContentHeight
        return NotchDropLayout(
            panelFrame: CGRect(
                x: notchRect.midX - width / 2,
                y: notchRect.maxY - height,
                width: width,
                height: height
            ),
            collapsedHeight: notchRect.height
        )
    }

    /// 顯示在可視區上方中央
    static func topCenterOrigin(size: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - size.height - topCenterInset
        )
    }
}
