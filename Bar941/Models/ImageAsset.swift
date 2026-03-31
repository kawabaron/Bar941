import UIKit

struct ImageAsset: Identifiable {
    let id: UUID
    let originalImage: UIImage
    let size: CGSize
    let scale: CGFloat

    init(id: UUID = UUID(), originalImage: UIImage) {
        self.id = id
        self.originalImage = originalImage
        self.size = originalImage.size
        self.scale = originalImage.scale
    }
}
