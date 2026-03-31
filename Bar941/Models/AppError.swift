import Foundation

enum AppError: LocalizedError {
    case invalidImageData
    case unsupportedImageSize
    case renderFailed
    case photoAccessDenied
    case photoSaveFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "画像を読み込めませんでした"
        case .unsupportedImageSize:
            return "この画像サイズは現在サポート対象外です"
        case .renderFailed:
            return "画像の加工に失敗しました"
        case .photoAccessDenied:
            return "写真ライブラリへのアクセスが許可されていません"
        case .photoSaveFailed:
            return "写真ライブラリへの保存に失敗しました"
        }
    }
}
