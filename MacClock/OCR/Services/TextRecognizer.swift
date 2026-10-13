//
//  TextRecognizer.swift
//  MacClock
//
//  使用 macOS 內建 Vision 框架進行文字辨識（完全離線，不上傳任何資料）
//

import CoreGraphics
import Foundation
import Vision

nonisolated struct TextRecognitionOptions: Hashable, Sendable {
    let languages: [String]
    let accurate: Bool
    let usesLanguageCorrection: Bool

    init(settings: OCRSettings) {
        languages = settings.languages.map(\.rawValue)
        accurate = settings.accurateMode
        usesLanguageCorrection = settings.usesLanguageCorrection
    }

    init(languages: [String], accurate: Bool, usesLanguageCorrection: Bool) {
        self.languages = languages
        self.accurate = accurate
        self.usesLanguageCorrection = usesLanguageCorrection
    }
}

nonisolated enum TextRecognizer {

    /// 執行 OCR；Vision 的 perform 為同步阻塞呼叫，因此丟到背景執行緒避免卡住 UI
    static func recognize(_ image: CGImage, options: TextRecognitionOptions) async throws -> [RecognizedFragment] {
        try await Task.detached(priority: .userInitiated) {
            try recognizeSync(image, options: options)
        }.value
    }

    /// Vision 精準模式在影像任一邊太小時會失敗（例如只框選一行字）；補邊到這個大小即可正常辨識
    static let minimumSide = 64

    static func recognizeSync(_ image: CGImage, options: TextRecognitionOptions) throws -> [RecognizedFragment] {
        let prepared = padIfNeeded(image)
        return try RequestPool.shared.withLock { pool in
            do {
                return try perform(prepared, request: pool.request(for: options))
            } catch {
                // 快取的辨識器失效時，重建一次再試
                pool.discard(options)
                do {
                    return try perform(prepared, request: pool.request(for: options))
                } catch where options.accurate {
                    // 仍失敗時改用快速模式，至少不讓使用者看到錯誤
                    let fast = TextRecognitionOptions(
                        languages: options.languages,
                        accurate: false,
                        usesLanguageCorrection: options.usesLanguageCorrection
                    )
                    return try perform(prepared, request: pool.request(for: fast))
                }
            }
        }
    }

    private static func perform(_ image: CGImage, request: VNRecognizeTextRequest) throws -> [RecognizedFragment] {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedFragment(text: candidate.string, boundingBox: observation.boundingBox)
        }
    }

    fileprivate static func makeRequest(_ options: TextRecognitionOptions) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = options.accurate ? .accurate : .fast
        request.usesLanguageCorrection = options.usesLanguageCorrection

        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let languages = filterSupported(options.languages, supported: supported)
        if languages.isEmpty {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = languages
        }

        return request
    }

    /// 補邊後的尺寸：每邊至少 minimumSide
    static func paddedSize(width: Int, height: Int, minimumSide: Int = minimumSide) -> (width: Int, height: Int) {
        (max(width, minimumSide), max(height, minimumSide))
    }

    /// 影像太小時置中補邊；補邊顏色取四角平均，讓深色背景的截圖也維持一致
    static func padIfNeeded(_ image: CGImage) -> CGImage {
        let size = paddedSize(width: image.width, height: image.height)
        guard size.width != image.width || size.height != image.height,
              let context = CGContext(
                data: nil,
                width: size.width,
                height: size.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return image }

        context.setFillColor(backgroundColor(of: image))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        context.draw(image, in: CGRect(
            x: (size.width - image.width) / 2,
            y: (size.height - image.height) / 2,
            width: image.width,
            height: image.height
        ))
        return context.makeImage() ?? image
    }

    /// 四個角落像素的平均色（每個角落只裁 1×1 讀取，不配置整張影像）
    private static func backgroundColor(of image: CGImage) -> CGColor {
        let white = CGColor(gray: 1, alpha: 1)
        let maxX = image.width - 1
        let maxY = image.height - 1
        guard maxX >= 0, maxY >= 0 else { return white }

        let corners = [(0, 0), (maxX, 0), (0, maxY), (maxX, maxY)]
        var totals = (r: 0, g: 0, b: 0)
        var pixel = [UInt8](repeating: 255, count: 4)
        for (x, y) in corners {
            guard let corner = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { return white }
            let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(
                    data: buffer.baseAddress,
                    width: 1,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                context.draw(corner, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return true
            }
            guard drawn else { return white }
            totals.r += Int(pixel[0])
            totals.g += Int(pixel[1])
            totals.b += Int(pixel[2])
        }
        let count = CGFloat(corners.count * 255)
        return CGColor(
            red: CGFloat(totals.r) / count,
            green: CGFloat(totals.g) / count,
            blue: CGFloat(totals.b) / count,
            alpha: 1
        )
    }

    /// 只保留 Vision 支援的語言，維持使用者設定的優先順序
    static func filterSupported(_ requested: [String], supported: [String]) -> [String] {
        guard !supported.isEmpty else { return requested }
        let supportedSet = Set(supported)
        return requested.filter { supportedSet.contains($0) }
    }
}

/// 重複使用 Vision 辨識器
/// 沙盒中每次重新建立中文精準辨識器時，第二次起載入模型會失敗（CRImageReaderError / e5rt error），
/// 重複使用同一個 request 則可穩定辨識。VNRecognizeTextRequest 不是執行緒安全的，因此以鎖序列化。
private final class RequestPool: @unchecked Sendable {
    static let shared = RequestPool()

    private let lock = NSLock()
    private var requests: [TextRecognitionOptions: VNRecognizeTextRequest] = [:]

    func withLock<T>(_ body: (RequestPool) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(self)
    }

    /// 呼叫端需持有鎖
    func request(for options: TextRecognitionOptions) -> VNRecognizeTextRequest {
        if let existing = requests[options] { return existing }
        let request = TextRecognizer.makeRequest(options)
        requests[options] = request
        return request
    }

    /// 呼叫端需持有鎖
    func discard(_ options: TextRecognitionOptions) {
        requests[options] = nil
    }
}
