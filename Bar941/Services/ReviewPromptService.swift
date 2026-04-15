import Foundation

protocol ReviewPromptServiceProtocol {
    @discardableResult
    func registerSuccessfulSave() -> Bool
}

final class ReviewPromptService: ReviewPromptServiceProtocol {
    private enum Keys {
        static let installedAt = "ReviewPromptService.installedAt"
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

        registerInstallIfNeeded()
    }

    @discardableResult
    func registerSuccessfulSave() -> Bool {
        registerInstallIfNeeded()

        let successfulSaveCount = userDefaults.integer(forKey: Keys.successfulSaveCount) + 1
        userDefaults.set(successfulSaveCount, forKey: Keys.successfulSaveCount)

        guard successfulSaveCount >= 3 else { return false }
        guard isAtLeastSecondDaySinceInstall else { return false }
        guard hasCooldownElapsed else { return false }
        guard hasNotPromptedForCurrentVersion else { return false }

        userDefaults.set(now(), forKey: Keys.lastPromptAt)
        userDefaults.set(currentMarketingVersion, forKey: Keys.lastPromptedVersion)
        return true
    }

    @discardableResult
    private func registerInstallIfNeeded() -> Date {
        if let installedAt = userDefaults.object(forKey: Keys.installedAt) as? Date {
            return installedAt
        }

        let installedAt = now()
        userDefaults.set(installedAt, forKey: Keys.installedAt)
        return installedAt
    }

    private var isAtLeastSecondDaySinceInstall: Bool {
        guard let installedAt = userDefaults.object(forKey: Keys.installedAt) as? Date else {
            return false
        }

        let installDay = calendar.startOfDay(for: installedAt)
        let today = calendar.startOfDay(for: now())
        let daysSinceInstall = calendar.dateComponents([.day], from: installDay, to: today).day ?? 0
        return daysSinceInstall >= 1
    }

    private var hasCooldownElapsed: Bool {
        guard let lastPromptAt = userDefaults.object(forKey: Keys.lastPromptAt) as? Date else {
            return true
        }

        let daysSinceLastPrompt =
            calendar.dateComponents([.day], from: lastPromptAt, to: now()).day ?? 0
        return daysSinceLastPrompt >= 90
    }

    private var hasNotPromptedForCurrentVersion: Bool {
        userDefaults.string(forKey: Keys.lastPromptedVersion) != currentMarketingVersion
    }

    private var currentMarketingVersion: String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }
}
