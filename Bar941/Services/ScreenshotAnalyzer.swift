import CoreGraphics
import UIKit

protocol ScreenshotAnalyzerProtocol {
    func isSupportedScreenshot(size: CGSize) -> Bool
    func detectScreenType(for size: CGSize) -> ScreenType
    func detectPreferredStyle(from image: UIImage) -> StatusBarStyle
}

final class ScreenshotAnalyzer: ScreenshotAnalyzerProtocol {
    private let dynamicIslandSizes: [CGSize] = [
        CGSize(width: 1179, height: 2556),
        CGSize(width: 1206, height: 2622),
        CGSize(width: 1290, height: 2796)
    ]

    private let notchSizes: [CGSize] = [
        CGSize(width: 828, height: 1792),
        CGSize(width: 1125, height: 2436),
        CGSize(width: 1170, height: 2532),
        CGSize(width: 1242, height: 2688),
        CGSize(width: 1284, height: 2778)
    ]

    func isSupportedScreenshot(size: CGSize) -> Bool {
        let normalized = normalizePortrait(size)
        guard normalized.height > normalized.width else { return false }
        guard normalized.width >= 800, normalized.height >= 1700 else { return false }

        let ratio = normalized.height / normalized.width
        let iPhoneRatio: CGFloat = 2.164
        return abs(ratio - iPhoneRatio) <= 0.05
    }

    func detectScreenType(for size: CGSize) -> ScreenType {
        let normalized = normalizePortrait(size)
        let dynamicDistance = closestDistance(from: normalized, to: dynamicIslandSizes)
        let notchDistance = closestDistance(from: normalized, to: notchSizes)

        if dynamicDistance.isFinite || notchDistance.isFinite {
            return dynamicDistance <= notchDistance ? .iPhoneWithDynamicIsland : .iPhoneWithNotch
        }

        return normalized.height >= 2550 ? .iPhoneWithDynamicIsland : .iPhoneWithNotch
    }

    func detectPreferredStyle(from image: UIImage) -> StatusBarStyle {
        guard let cgImage = image.normalizedImage().cgImage else { return .light }

        let sampleHeight = max(Int(CGFloat(cgImage.height) * 0.08), 24)
        let cropRect = CGRect(x: 0, y: 0, width: cgImage.width, height: min(sampleHeight, cgImage.height))

        guard let cropped = cgImage.cropping(to: cropRect) else { return .light }
        let luminance = averageLuminance(of: cropped)
        return luminance >= 0.62 ? .light : .dark
    }

    private func averageLuminance(of cgImage: CGImage) -> CGFloat {
        let targetWidth = 24
        let targetHeight = 8
        let bytesPerPixel = 4
        let bytesPerRow = targetWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: targetWidth * targetHeight * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 1
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        var total: CGFloat = 0
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = CGFloat(pixels[index]) / 255
            let green = CGFloat(pixels[index + 1]) / 255
            let blue = CGFloat(pixels[index + 2]) / 255
            total += 0.299 * red + 0.587 * green + 0.114 * blue
        }

        let pixelCount = CGFloat(targetWidth * targetHeight)
        return total / pixelCount
    }

    private func normalizePortrait(_ size: CGSize) -> CGSize {
        guard size.width > size.height else { return size }
        return CGSize(width: size.height, height: size.width)
    }

    private func closestDistance(from source: CGSize, to candidates: [CGSize]) -> CGFloat {
        guard let bestMatch = candidates.min(by: { distance(from: source, to: $0) < distance(from: source, to: $1) }) else {
            return .infinity
        }

        return distance(from: source, to: bestMatch)
    }

    private func distance(from lhs: CGSize, to rhs: CGSize) -> CGFloat {
        abs(lhs.width - rhs.width) + abs(lhs.height - rhs.height)
    }
}
