import Foundation
import SwiftUI

enum StatusBarStyle: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .auto:
            return "statusBarStyle.auto"
        case .light:
            return "statusBarStyle.light"
        case .dark:
            return "statusBarStyle.dark"
        }
    }
}
