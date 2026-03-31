import PhotosUI
import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: EditorViewModel
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    pickerSection

                    if let selectedImage = viewModel.selectedImage {
                        previewCard(image: selectedImage)
                    }
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Bar941")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $viewModel.isEditorPresented) {
                EditorView(viewModel: viewModel)
            }
            .alert("エラー", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    await viewModel.loadPhoto(from: newValue)
                    selectedItem = nil
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("App Store 用スクショの上部を、9:41 のきれいなステータスバーに整えます。")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(heroTitleColor)

            Text("写真ライブラリから iPhone スクリーンショットを選ぶだけで、上部バーを自然に差し替えて保存や共有までできます。")
                .font(.callout)
                .foregroundStyle(heroBodyColor)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                featureChip(title: "9:41 固定")
                featureChip(title: "保存")
                featureChip(title: "共有")
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
            Text("1 枚のスクリーンショットを選択")
                .font(.headline)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 12) {
                    if isRendering {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3)
                    }

                    Text(isRendering ? "画像を読み込み中..." : "スクリーンショットを選ぶ")
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
            .disabled(isRendering)

            Text("主要な iPhone 縦長スクリーンショットに対応しています。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func previewCard(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近読み込んだ画像")
                .font(.headline)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        }
    }

    private func featureChip(title: String) -> some View {
        Text(title)
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
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.clearError()
                }
            }
        )
    }
}
