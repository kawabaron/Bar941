import SwiftUI

@main
struct Bar941App: App {
    @AppStorage(AppLanguage.storageKey) private var selectedAppLanguage = AppLanguage.system.rawValue
    @StateObject private var viewModel = EditorViewModel(
        renderer: ImageRendererService(analyzer: ScreenshotAnalyzer()),
        photoSaveService: PhotoSaveService()
    )

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel)
                .environment(
                    \.locale,
                    AppLanguage(rawValue: selectedAppLanguage)?.locale ?? .autoupdatingCurrent
                )
        }
    }
}
