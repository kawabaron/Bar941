import Photos
import UIKit

protocol PhotoSaveServiceProtocol {
    func save(_ image: UIImage) async throws
    func save(_ images: [UIImage]) async throws
}

final class PhotoSaveService: PhotoSaveServiceProtocol {
    func save(_ image: UIImage) async throws {
        try await save([image])
    }

    func save(_ images: [UIImage]) async throws {
        guard !images.isEmpty else { return }

        let authorizationStatus = await requestAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw AppError.photoAccessDenied
        }

        let imageDataList = images.compactMap { $0.pngData() }
        guard imageDataList.count == images.count else {
            throw AppError.photoSaveFailed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                for imageData in imageDataList {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: imageData, options: nil)
                }
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
