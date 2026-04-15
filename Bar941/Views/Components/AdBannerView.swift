import GoogleMobileAds
import SwiftUI
import UIKit

struct AdBannerView: View {
    @State private var availableWidth = UIScreen.main.bounds.width - 48

    let adUnitID: String

    var body: some View {
        BannerContainerView(
            adUnitID: adUnitID,
            width: max(availableWidth, 320)
        )
        .frame(height: bannerHeight)
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

    private var bannerHeight: CGFloat {
        currentOrientationAnchoredAdaptiveBanner(width: max(availableWidth, 320)).size.height
    }

    private func updateWidth(_ newWidth: CGFloat) {
        availableWidth = max(newWidth, 320)
    }
}

private struct BannerContainerView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        bannerView.rootViewController = UIApplication.shared.topViewController
        bannerView.load(Request())
        context.coordinator.lastLoadedWidth = width
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = uiView.rootViewController ?? UIApplication.shared.topViewController

        guard abs(context.coordinator.lastLoadedWidth - width) > 1 else {
            return
        }

        uiView.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        uiView.load(Request())
        context.coordinator.lastLoadedWidth = width
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var lastLoadedWidth: CGFloat = 0

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdBannerView] Failed to load banner: \(error.localizedDescription)")
        }
    }
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
