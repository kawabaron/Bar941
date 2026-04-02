import SwiftUI

struct EditorView: View {
    enum PreviewMode: String, CaseIterable, Identifiable {
        case processed
        case original

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .processed:
                return "editor.preview.mode.processed"
            case .original:
                return "editor.preview.mode.original"
            }
        }
    }

    @ObservedObject var viewModel: EditorViewModel
    @AppStorage(AppLanguage.storageKey) private var selectedLanguageCode = AppLanguage.system.rawValue
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
                if viewModel.hasMultipleSourceImages {
                    batchInfoCard
                }
                actionButtons
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("editor.title")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: shareSheetBinding, onDismiss: viewModel.dismissShareSheet) {
            if !viewModel.shareImages.isEmpty {
                ShareSheet(items: viewModel.shareImages.map { $0 as Any })
            }
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
            if let successMessageKey = viewModel.successMessageKey {
                toast(messageKey: successMessageKey)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.successMessageKey)
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
        Picker("editor.preview.mode.label", selection: $previewMode) {
            ForEach(PreviewMode.allCases) { mode in
                Text(mode.titleKey).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var mainPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("editor.preview.title")
                .font(.headline)

            Group {
                if let displayedImage {
                    previewImageView(
                        processedImage: displayedImage,
                        originalImage: shouldShowOriginalOverlay ? viewModel.selectedImage : nil
                    )
                } else {
                    ContentUnavailableView("editor.preview.loading", systemImage: "photo")
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
                Text("editor.topPreview.title")
                    .font(.headline)

                Spacer()

                checkboxToggle(
                    titleKey: "editor.topPreview.overlay",
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
                    ContentUnavailableView("editor.topPreview.empty", systemImage: "rectangle.tophalf.inset.filled")
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
            Text("editor.style.title")
                .font(.headline)

            Picker("editor.style.title", selection: $draftSettings.barStyle) {
                ForEach(StatusBarStyle.allCases) { style in
                    Text(style.titleKey).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Text("editor.style.description")
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
                Text("editor.adjustment.title")
                    .font(.headline)

                Spacer()

                Button("editor.adjustment.reset") {
                    draftSettings.layoutAdjustments = .init()
                }
                .font(.footnote.weight(.semibold))
            }

            Text("editor.adjustment.description")
                .font(.footnote)
                .foregroundStyle(.secondary)

            adjustmentDisclosureSection(
                titleKey: "editor.adjustment.time",
                isExpanded: $isTimeAdjustmentExpanded,
                adjustment: binding(for: \.time)
            )
            adjustmentDisclosureSection(
                titleKey: "editor.adjustment.statusIcons",
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
                if viewModel.isSaving {
                    Text("editor.actions.saving")
                        .frame(maxWidth: .infinity)
                } else {
                    Text("editor.actions.save")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.renderedImage == nil || viewModel.isSaving || viewModel.isRendering)

            Button {
                Task {
                    await viewModel.prepareShare()
                }
            } label: {
                Label("editor.actions.share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(
                viewModel.renderedImage == nil ||
                viewModel.isRendering ||
                viewModel.isSaving ||
                viewModel.isPreparingShare
            )
        }
    }

    private var batchInfoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("editor.batch.title")
                    .font(.subheadline.weight(.semibold))

                Text("editor.batch.description")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(viewModel.sourceImageCount)")
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.10), in: Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func toast(messageKey: String) -> some View {
        Text(localizedKey: messageKey)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
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

    private func adjustmentSection(
        adjustment: Binding<StatusBarElementAdjustment>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            adjustmentSliderRow(
                titleKey: "editor.adjustment.x",
                value: valueBinding(for: \.xOffset, in: adjustment),
                range: -120...120,
                step: 1,
                valueText: AppLocalizer.format(
                    "editor.adjustment.value.pixels",
                    languageCode: selectedLanguageCode,
                    valueBinding(for: \.xOffset, in: adjustment).wrappedValue
                )
            )
            adjustmentSliderRow(
                titleKey: "editor.adjustment.y",
                value: valueBinding(for: \.yOffset, in: adjustment),
                range: -80...80,
                step: 1,
                valueText: AppLocalizer.format(
                    "editor.adjustment.value.pixels",
                    languageCode: selectedLanguageCode,
                    valueBinding(for: \.yOffset, in: adjustment).wrappedValue
                )
            )
            adjustmentSliderRow(
                titleKey: "editor.adjustment.scale",
                value: valueBinding(for: \.scale, in: adjustment),
                range: 0.6...1.6,
                step: 0.01,
                valueText: AppLocalizer.format(
                    "editor.adjustment.value.scale",
                    languageCode: selectedLanguageCode,
                    valueBinding(for: \.scale, in: adjustment).wrappedValue
                )
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }

    private func adjustmentDisclosureSection(
        titleKey: LocalizedStringKey,
        isExpanded: Binding<Bool>,
        adjustment: Binding<StatusBarElementAdjustment>
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            adjustmentSection(adjustment: adjustment)
                .padding(.top, 10)
        } label: {
            HStack {
                Text(titleKey)
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

    private func checkboxToggle(titleKey: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.body)
                Text(titleKey)
                    .font(.footnote.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
    }

    private func adjustmentSliderRow(
        titleKey: LocalizedStringKey,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(titleKey)
                    .font(.footnote.weight(.medium))

                Spacer()

                Text(valueText)
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
            get: { !viewModel.shareImages.isEmpty },
            set: { newValue in
                if !newValue {
                    viewModel.dismissShareSheet()
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
