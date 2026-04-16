import PhotosUI
import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var adsConsentManager: AdsConsentManager
    @ObservedObject var viewModel: EditorViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var pendingBatchItems: [PhotosPickerItem] = []
    @State private var isBatchRewardPromptPresented = false
    @State private var isStartingBatchEdit = false
    @State private var batchRewardNoticeKey: String?
    @State private var batchRewardNoticeTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    pickerSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if adsConsentManager.canRequestAds,
                   let bannerAdUnitID = AdMobConfiguration.bannerAdUnitID {
                    bannerSection(adUnitID: bannerAdUnitID)
                }
            }
            .sheet(isPresented: $isBatchRewardPromptPresented, onDismiss: {
                if !isStartingBatchEdit {
                    pendingBatchItems = []
                }
            }) {
                BatchRewardPromptView(
                    isAdReady: adsConsentManager.isRewardedInterstitialReady,
                    isProcessing: isStartingBatchEdit,
                    onContinue: {
                        Task {
                            await continueBatchFlow()
                        }
                    },
                    onCancel: dismissBatchRewardPrompt
                )
                .interactiveDismissDisabled(isStartingBatchEdit)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(Text("settings.title"))
                }
            }
            .navigationDestination(isPresented: $viewModel.isEditorPresented) {
                EditorView(viewModel: viewModel)
            }
            .alert("common.error", isPresented: errorBinding) {
                Button("common.ok", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessageKey = viewModel.errorMessageKey {
                    Text(localizedKey: errorMessageKey)
                }
            }
            .overlay(alignment: .top) {
                if let batchRewardNoticeKey {
                    toast(messageKey: batchRewardNoticeKey)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: batchRewardNoticeKey)
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    await viewModel.loadPhoto(from: newValue)
                    selectedItem = nil
                }
            }
            .onChange(of: selectedItems) { _, newValue in
                guard !newValue.isEmpty else { return }

                if newValue.count > 1 {
                    batchRewardNoticeKey = nil
                    selectedItems = []

                    if adsConsentManager.shouldOfferRewardedInterstitial {
                        pendingBatchItems = newValue
                        isBatchRewardPromptPresented = true

                        Task {
                            await adsConsentManager.prepareRewardedInterstitialIfNeeded()
                        }
                    } else {
                        let selectedBatchItems = newValue
                        pendingBatchItems = []

                        Task {
                            await viewModel.loadPhotos(from: selectedBatchItems)
                        }
                    }
                } else {
                    let selectedItems = newValue
                    self.selectedItems = []

                    Task {
                        await viewModel.loadPhotos(from: selectedItems)
                    }
                }
            }
        }
    }

    private func bannerSection(adUnitID: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AdBannerView(adUnitID: adUnitID)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
        .padding(.bottom, 4)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func continueBatchFlow() async {
        guard !pendingBatchItems.isEmpty else {
            dismissBatchRewardPrompt()
            return
        }

        let selectedBatchItems = pendingBatchItems
        let shouldPresentRewardedInterstitial = adsConsentManager.isRewardedInterstitialReady
        isStartingBatchEdit = true

        if shouldPresentRewardedInterstitial {
            let result = await adsConsentManager.presentRewardedInterstitial()

            switch result {
            case .rewarded:
                dismissBatchRewardPrompt()
                await viewModel.loadPhotos(from: selectedBatchItems)
            case .unavailable, .failed:
                dismissBatchRewardPrompt()
                await viewModel.loadPhotos(from: selectedBatchItems)
            case .skipped:
                dismissBatchRewardPrompt()
                showBatchRewardNotice("home.multiPicker.reward.skipped")
            }

            return
        }

        dismissBatchRewardPrompt()
        await viewModel.loadPhotos(from: selectedBatchItems)
    }

    private func dismissBatchRewardPrompt() {
        isStartingBatchEdit = false
        isBatchRewardPromptPresented = false
        pendingBatchItems = []
    }

    private func showBatchRewardNotice(_ messageKey: String) {
        batchRewardNoticeTask?.cancel()
        batchRewardNoticeKey = messageKey

        batchRewardNoticeTask = Task {
            try? await Task.sleep(for: .seconds(2.5))

            guard !Task.isCancelled else { return }
            batchRewardNoticeKey = nil
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("home.hero.title")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(heroTitleColor)

            Text("home.hero.body")
                .font(.callout)
                .foregroundStyle(heroBodyColor)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                featureChip(titleKey: "home.feature.fixedTime")
                featureChip(titleKey: "home.feature.save")
                featureChip(titleKey: "home.feature.share")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: heroGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    @MainActor
    private var pickerSection: some View {
        let isRendering = viewModel.isRendering

        return VStack(alignment: .leading, spacing: 12) {
            Text("home.picker.title")
                .font(.headline)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                pickerButtonLabel(
                    titleKey: isRendering ? "home.picker.loading" : "home.picker.button",
                    systemImage: "photo.on.rectangle.angled",
                    isPrimary: true,
                    isLoading: isRendering
                )
            }
            .disabled(isRendering)

            Text("home.multiPicker.title")
                .font(.headline)
                .padding(.top, 4)

            PhotosPicker(selection: $selectedItems, maxSelectionCount: 30, matching: .images) {
                pickerButtonLabel(
                    titleKey: isRendering ? "home.picker.loading" : "home.multiPicker.button",
                    systemImage: "square.stack.3d.up",
                    isPrimary: false,
                    isLoading: isRendering
                )
            }
            .disabled(isRendering)

            Text("home.picker.support")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func pickerButtonLabel(
        titleKey: LocalizedStringKey,
        systemImage: String,
        isPrimary: Bool,
        isLoading: Bool
    ) -> some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(isPrimary ? .white : .accentColor)
            } else {
                Image(systemName: systemImage)
                    .font(.title3)
            }

            Text(titleKey)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.accentColor)
        )
    }

    private func featureChip(titleKey: LocalizedStringKey) -> some View {
        Text(titleKey)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(heroChipTextColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(heroChipBackgroundColor, in: Capsule())
    }

    private var heroTitleColor: Color {
        Color(red: 0.11, green: 0.15, blue: 0.13)
    }

    private var heroBodyColor: Color {
        Color(red: 0.29, green: 0.35, blue: 0.32)
    }

    private var heroChipTextColor: Color {
        Color(red: 0.20, green: 0.26, blue: 0.23)
    }

    private var heroChipBackgroundColor: Color {
        Color.white.opacity(colorScheme == .dark ? 0.92 : 0.78)
    }

    private var heroGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.90, green: 0.95, blue: 0.90),
                Color(red: 0.82, green: 0.91, blue: 0.83)
            ]
        }

        return [
            Color(red: 0.95, green: 0.98, blue: 0.95),
            Color(red: 0.89, green: 0.96, blue: 0.90)
        ]
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessageKey != nil },
            set: { newValue in
                if !newValue {
                    viewModel.clearError()
                }
            }
        )
    }

    private func toast(messageKey: String) -> some View {
        Text(localizedKey: messageKey)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
            .padding(.horizontal, 20)
    }
}

private extension Text {
    init(localizedKey key: String) {
        self.init(LocalizedStringKey(key))
    }
}

private struct BatchRewardPromptView: View {
    let isAdReady: Bool
    let isProcessing: Bool
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 8) {
                    Text("home.multiPicker.reward.title")
                        .font(.title3.weight(.bold))

                    Text("home.multiPicker.reward.body")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isAdReady {
                Text("home.multiPicker.reward.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.accentColor.opacity(0.08))
                    )
            } else {
                Text("home.multiPicker.reward.unavailable")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.accentColor.opacity(0.08))
                    )
            }

            VStack(spacing: 12) {
                HStack {
                    Spacer(minLength: 0)

                    Button(action: onContinue) {
                        Group {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 4)
                            } else if isAdReady {
                                Text("home.multiPicker.reward.watch")
                                    .padding(.horizontal, 28)
                            } else {
                                Text("home.multiPicker.reward.continue")
                                    .padding(.horizontal, 28)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isProcessing)

                    Spacer(minLength: 0)
                }

                HStack {
                    Spacer(minLength: 0)

                    Button("home.multiPicker.reward.cancel", role: .cancel, action: onCancel)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(isProcessing)

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}
