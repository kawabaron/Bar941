import UIKit

extension UIImage {
    func normalizedImage() -> UIImage {
        guard imageOrientation != .up else { return self }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func croppedTopSection(heightRatio: CGFloat = 0.14) -> UIImage? {
        guard let cgImage else { return nil }

        let safeRatio = min(max(heightRatio, 0.05), 0.35)
        let cropHeight = max(Int(CGFloat(cgImage.height) * safeRatio), 1)
        let cropRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cropHeight)

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
