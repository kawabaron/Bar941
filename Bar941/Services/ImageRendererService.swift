import UIKit

protocol ImageRendererServiceProtocol {
    func render(image: UIImage, settings: EditorSettings) throws -> RenderResult
}

final class ImageRendererService: ImageRendererServiceProtocol {
    private let analyzer: ScreenshotAnalyzerProtocol
    private let defaultTimeXOffset: CGFloat = 30 + 13
    private let defaultStatusIconsXOffset: CGFloat = -25
    private let defaultStatusIconsScale: CGFloat = 0.93

    init(analyzer: ScreenshotAnalyzerProtocol) {
        self.analyzer = analyzer
    }

    func render(image: UIImage, settings: EditorSettings) throws -> RenderResult {
        let normalized = image.normalizedImage()
        guard analyzer.isSupportedScreenshot(size: normalized.size) else {
            throw AppError.unsupportedImageSize
        }

        let baseConfig = makeConfig(for: normalized.size, style: .light)
        let coverRect = statusBarCoverRect(for: baseConfig)
        let resolvedStyle = resolveStyle(
            requestedStyle: settings.barStyle,
            image: normalized,
            coverRect: coverRect
        )
        let config = makeConfig(for: normalized.size, style: resolvedStyle)
        let backgroundPatch = makeBackgroundPatch(from: normalized, coverRect: coverRect)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: normalized.size, format: format)
        let renderedImage = renderer.image { context in
            let rect = CGRect(origin: .zero, size: normalized.size)
            normalized.draw(in: rect)

            let overlayRect = CGRect(
                x: 0,
                y: 0,
                width: normalized.size.width,
                height: config.topPadding + config.statusBarHeight
            )

            if let backgroundPatch {
                backgroundPatch.draw(in: overlayRect)
            } else {
                fallbackBackgroundColor(from: normalized, coverRect: overlayRect).setFill()
                context.cgContext.fill(overlayRect)
            }

            drawStatusBar(
                in: context.cgContext,
                canvasSize: normalized.size,
                config: config,
                adjustments: settings.layoutAdjustments
            )
        }

        return RenderResult(renderedImage: renderedImage, previewImage: renderedImage)
    }

    private func makeConfig(for size: CGSize, style: StatusBarStyle) -> RenderConfig {
        let screenType = analyzer.detectScreenType(for: size)
        let scale: CGFloat = size.width < 1000 ? 2 : 3

        let topPadding: CGFloat
        let statusBarHeight: CGFloat
        switch screenType {
        case .iPhoneWithDynamicIsland:
            topPadding = 18 * scale
            statusBarHeight = 22 * scale
        case .iPhoneWithNotch, .unknown:
            topPadding = 16 * scale
            statusBarHeight = 22 * scale
        }

        return RenderConfig(
            screenType: screenType,
            canvasSize: size,
            statusBarHeight: statusBarHeight,
            topPadding: topPadding,
            style: style
        )
    }

    private func resolveStyle(
        requestedStyle: StatusBarStyle,
        image: UIImage,
        coverRect: CGRect
    ) -> StatusBarStyle {
        guard requestedStyle == .auto else { return requestedStyle }

        guard let backgroundPatch = makeBackgroundPatch(from: image, coverRect: coverRect) else {
            return analyzer.detectPreferredStyle(from: image)
        }

        return preferredStyle(from: backgroundPatch)
    }

    private func statusBarCoverRect(for config: RenderConfig) -> CGRect {
        CGRect(
            x: 0,
            y: 0,
            width: config.canvasSize.width,
            height: config.topPadding + config.statusBarHeight
        )
    }

    private func makeBackgroundPatch(from image: UIImage, coverRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let samplingRect = backgroundSamplingRect(for: image.size, coverRect: coverRect)
        guard samplingRect.width > 0, samplingRect.height > 0 else { return nil }

        let cropRect = CGRect(
            x: samplingRect.origin.x * image.scale,
            y: samplingRect.origin.y * image.scale,
            width: samplingRect.width * image.scale,
            height: samplingRect.height * image.scale
        ).integral

        guard let sampledImage = cgImage.cropping(to: cropRect) else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: coverRect.size, format: format)

        return renderer.image { _ in
            UIImage(cgImage: sampledImage, scale: 1, orientation: .up)
                .draw(in: CGRect(origin: .zero, size: coverRect.size))
        }
    }

    private func backgroundSamplingRect(for canvasSize: CGSize, coverRect: CGRect) -> CGRect {
        let scale: CGFloat = canvasSize.width < 1000 ? 2 : 3
        let sampleYOffset = max(scale * 1.5, 3)
        let sampleHeight = max(scale * 6, 10)
        let sampleY = min(max(coverRect.maxY + sampleYOffset, 0), canvasSize.height - 1)
        let availableHeight = canvasSize.height - sampleY

        return CGRect(
            x: 0,
            y: sampleY,
            width: canvasSize.width,
            height: min(sampleHeight, availableHeight)
        )
    }

    private func fallbackBackgroundColor(from image: UIImage, coverRect: CGRect) -> UIColor {
        guard let patch = makeBackgroundPatch(from: image, coverRect: coverRect),
              let color = averageColor(of: patch) else {
            return .systemBackground
        }

        return color
    }

    private func preferredStyle(from image: UIImage) -> StatusBarStyle {
        guard let color = averageColor(of: image) else { return .light }
        return luminance(for: color) >= 0.62 ? .light : .dark
    }

    private func averageColor(of image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }

        let targetWidth = 24
        let targetHeight = 4
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
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0

        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            totalRed += CGFloat(pixels[index]) / 255
            totalGreen += CGFloat(pixels[index + 1]) / 255
            totalBlue += CGFloat(pixels[index + 2]) / 255
        }

        let pixelCount = CGFloat(targetWidth * targetHeight)
        return UIColor(
            red: totalRed / pixelCount,
            green: totalGreen / pixelCount,
            blue: totalBlue / pixelCount,
            alpha: 1
        )
    }

    private func luminance(for color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.299 * red + 0.587 * green + 0.114 * blue
    }

    private func drawStatusBar(
        in context: CGContext,
        canvasSize: CGSize,
        config: RenderConfig,
        adjustments: StatusBarLayoutAdjustments
    ) {
        let scale: CGFloat = canvasSize.width < 1000 ? 2 : 3
        let foregroundColor: UIColor = config.style == .dark ? .white : .black
        let timeFont = UIFont.systemFont(
            ofSize: (17 * scale) * adjustments.time.scale,
            weight: .semibold
        )
        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: timeFont,
            .foregroundColor: foregroundColor
        ]

        let horizontalInsets = statusBarHorizontalInsets(for: config.screenType, scale: scale)
        let leftPadding = horizontalInsets.timeLeft
        let rightPadding = horizontalInsets.trailing
        let barCenterY = config.topPadding + (config.statusBarHeight / 2)
        let timeString = "9:41" as NSString
        let timeSize = timeString.size(withAttributes: timeAttributes)
        let timeOrigin = CGPoint(
            x: leftPadding + defaultTimeXOffset + adjustments.time.xOffset,
            y: barCenterY - (timeSize.height / 2) + adjustments.time.yOffset
        )
        timeString.draw(at: timeOrigin, withAttributes: timeAttributes)

        let baseSymbolPointSize = (15 * scale) * defaultStatusIconsScale
        let signalConfig = UIImage.SymbolConfiguration(
            pointSize: baseSymbolPointSize * adjustments.statusIcons.scale,
            weight: .semibold
        )
        let wifiConfig = UIImage.SymbolConfiguration(
            pointSize: baseSymbolPointSize * adjustments.statusIcons.scale,
            weight: .semibold
        )

        let signalImage = UIImage(systemName: "cellularbars", withConfiguration: signalConfig)?
            .withTintColor(foregroundColor, renderingMode: .alwaysOriginal)
        let wifiImage = UIImage(systemName: "wifi", withConfiguration: wifiConfig)?
            .withTintColor(foregroundColor, renderingMode: .alwaysOriginal)

        let signalSize = signalImage?.size ?? CGSize(
            width: (18 * scale * defaultStatusIconsScale) * adjustments.statusIcons.scale,
            height: (12 * scale * defaultStatusIconsScale) * adjustments.statusIcons.scale
        )
        let wifiSize = wifiImage?.size ?? CGSize(
            width: (16 * scale * defaultStatusIconsScale) * adjustments.statusIcons.scale,
            height: (12 * scale * defaultStatusIconsScale) * adjustments.statusIcons.scale
        )
        let batterySize = CGSize(
            width: (26 * scale * defaultStatusIconsScale) * adjustments.statusIcons.scale,
            height: (13 * scale * defaultStatusIconsScale) * adjustments.statusIcons.scale
        )
        let iconSpacing = 6 * scale

        let totalWidth = signalSize.width + wifiSize.width + batterySize.width + (iconSpacing * 2)
        var originX = canvasSize.width - rightPadding - totalWidth

        if let signalImage {
            let rect = CGRect(
                x: originX + defaultStatusIconsXOffset + adjustments.statusIcons.xOffset,
                y: barCenterY - (signalSize.height / 2) + adjustments.statusIcons.yOffset,
                width: signalSize.width,
                height: signalSize.height
            )
            signalImage.draw(in: rect)
        }
        originX += signalSize.width + iconSpacing

        if let wifiImage {
            let rect = CGRect(
                x: originX + defaultStatusIconsXOffset + adjustments.statusIcons.xOffset,
                y: barCenterY - (wifiSize.height / 2) + adjustments.statusIcons.yOffset,
                width: wifiSize.width,
                height: wifiSize.height
            )
            wifiImage.draw(in: rect)
        }
        originX += wifiSize.width + iconSpacing

        drawBattery(
            in: context,
            rect: CGRect(
                x: originX + defaultStatusIconsXOffset + adjustments.statusIcons.xOffset,
                y: barCenterY - (batterySize.height / 2) + adjustments.statusIcons.yOffset,
                width: batterySize.width,
                height: batterySize.height
            ),
            color: foregroundColor
        )
    }

    private func drawBattery(in context: CGContext, rect: CGRect, color: UIColor) {
        let lineWidth = max(rect.height * 0.11, 1.4)
        let bodyWidth = rect.width * 0.86
        let capWidth = rect.width - bodyWidth
        let bodyRect = CGRect(x: rect.minX, y: rect.minY, width: bodyWidth, height: rect.height)
        let capRect = CGRect(
            x: bodyRect.maxX + (capWidth * 0.15),
            y: rect.minY + (rect.height * 0.28),
            width: capWidth * 0.55,
            height: rect.height * 0.44
        )

        let batteryPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: rect.height * 0.22)
        batteryPath.lineWidth = lineWidth
        color.setStroke()
        batteryPath.stroke()

        let fillInset = lineWidth + max(rect.height * 0.08, 1)
        let fillRect = bodyRect.insetBy(dx: fillInset, dy: fillInset).integral
        let fillPath = UIBezierPath(roundedRect: fillRect, cornerRadius: max(fillRect.height * 0.18, 1))
        color.setFill()
        fillPath.fill()

        let capPath = UIBezierPath(roundedRect: capRect, cornerRadius: capRect.width / 2)
        capPath.fill()
    }

    private func statusBarHorizontalInsets(
        for screenType: ScreenType,
        scale: CGFloat
    ) -> (timeLeft: CGFloat, trailing: CGFloat) {
        switch screenType {
        case .iPhoneWithDynamicIsland:
            return (timeLeft: 44 * scale, trailing: 28 * scale)
        case .iPhoneWithNotch:
            return (timeLeft: 39 * scale, trailing: 24 * scale)
        case .unknown:
            return (timeLeft: 37 * scale, trailing: 22 * scale)
        }
    }
}
