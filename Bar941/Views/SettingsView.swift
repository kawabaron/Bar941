import SwiftUI

private enum SettingsLink: String, CaseIterable, Identifiable {
    case terms
    case privacy
    case contact

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .terms:
            return "settings.links.terms"
        case .privacy:
            return "settings.links.privacy"
        case .contact:
            return "settings.links.contact"
        }
    }

    var systemImage: String {
        switch self {
        case .terms:
            return "doc.text"
        case .privacy:
            return "hand.raised"
        case .contact:
            return "envelope"
        }
    }

    var url: URL {
        switch self {
        case .terms:
            return URL(string: "https://kawabaron.github.io/Bar941/terms.html")!
        case .privacy:
            return URL(string: "https://kawabaron.github.io/Bar941/privacy.html")!
        case .contact:
            return URL(string: "https://kawabaron.github.io/Bar941/contact.html")!
        }
    }
}

struct SettingsView: View {
    @Environment(\.locale) private var locale
    @AppStorage(AppLanguage.storageKey) private var selectedLanguageCode = AppLanguage.system.rawValue

    var body: some View {
        Form {
            languageSection
            linksSection
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var languageSection: some View {
        Section("settings.language.section") {
            Picker("settings.language.label", selection: $selectedLanguageCode) {
                ForEach(AppLanguage.allCases) { language in
                    Text(displayName(for: language)).tag(language.rawValue)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var linksSection: some View {
        Section("settings.links.section") {
            ForEach(SettingsLink.allCases) { item in
                Link(destination: item.url) {
                    HStack(spacing: 12) {
                        Label {
                            Text(item.titleKey)
                        } icon: {
                            Image(systemName: item.systemImage)
                        }
                        .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func displayName(for language: AppLanguage) -> String {
        switch language {
        case .system:
            return AppLocalizer.string("settings.language.system", languageCode: selectedLanguageCode)
        default:
            return locale.localizedString(forIdentifier: language.rawValue)
                ?? AppLocalizer.locale(for: selectedLanguageCode).localizedString(forIdentifier: language.rawValue)
                ?? language.rawValue
        }
    }
}
