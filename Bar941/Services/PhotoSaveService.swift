import Photos
import UIKit

protocol PhotoSaveServiceProtocol {
    func save(_ image: UIImage) async throws
}

final class PhotoSaveService: PhotoSaveServiceProtocol {
    func save(_ image: UIImage) async throws {
        let authorizationStatus = await requestAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw AppError.photoAccessDenied
        }

        guard let imageData = image.pngData() else {
            throw AppError.photoSaveFailed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: AppError.photoSaveFailed)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppError.photoSaveFailed)
                }
            })
        }
    }

    private func requestAuthorization() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard currentStatus == .notDetermined else { return currentStatus }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
