import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var sourceImages: [UIImage] = []
    @Published var selectedImage: UIImage?
    @Published var renderedImage: UIImage?
    @Published var previewImage: UIImage?
    @Published var settings: EditorSettings = .init()
    @Published var isRendering = false
    @Published var isSaving = false
    @Published var isPreparingShare = false
    @Published var errorMessageKey: String?
    @Published var successMessageKey: String?
    @Published var isEditorPresented = false
    @Published var shareImages: [UIImage] = []

    private let renderer: ImageRendererServiceProtocol
    private let photoSaveService: PhotoSaveServiceProtocol
    private var successTask: Task<Void, Never>?

    init(
        renderer: ImageRendererServiceProtocol,
        photoSaveService: PhotoSaveServiceProtocol
    ) {
        self.renderer = renderer
        self.photoSaveService = photoSaveService
    }

    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        await loadPhotos(from: [item])
    }

    func loadPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        do {
            let images = try await loadImages(from: items)
            try presentEditor(with: images)
        } catch {
            resetEditorState()
            handle(error)
        }
    }

    func apply(settings: EditorSettings) {
        self.settings = settings

        do {
            try renderCurrentImage()
        } catch {
            handle(error)
        }
    }

    func saveRenderedImage() async {
        guard !sourceImages.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            let outputImages = try renderOutputImages()
            try await photoSaveService.save(outputImages)
            showSuccess("success.saved")
        } catch {
            handle(error)
        }
    }

    func prepareShare() async {
        guard !sourceImages.isEmpty else { return }

        isPreparingShare = true
        defer { isPreparingShare = false }

        do {
            shareImages = try renderOutputImages()
        } catch {
            handle(error)
        }
    }

    func dismissShareSheet() {
        shareImages = []
    }

    func clearError() {
        errorMessageKey = nil
    }

    func clearSuccess() {
        successMessageKey = nil
    }

    var sourceImageCount: Int {
        sourceImages.count
    }

    var hasMultipleSourceImages: Bool {
        sourceImages.count > 1
    }

    private func renderCurrentImage() throws {
        guard let selectedImage else {
            throw AppError.renderFailed
        }

        isRendering = true
        defer { isRendering = false }

        let result = try renderer.render(image: selectedImage, settings: settings)
        renderedImage = result.renderedImage
        previewImage = result.previewImage
    }

    private func renderOutputImages() throws -> [UIImage] {
        guard !sourceImages.isEmpty else {
            throw AppError.renderFailed
        }

        return try sourceImages.map { image in
            try renderer.render(image: image, settings: settings).renderedImage
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async throws -> [UIImage] {
        var images: [UIImage] = []
        images.reserveCapacity(items.count)

        for item in items {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AppError.invalidImageData
            }

            guard let image = UIImage(data: data)?.normalizedImage() else {
                throw AppError.invalidImageData
            }

            images.append(image)
        }

        guard !images.isEmpty else {
            throw AppError.invalidImageData
        }

        return images
    }

    private func presentEditor(with images: [UIImage]) throws {
        guard let representativeImage = images.first else {
            throw AppError.invalidImageData
        }

        sourceImages = images
        selectedImage = representativeImage
        settings = .init()
        shareImages = []
        try renderCurrentImage()
        isEditorPresented = true
    }

    private func resetEditorState() {
        sourceImages = []
        selectedImage = nil
        renderedImage = nil
        previewImage = nil
        isEditorPresented = false
        shareImages = []
    }

    private func showSuccess(_ messageKey: String) {
        successTask?.cancel()
        successMessageKey = messageKey
        successTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.successMessageKey = nil
        }
    }

    private func handle(_ error: Error) {
        if let appError = error as? AppError {
            errorMessageKey = appError.localizationKey
        } else {
            errorMessageKey = AppError.renderFailed.localizationKey
        }
    }
}
