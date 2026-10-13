//
//  ClotheslineLayout.swift
//  MacClock
//
//  晾衣繩面板的位置與滑鼠觸發區（AppKit 全域座標）
//

import CoreGraphics

nonisolated enum ClotheslineLayout {
    /// 面板高度：繩子 + 夾子 + 縮圖
    static let panelHeight: CGFloat = 140
    /// 面板左右與螢幕邊緣的距離
    static let horizontalMargin: CGFloat = 24
    /// 每張縮圖的最大寬度與間距（用來估算需要的寬度）
    static let itemMaxWidth: CGFloat = 132
    static let itemSpacing: CGFloat = 14
    /// 沒有瀏海時，在選單列中央的觸發區寬度
    static let fallbackTriggerWidth: CGFloat = 240

    /// 面板貼在選單列下方，以瀏海（或螢幕中央）為中心；寬度依項目數量，不超過螢幕
    static func panelFrame(screenFrame: CGRect, menuBarHeight: CGFloat, centerX: CGFloat, itemCount: Int) -> CGRect {
        let needed = CGFloat(max(itemCount, 1)) * (itemMaxWidth + itemSpacing) + horizontalMargin * 2
        let maxWidth = screenFrame.width - horizontalMargin * 2
        let width = min(max(needed, 360), maxWidth)
        let minX = screenFrame.minX + horizontalMargin
        let maxX = screenFrame.maxX - horizontalMargin - width
        let x = min(max(centerX - width / 2, minX), maxX)
        return CGRect(
            x: x,
            y: screenFrame.maxY - menuBarHeight - panelHeight,
            width: width,
            height: panelHeight
        )
    }

    /// 觸發展開的區域：瀏海本身；沒有瀏海時為選單列中央一段
    static func triggerRect(screenFrame: CGRect, menuBarHeight: CGFloat, notchRect: CGRect?) -> CGRect {
        if let notchRect { return notchRect }
        return CGRect(
            x: screenFrame.midX - fallbackTriggerWidth / 2,
            y: screenFrame.maxY - menuBarHeight,
            width: fallbackTriggerWidth,
            height: menuBarHeight
        )
    }

    /// 展開中時，滑鼠在面板、觸發區或兩者之間的空隙都算「還在上面」
    static func keepsOpen(mouse: CGPoint, panelFrame: CGRect, triggerRect: CGRect) -> Bool {
        let bridge = CGRect(
            x: min(panelFrame.minX, triggerRect.minX),
            y: panelFrame.maxY,
            width: max(panelFrame.maxX, triggerRect.maxX) - min(panelFrame.minX, triggerRect.minX),
            height: max(0, triggerRect.minY - panelFrame.maxY)
        )
        return panelFrame.contains(mouse) || triggerRect.insetBy(dx: -4, dy: -4).contains(mouse) || bridge.contains(mouse)
    }
}
