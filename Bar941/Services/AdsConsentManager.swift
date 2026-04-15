import Foundation
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdsConsentManager: NSObject, ObservableObject {
    private static let rewardedInterstitialLastRewardDateKey =
        "AdsConsentManager.rewardedInterstitialLastRewardDate"

    enum RewardedInterstitialResult {
        case rewarded
        case skipped
        case unavailable
        case failed
    }

    @Published private(set) var canRequestAds = false
    @Published private(set) var isPrivacyOptionsRequired = false
    @Published private(set) var isRewardedInterstitialReady = false

    private var hasRequestedConsentInfo = false
    private var hasStartedMobileAds = false
    private var rewardedInterstitialAd: RewardedInterstitialAd?
    private var rewardedInterstitialContinuation: CheckedContinuation<RewardedInterstitialResult, Never>?
    private var isLoadingRewardedInterstitial = false
    private var didEarnReward = false

    var shouldOfferRewardedInterstitial: Bool {
        canRequestAds && !hasEarnedRewardedInterstitialToday
    }

    func prepareIfNeeded() async {
        guard !hasRequestedConsentInfo else { return }
        hasRequestedConsentInfo = true
        await refreshConsent()
    }

    func prepareRewardedInterstitialIfNeeded() async {
        await loadRewardedInterstitialIfNeeded()
    }

    func presentPrivacyOptionsForm() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            log(error, prefix: "Failed to present privacy options form")
        }

        updateConsentState()
        startGoogleMobileAdsIfNeeded()
        await loadRewardedInterstitialIfNeeded()
    }

    func presentRewardedInterstitial() async -> RewardedInterstitialResult {
        guard shouldOfferRewardedInterstitial else {
            return .unavailable
        }

        if rewardedInterstitialAd == nil {
            await loadRewardedInterstitialIfNeeded()
        }

        guard let rewardedInterstitialAd else {
            return .unavailable
        }

        didEarnReward = false
        isRewardedInterstitialReady = false

        return await withCheckedContinuation { continuation in
            rewardedInterstitialContinuation = continuation
            rewardedInterstitialAd.present(from: nil) { [weak self, weak rewardedInterstitialAd] in
                guard let self else { return }
                self.didEarnReward = true

                if let reward = rewardedInterstitialAd?.adReward {
                    print("[AdsConsentManager] Reward earned: \(reward.type) \(reward.amount)")
                }
            }
        }
    }

    private func refreshConsent() async {
        do {
            try await requestConsentInfoUpdate()
            updateConsentState()
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            log(error, prefix: "Failed to refresh consent information")
        }

        updateConsentState()
        startGoogleMobileAdsIfNeeded()
        await loadRewardedInterstitialIfNeeded()
    }

    private func loadRewardedInterstitialIfNeeded(force: Bool = false) async {
        guard shouldOfferRewardedInterstitial,
              let adUnitID = AdMobConfiguration.rewardedInterstitialAdUnitID else {
            rewardedInterstitialAd = nil
            isRewardedInterstitialReady = false
            return
        }

        guard force || rewardedInterstitialAd == nil else {
            isRewardedInterstitialReady = true
            return
        }

        guard !isLoadingRewardedInterstitial else { return }

        isLoadingRewardedInterstitial = true
        defer { isLoadingRewardedInterstitial = false }

        do {
            let rewardedInterstitialAd = try await RewardedInterstitialAd.load(
                with: adUnitID,
                request: Request()
            )
            rewardedInterstitialAd.fullScreenContentDelegate = self
            self.rewardedInterstitialAd = rewardedInterstitialAd
            isRewardedInterstitialReady = true
        } catch {
            rewardedInterstitialAd = nil
            isRewardedInterstitialReady = false
            log(error, prefix: "Failed to load rewarded interstitial")
        }
    }

    private func requestConsentInfoUpdate() async throws {
        let parameters = RequestParameters()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func updateConsentState() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        isPrivacyOptionsRequired =
            ConsentInformation.shared.privacyOptionsRequirementStatus == .required

        if !canRequestAds {
            rewardedInterstitialAd = nil
            isRewardedInterstitialReady = false
        }
    }

    private func startGoogleMobileAdsIfNeeded() {
        guard canRequestAds, !hasStartedMobileAds else { return }

        hasStartedMobileAds = true
        MobileAds.shared.start()
    }

    private var hasEarnedRewardedInterstitialToday: Bool {
        guard
            let lastRewardDate = UserDefaults.standard.object(
                forKey: Self.rewardedInterstitialLastRewardDateKey
            ) as? Date
        else {
            return false
        }

        return Calendar.autoupdatingCurrent.isDate(lastRewardDate, inSameDayAs: Date())
    }

    private func recordRewardedInterstitialReward() {
        UserDefaults.standard.set(Date(), forKey: Self.rewardedInterstitialLastRewardDateKey)
    }

    private func finishRewardedInterstitialPresentation(with result: RewardedInterstitialResult) {
        rewardedInterstitialContinuation?.resume(returning: result)
        rewardedInterstitialContinuation = nil
    }

    private func log(_ error: Error, prefix: String) {
        print("[AdsConsentManager] \(prefix): \(error.localizedDescription)")
    }
}

extension AdsConsentManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardedInterstitialAd = nil

        if didEarnReward {
            recordRewardedInterstitialReward()
        }

        finishRewardedInterstitialPresentation(with: didEarnReward ? .rewarded : .skipped)

        Task { [weak self] in
            await self?.loadRewardedInterstitialIfNeeded(force: true)
        }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        log(error, prefix: "Rewarded interstitial failed to present")
        rewardedInterstitialAd = nil
        isRewardedInterstitialReady = false
        finishRewardedInterstitialPresentation(with: .failed)

        Task { [weak self] in
            await self?.loadRewardedInterstitialIfNeeded(force: true)
        }
    }
}
