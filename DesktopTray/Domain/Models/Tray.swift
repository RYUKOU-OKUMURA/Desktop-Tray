import Foundation

/// トレイ種別。手動 / スマートの2種（要件定義 §5.2）。
enum TrayType: String, Codable, Sendable, CaseIterable {
    case manual
    case smart
}

/// トレイの展開時位置・サイズ。`CGRect` は直接 Codable でないためラップする。
struct TrayFrame: Codable, Sendable, Equatable, Hashable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 0, height: CGFloat = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.width
        self.height = rect.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    /// macOS の NSRect は左下原点。_screenRect は画面座標への変換用。
    var size: CGSize { CGSize(width: width, height: height) }
}

/// トレイのメタデータモデル。ファイル本体は持たない（非破壊の担保）。
/// アーキテクチャ v0.1 §3.4 / §5.2 参照。
struct Tray: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var type: TrayType
    var color: TrayColor
    var frame: TrayFrame
    var isCollapsed: Bool
    var tabIndex: Int
    /// 手動トレイのみ。スマートトレイは空配列。
    var items: [TrayItem]
    /// スマートトレイのみ。手動トレイは nil。
    var rule: SmartTrayRule?

    init(
        id: UUID = UUID(),
        name: String,
        type: TrayType,
        color: TrayColor = .blue,
        frame: TrayFrame = TrayFrame(width: 400, height: 300),
        isCollapsed: Bool = false,
        tabIndex: Int = 0,
        items: [TrayItem] = [],
        rule: SmartTrayRule? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.color = color
        self.frame = frame
        self.isCollapsed = isCollapsed
        self.tabIndex = tabIndex
        self.items = items
        self.rule = rule
    }

    var isSmart: Bool { type == .smart }
}
