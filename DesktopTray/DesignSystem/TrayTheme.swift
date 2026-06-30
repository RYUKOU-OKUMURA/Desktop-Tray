import SwiftUI

/// トレイ UI 全体の視覚パラメータを一元管理するテーマ。
/// ライト/ダーク両モードで破綻しないよう、system color を基準に組む（要件定義 §13.3）。
enum TrayTheme {
    // MARK: - Metrics
    static let cornerRadius: CGFloat = 18
    static let borderWidth: CGFloat = 1
    static let trayWidthRange: ClosedRange<CGFloat> = 360...440
    static let trayHeightRange: ClosedRange<CGFloat> = 260...340
    static let itemIconSize: CGFloat = 64
    static let itemSpacing: CGFloat = 12
    static let sideRailWidth: CGFloat = 56
    static let collapsedTabWidth: CGFloat = 32
    static let collapsedTabHeight: CGFloat = 56
    static let tabSpacing: CGFloat = 6
    static let tabRailTopPadding: CGFloat = 16
    static let tabRailFooterHeight: CGFloat = 72
    static let snapThreshold: CGFloat = 20

    // MARK: - Colors
    static let trayAccent = Color.accentColor
    static let headerTitle = Color.primary
    static let headerSubtitle = Color.secondary
    static let staleOverlay = Color.gray.opacity(0.55)

    /// トレイ識別色の候補。MVP では固定パレットを使用（要件定義 §14: 色変更は MVP 以降）。
    static let palette: [TrayColor] = [
        .blue, .purple, .pink, .red, .orange, .yellow, .green, .teal, .indigo, .gray
    ]
}

/// トレイ識別色。JSON 永続化のために文字列ベースで扱う。
enum TrayColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue, purple, pink, red, orange, yellow, green, teal, indigo, gray

    var id: String { rawValue }

    /// system color に対応付ける。ライト/ダーク自動追従。
    var swiftUIColor: Color {
        switch self {
        case .blue:    return .blue
        case .purple:  return .purple
        case .pink:    return .pink
        case .red:     return .red
        case .orange:  return .orange
        case .yellow:  return .yellow
        case .green:   return .green
        case .teal:    return .teal
        case .indigo:  return .indigo
        case .gray:    return .gray
        }
    }

    var nsColor: NSColor {
        switch self {
        case .blue:    return .systemBlue
        case .purple:  return .systemPurple
        case .pink:    return .systemPink
        case .red:     return .systemRed
        case .orange:  return .systemOrange
        case .yellow:  return .systemYellow
        case .green:   return .systemGreen
        case .teal:    return .systemTeal
        case .indigo:  return .systemIndigo
        case .gray:    return .systemGray
        }
    }
}
