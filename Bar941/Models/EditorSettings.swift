import Foundation

struct EditorSettings: Equatable {
    var barStyle: StatusBarStyle = .auto
    var layoutAdjustments: StatusBarLayoutAdjustments = .init()
}

struct StatusBarLayoutAdjustments: Equatable {
    var time: StatusBarElementAdjustment
    var statusIcons: StatusBarElementAdjustment

    init(
        time: StatusBarElementAdjustment = .init(),
        statusIcons: StatusBarElementAdjustment = .init()
    ) {
        self.time = time
        self.statusIcons = statusIcons
    }
}

struct StatusBarElementAdjustment: Equatable {
    var xOffset: CGFloat
    var yOffset: CGFloat
    var scale: CGFloat

    init(
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0,
        scale: CGFloat = 1
    ) {
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.scale = scale
    }
}
