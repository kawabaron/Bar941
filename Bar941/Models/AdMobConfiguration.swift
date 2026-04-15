import Foundation

enum AdMobConfiguration {
    static let bannerAdUnitInfoKey = "Bar941BannerAdUnitID"
    static let rewardedInterstitialAdUnitInfoKey = "Bar941RewardedInterstitialAdUnitID"
    static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let testRewardedInterstitialAdUnitID = "ca-app-pub-3940256099942544/6978759866"

    static var appID: String {
        infoString(for: "GADApplicationIdentifier") ?? testAppID
    }

    static var bannerAdUnitID: String? {
        guard let adUnitID = infoString(for: bannerAdUnitInfoKey) else {
            return testBannerAdUnitID
        }

        return validatedAdUnitID(adUnitID)
    }

    static var rewardedInterstitialAdUnitID: String? {
        guard let adUnitID = infoString(for: rewardedInterstitialAdUnitInfoKey) else {
            return testRewardedInterstitialAdUnitID
        }

        return validatedAdUnitID(adUnitID)
    }

    private static func validatedAdUnitID(_ adUnitID: String) -> String? {
        guard adUnitID.hasPrefix("ca-app-pub-") else {
            return nil
        }

        return adUnitID
    }

    private static func infoString(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
