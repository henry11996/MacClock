//
//  OCRTextFormatter.swift
//  MacClock
//
//  將 Vision 辨識出的文字片段依閱讀順序組合成純文字
//

import CoreGraphics
import Foundation

/// 一個辨識出的文字片段
/// - boundingBox: Vision 的正規化座標（0~1，原點在左下）
nonisolated struct RecognizedFragment: Equatable, Sendable {
    let text: String
    let boundingBox: CGRect
}

nonisolated enum OCRTextFormatter {

    /// 判定兩個片段屬於同一行的垂直重疊比例門檻（相對於較矮者的高度）
    static let sameLineOverlapRatio: CGFloat = 0.5

    /// 依閱讀順序（上到下、左到右）將片段組成文字
    /// - Parameter keepLineBreaks: true 保留原本換行；false 將所有行合併成一段
    static func format(_ fragments: [RecognizedFragment], keepLineBreaks: Bool) -> String {
        let lines = groupIntoLines(fragments)
            .map { joinFragments($0.map(\.text)) }
            .filter { !$0.isEmpty }

        guard keepLineBreaks else { return joinFragments(lines, mergingHyphens: true) }
        return lines.joined(separator: "\n")
    }

    /// 將片段分組成行：先依垂直中心由上而下排序，再把垂直重疊足夠的片段歸到同一行
    static func groupIntoLines(_ fragments: [RecognizedFragment]) -> [[RecognizedFragment]] {
        let sorted = fragments
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        var lines: [[RecognizedFragment]] = []
        var currentBand: CGRect = .null

        for fragment in sorted {
            if let last = lines.last, !last.isEmpty,
               overlapsVertically(currentBand, fragment.boundingBox) {
                lines[lines.count - 1] = last + [fragment]
                currentBand = currentBand.union(fragment.boundingBox)
            } else {
                lines.append([fragment])
                currentBand = fragment.boundingBox
            }
        }

        return lines.map { $0.sorted { $0.boundingBox.minX < $1.boundingBox.minX } }
    }

    /// 依兩端字元決定片段之間是否需要空白（CJK 之間不加空白）
    static func joinFragments(_ parts: [String], mergingHyphens: Bool = false) -> String {
        var result = ""
        for raw in parts {
            let part = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !part.isEmpty else { continue }
            guard let last = result.unicodeScalars.last, let first = part.unicodeScalars.first else {
                result = part
                continue
            }
            if mergingHyphens, last == "-", result.count > 1,
               let beforeHyphen = result.unicodeScalars.dropLast().last,
               CharacterSet.letters.contains(beforeHyphen),
               CharacterSet.lowercaseLetters.contains(first) {
                // 英文行尾斷字："exam-" + "ple" → "example"
                result.removeLast()
                result += part
            } else {
                result += separator(between: last, and: first) + part
            }
        }
        return result
    }

    static func separator(between left: Unicode.Scalar, and right: Unicode.Scalar) -> String {
        (isCJK(left) || isCJK(right)) ? "" : " "
    }

    /// 是否為中日韓文字或全形標點（這類文字之間不需要空白）
    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3000...0x303F,   // CJK 標點
             0x3040...0x30FF,   // 平假名、片假名
             0x3100...0x312F,   // 注音
             0x3400...0x4DBF,   // CJK 擴充 A
             0x4E00...0x9FFF,   // CJK 統一漢字
             0xAC00...0xD7AF,   // 韓文音節
             0xF900...0xFAFF,   // CJK 相容漢字
             0xFF00...0xFFEF,   // 全形字元
             0x20000...0x2FA1F: // CJK 擴充 B 之後
            return true
        default:
            return false
        }
    }

    private static func overlapsVertically(_ band: CGRect, _ box: CGRect) -> Bool {
        let overlap = min(band.maxY, box.maxY) - max(band.minY, box.minY)
        let smallerHeight = min(band.height, box.height)
        guard smallerHeight > 0 else { return false }
        return overlap / smallerHeight >= sameLineOverlapRatio
    }
}
