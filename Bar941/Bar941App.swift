import SwiftUI

@main
struct Bar941App: App {
    @StateObject private var viewModel = EditorViewModel(
        renderer: ImageRendererService(analyzer: ScreenshotAnalyzer()),
        photoSaveService: PhotoSaveService()
    )

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel)
        }
    }
}
