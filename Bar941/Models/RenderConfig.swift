import CoreGraphics

struct RenderConfig {
    let screenType: ScreenType
    let canvasSize: CGSize
    let statusBarHeight: CGFloat
    let topPadding: CGFloat
    let style: StatusBarStyle
}
