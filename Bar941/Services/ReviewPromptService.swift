import Foundation

protocol ReviewPromptServiceProtocol {
    @discardableResult
    func registerSuccessfulSave() -> Bool
}

final class ReviewPromptService: ReviewPromptServiceProtocol {
    private enum Keys {
        static let successfulSaveCount = "ReviewPromptService.successfulSaveCount"
        static let lastPromptAt = "ReviewPromptService.lastPromptAt"
        static let lastPromptedVersion = "ReviewPromptService.lastPromptedVersion"
    }

    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private let bundle: Bundle

    init(
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init,
        bundle: Bundle = .main
    ) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.now = now
        self.bundle = bundle
    }

    @discardableResult
    func registerSuccessfulSave() -> Bool {
        let successfulSaveCount = userDefaults.integer(forKey: Keys.successfulSaveCount) + 1
        userDefaults.set(successfulSaveCount, forKey: Keys.successfulSaveCount)

        guard successfulSaveCount >= 3 else { return false }
        guard hasCooldownElapsed else { return false }
        guard hasNotPromptedForCurrentVersion else { return false }

        userDefaults.set(now(), forKey: Keys.lastPromptAt)
        userDefaults.set(currentMarketingVersion, forKey: Keys.lastPromptedVersion)
        return true
    }

    private var hasCooldownElapsed: Bool {
        guard let lastPromptAt = userDefaults.object(forKey: Keys.lastPromptAt) as? Date else {
            return true
        }

        let daysSinceLastPrompt =
            calendar.dateComponents([.day], from: lastPromptAt, to: now()).day ?? 0
        return daysSinceLastPrompt >= 30
    }

    private var hasNotPromptedForCurrentVersion: Bool {
        userDefaults.string(forKey: Keys.lastPromptedVersion) != currentMarketingVersion
    }

    private var currentMarketingVersion: String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }
}
