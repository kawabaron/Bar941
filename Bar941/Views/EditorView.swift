import SwiftUI

struct EditorView: View {
    enum PreviewMode: String, CaseIterable, Identifiable {
        case processed = "加工後"
        case original = "加工前"

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: EditorViewModel
    @State private var previewMode: PreviewMode = .processed
    @State private var draftSettings: EditorSettings
    @State private var isTimeAdjustmentExpanded = true
    @State private var isStatusIconsAdjustmentExpanded = false
    @State private var showsOriginalOverlay = false

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        _draftSettings = State(initialValue: viewModel.settings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                previewModePicker
                mainPreview
                topPreview
                adjustmentCard
                settingsCard
                actionButtons
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("編集")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: shareSheetBinding, onDismiss: viewModel.dismissShareSheet) {
            if let shareImage = viewModel.shareImage {
                ShareSheet(items: [shareImage])
            }
        }
        .alert("エラー", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if let successMessage = viewModel.successMessage {
                toast(message: successMessage)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.successMessage)
        .onAppear {
            draftSettings = viewModel.settings
        }
        .onChange(of: draftSettings) { _, newValue in
            viewModel.apply(settings: newValue)
        }
    }

    private var displayedImage: UIImage? {
        switch previewMode {
        case .processed:
            return viewModel.previewImage ?? viewModel.renderedImage
        case .original:
            return viewModel.selectedImage
        }
    }

    private var shouldShowOriginalOverlay: Bool {
        previewMode == .processed && showsOriginalOverlay
    }

    private var previewModePicker: some View {
        Picker("Preview", selection: $previewMode) {
            ForEach(PreviewMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var mainPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("画像プレビュー")
                .font(.headline)

            Group {
                if let displayedImage {
                    previewImageView(
                        processedImage: displayedImage,
                        originalImage: shouldShowOriginalOverlay ? viewModel.selectedImage : nil
                    )
                } else {
                    ContentUnavailableView("プレビューを準備中", systemImage: "photo")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var topPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("上部拡大")
                    .font(.headline)

                Spacer()

                checkboxToggle(
                    title: "元画像を透かす",
                    isOn: $showsOriginalOverlay
                )
            }

            Group {
                if let cropped = displayedImage?.croppedTopSection() {
                    previewImageView(
                        processedImage: cropped,
                        originalImage: shouldShowOriginalOverlay ? viewModel.selectedImage?.croppedTopSection() : nil
                    )
                } else {
                    ContentUnavailableView("上部プレビューなし", systemImage: "rectangle.tophalf.inset.filled")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bar Style")
                .font(.headline)

            Picker("Bar Style", selection: $draftSettings.barStyle) {
                ForEach(StatusBarStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Text("Auto は上端の背景から明暗を推定し、Light / Dark は文字色を固定します。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var adjustmentCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
            Text("微調整")
                .font(.headline)

                Spacer()

                Button("リセット") {
                    draftSettings.layoutAdjustments = .init()
                }
                .font(.footnote.weight(.semibold))
            }

            Text("時間と右側アイコン群の位置・サイズを調整すると、上部拡大プレビューにすぐ反映されます。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            adjustmentDisclosureSection(
                title: "時間",
                isExpanded: $isTimeAdjustmentExpanded,
                adjustment: binding(for: \.time)
            )
            adjustmentDisclosureSection(
                title: "右側アイコン",
                isExpanded: $isStatusIconsAdjustmentExpanded,
                adjustment: binding(for: \.statusIcons)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.saveRenderedImage()
                }
            } label: {
                Text(viewModel.isSaving ? "保存中..." : "写真ライブラリに保存")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.renderedImage == nil || viewModel.isSaving || viewModel.isRendering)

            Button {
                viewModel.prepareShare()
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.renderedImage == nil || viewModel.isRendering)
        }
    }

    private func toast(message: String) -> some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
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

    private func adjustmentSection(
        adjustment: Binding<StatusBarElementAdjustment>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            adjustmentSliderRow(
                title: "横位置",
                value: valueBinding(for: \.xOffset, in: adjustment),
                range: -120...120,
                step: 1,
                valueFormat: "%.0f px"
            )
            adjustmentSliderRow(
                title: "縦位置",
                value: valueBinding(for: \.yOffset, in: adjustment),
                range: -80...80,
                step: 1,
                valueFormat: "%.0f px"
            )
            adjustmentSliderRow(
                title: "サイズ",
                value: valueBinding(for: \.scale, in: adjustment),
                range: 0.6...1.6,
                step: 0.01,
                valueFormat: "%.2f x"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }

    private func adjustmentDisclosureSection(
        title: String,
        isExpanded: Binding<Bool>,
        adjustment: Binding<StatusBarElementAdjustment>
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            adjustmentSection(adjustment: adjustment)
                .padding(.top, 10)
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
    }

    private func previewImageView(
        processedImage: UIImage,
        originalImage: UIImage?
    ) -> some View {
        ZStack {
            Image(uiImage: processedImage)
                .resizable()
                .scaledToFit()

            if let originalImage {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.28)
                    .blendMode(.normal)
            }
        }
    }

    private func checkboxToggle(title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.body)
                Text(title)
                    .font(.footnote.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
    }

    private func adjustmentSliderRow(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat,
        valueFormat: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.footnote.weight(.medium))

                Spacer()

                Text(String(format: valueFormat, value.wrappedValue))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range, step: step)
        }
    }

    private func binding(
        for keyPath: WritableKeyPath<StatusBarLayoutAdjustments, StatusBarElementAdjustment>
    ) -> Binding<StatusBarElementAdjustment> {
        Binding(
            get: { draftSettings.layoutAdjustments[keyPath: keyPath] },
            set: { draftSettings.layoutAdjustments[keyPath: keyPath] = $0 }
        )
    }

    private func valueBinding(
        for keyPath: WritableKeyPath<StatusBarElementAdjustment, CGFloat>,
        in adjustment: Binding<StatusBarElementAdjustment>
    ) -> Binding<CGFloat> {
        Binding(
            get: { adjustment.wrappedValue[keyPath: keyPath] },
            set: { adjustment.wrappedValue[keyPath: keyPath] = $0 }
        )
    }

    private var shareSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.shareImage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.dismissShareSheet()
                }
            }
        )
    }
}
