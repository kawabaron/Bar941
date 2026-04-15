import SwiftUI

@main
struct Bar941App: App {
    @AppStorage(AppLanguage.storageKey) private var selectedAppLanguage = AppLanguage.system.rawValue
    @StateObject private var adsConsentManager = AdsConsentManager()
    @StateObject private var viewModel = EditorViewModel(
        renderer: ImageRendererService(analyzer: ScreenshotAnalyzer()),
        photoSaveService: PhotoSaveService(),
        reviewPromptService: ReviewPromptService()
    )

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel)
                .environmentObject(adsConsentManager)
                .environment(
                    \.locale,
                    AppLanguage(rawValue: selectedAppLanguage)?.locale ?? .autoupdatingCurrent
                )
                .task {
                    await adsConsentManager.prepareIfNeeded()
                }
        }
    }
}
