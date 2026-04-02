import PhotosUI
import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: EditorViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    pickerSection
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Bar941")
            .navigationBarTitleDisplayMode(.large)
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
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    await viewModel.loadPhoto(from: newValue)
                    selectedItem = nil
                }
            }
            .onChange(of: selectedItems) { _, newValue in
                Task {
                    await viewModel.loadPhotos(from: newValue)
                    selectedItems = []
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("home.hero.title")
                .font(.system(size: 28, weight: .bold, design: .rounded))
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
        .padding(24)
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
}

private extension Text {
    init(localizedKey key: String) {
        self.init(LocalizedStringKey(key))
    }
}
