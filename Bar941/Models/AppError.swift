import Foundation

enum AppError: Error {
    case invalidImageData
    case unsupportedImageSize
    case renderFailed
    case photoAccessDenied
    case photoSaveFailed

    var localizationKey: String {
        switch self {
        case .invalidImageData:
            return "error.invalidImageData"
        case .unsupportedImageSize:
            return "error.unsupportedImageSize"
        case .renderFailed:
            return "error.renderFailed"
        case .photoAccessDenied:
            return "error.photoAccessDenied"
        case .photoSaveFailed:
            return "error.photoSaveFailed"
        }
    }
}
