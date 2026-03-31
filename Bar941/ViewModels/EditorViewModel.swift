import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var renderedImage: UIImage?
    @Published var previewImage: UIImage?
    @Published var settings: EditorSettings = .init()
    @Published var isRendering = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isEditorPresented = false
    @Published var shareImage: UIImage?

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

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AppError.invalidImageData
            }

            guard let image = UIImage(data: data)?.normalizedImage() else {
                throw AppError.invalidImageData
            }

            selectedImage = image
            settings = .init()
            try renderCurrentImage()
            isEditorPresented = true
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
        guard let renderedImage else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await photoSaveService.save(renderedImage)
            showSuccess("写真ライブラリに保存しました")
        } catch {
            handle(error)
        }
    }

    func prepareShare() {
        shareImage = renderedImage
    }

    func dismissShareSheet() {
        shareImage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func clearSuccess() {
        successMessage = nil
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

    private func resetEditorState() {
        selectedImage = nil
        renderedImage = nil
        previewImage = nil
        isEditorPresented = false
        shareImage = nil
    }

    private func showSuccess(_ message: String) {
        successTask?.cancel()
        successMessage = message
        successTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.successMessage = nil
        }
    }

    private func handle(_ error: Error) {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            errorMessage = description
        } else {
            errorMessage = AppError.renderFailed.errorDescription
        }
    }
}
