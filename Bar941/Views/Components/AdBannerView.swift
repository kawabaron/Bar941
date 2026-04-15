import GoogleMobileAds
import SwiftUI
import UIKit

struct AdBannerView: View {
    @State private var availableWidth: CGFloat?

    let adUnitID: String

    var body: some View {
        Group {
            if let availableWidth {
                BannerContainerView(
                    adUnitID: adUnitID,
                    preferredWidth: availableWidth
                )
                .frame(maxWidth: .infinity)
                .frame(height: bannerHeight(for: availableWidth))
            } else {
                Color.clear
                    .frame(height: 0)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateWidth(proxy.size.width)
                    }
                    .onChange(of: proxy.size.width) { _, newValue in
                        updateWidth(newValue)
                    }
            }
        )
    }

    private func bannerHeight(for width: CGFloat) -> CGFloat {
        resolvedBannerAdSize(for: width).size.height
    }

    private func updateWidth(_ newWidth: CGFloat) {
        let measuredWidth = pixelAlignedWidth(max(newWidth, 1))

        guard availableWidth != measuredWidth else { return }
        availableWidth = measuredWidth
    }
}

private struct BannerContainerView: UIViewRepresentable {
    let adUnitID: String
    let preferredWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerHostingView {
        let bannerView = BannerHostingView()
        context.coordinator.hostingView = bannerView
        bannerView.update(
            adUnitID: adUnitID,
            preferredWidth: preferredWidth,
            coordinator: context.coordinator
        )
        return bannerView
    }

    func updateUIView(_ uiView: BannerHostingView, context: Context) {
        context.coordinator.hostingView = uiView
        uiView.update(
            adUnitID: adUnitID,
            preferredWidth: preferredWidth,
            coordinator: context.coordinator
        )
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        weak var hostingView: BannerHostingView?

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            hostingView?.finishLoad(success: true)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            hostingView?.finishLoad(success: false)
            print("[AdBannerView] Failed to load banner: \(error.localizedDescription)")
        }
    }
}

private final class BannerHostingView: UIView {
    private let bannerView = BannerView(adSize: resolvedBannerAdSize(for: 320))
    private var preferredWidth: CGFloat = 0
    private var lastRequestedWidth: CGFloat = 0
    private var hasAttemptedInitialLoad = false
    private var loadFailed = false
    private var isLoading = false
    private var foregroundObserver: NSObjectProtocol?

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)

        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        bannerView.backgroundColor = .clear
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            bannerView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            bannerView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            bannerView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            bannerView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        unregisterForegroundObserver()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            unregisterForegroundObserver()
        } else {
            registerForegroundObserverIfNeeded()
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshBannerIfNeeded()
    }

    func update(
        adUnitID: String,
        preferredWidth: CGFloat,
        coordinator: BannerContainerView.Coordinator
    ) {
        if bannerView.adUnitID != adUnitID {
            bannerView.adUnitID = adUnitID
            resetLoadState()
        }

        self.preferredWidth = preferredWidth
        bannerView.delegate = coordinator
        bannerView.rootViewController = UIApplication.shared.topViewController
        setNeedsLayout()
    }

    func finishLoad(success: Bool) {
        isLoading = false
        loadFailed = !success
    }

    private func refreshBannerIfNeeded(forceRetry: Bool = false) {
        guard window != nil else { return }

        let containerWidth = resolvedContainerWidth()
        guard containerWidth > 1 else { return }

        let adSize = resolvedBannerAdSize(for: containerWidth)
        let adSizeChanged =
            abs(bannerView.adSize.size.width - adSize.size.width) > 0.5 ||
            abs(bannerView.adSize.size.height - adSize.size.height) > 0.5
        let widthChanged = abs(lastRequestedWidth - containerWidth) > 1
        let shouldLoad = !hasAttemptedInitialLoad || widthChanged || (forceRetry && loadFailed)

        if adSizeChanged {
            bannerView.adSize = adSize
            bannerView.invalidateIntrinsicContentSize()
        }

        guard shouldLoad, !isLoading else { return }

        lastRequestedWidth = containerWidth
        hasAttemptedInitialLoad = true
        loadFailed = false
        isLoading = true
        bannerView.rootViewController = UIApplication.shared.topViewController
        bannerView.load(Request())
    }

    private func resolvedContainerWidth() -> CGFloat {
        let measuredWidth = bounds.width
        let candidateWidth = preferredWidth > 0 ? min(preferredWidth, measuredWidth) : measuredWidth
        return pixelAlignedWidth(candidateWidth)
    }

    private func registerForegroundObserverIfNeeded() {
        guard foregroundObserver == nil else { return }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            self.bannerView.rootViewController = UIApplication.shared.topViewController
            self.bannerView.setNeedsLayout()
            self.bannerView.layoutIfNeeded()
            self.refreshBannerIfNeeded(forceRetry: self.loadFailed)
        }
    }

    private func unregisterForegroundObserver() {
        guard let foregroundObserver else { return }

        NotificationCenter.default.removeObserver(foregroundObserver)
        self.foregroundObserver = nil
    }

    private func resetLoadState() {
        lastRequestedWidth = 0
        hasAttemptedInitialLoad = false
        loadFailed = false
        isLoading = false
    }
}

private func resolvedBannerAdSize(for width: CGFloat) -> AdSize {
    largeAnchoredAdaptiveBanner(width: width)
}

private func pixelAlignedWidth(_ width: CGFloat) -> CGFloat {
    let scale = UIScreen.main.scale
    return floor(width * scale) / scale
}

private extension UIApplication {
    var topViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .topMostPresentedViewController
    }
}

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostPresentedViewController
        }

        return self
    }
}
