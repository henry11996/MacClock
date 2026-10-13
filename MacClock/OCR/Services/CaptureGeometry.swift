//
//  CaptureGeometry.swift
//  MacClock
//
//  選取框與螢幕座標系之間的換算
//  - AppKit 全域座標：原點在主螢幕左下角，Y 軸向上
//  - CoreGraphics 全域座標（SCDisplay.frame）：原點在主螢幕左上角，Y 軸向下
//

import CoreGraphics

nonisolated enum CaptureGeometry {

    /// 選取框最小邊長（points），太小視為誤觸
    static let minimumSelectionSide: CGFloat = 4

    /// 由拖曳起點與終點建立正規化（寬高為正）的矩形
    static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    static func isValidSelection(_ rect: CGRect) -> Bool {
        !rect.isNull && rect.width >= minimumSelectionSide && rect.height >= minimumSelectionSide
    }

    /// AppKit 全域座標 → CoreGraphics 全域座標
    static func toCoreGraphicsGlobal(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// 將 CoreGraphics 全域矩形裁切到指定螢幕內，並轉換成該螢幕的區域座標
    /// - Returns: 不與螢幕相交時回傳 nil
    static func displayLocalRect(_ globalRect: CGRect, displayFrame: CGRect) -> CGRect? {
        let clipped = globalRect.intersection(displayFrame)
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
        return clipped.offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY)
    }

    /// 擷取影像長邊上限（px）：限制記憶體用量，Vision 對更大的圖也不會更準
    static let maxPixelDimension: CGFloat = 8192

    /// 選取框（points）在指定縮放倍率下的像素尺寸，至少 1px，長邊不超過上限（等比縮小）
    static func pixelSize(of rect: CGRect, scale: CGFloat) -> (width: Int, height: Int) {
        let safeScale = max(scale, 1)
        let width = rect.width * safeScale
        let height = rect.height * safeScale
        let longest = max(width, height)
        let shrink = longest > maxPixelDimension ? maxPixelDimension / longest : 1
        return (
            width: max(1, Int((width * shrink).rounded())),
            height: max(1, Int((height * shrink).rounded()))
        )
    }

    /// 找出與矩形相交面積最大的螢幕
    static func bestMatchingFrame(for rect: CGRect, in frames: [CGRect]) -> Int? {
        frames.indices
            .map { index -> (Int, CGFloat) in
                let overlap = rect.intersection(frames[index])
                return (index, overlap.isNull ? 0 : overlap.width * overlap.height)
            }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?
            .0
    }
}
