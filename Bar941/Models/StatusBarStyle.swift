import Foundation

enum StatusBarStyle: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}
