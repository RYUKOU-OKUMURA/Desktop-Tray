import AppKit

/// トレイ表示用のカスタム `NSPanel`。
/// `.nonactivatingPanel` + `.borderless` でデスクトップ上にフローティングする半透明パネルを実現する
/// （技術スタック v0.1 §6.2）。
final class TrayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    /// `nonactivatingPanel` でもドラッグ可能にするため、背景ドラッグを許可。
    override var isMovableByWindowBackground: Bool {
        get { true }
        set { /* 固定 */ }
    }
}

/// 左端 TabRail 用の固定パネル（Fix G）。
final class TabRailPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override var isMovableByWindowBackground: Bool {
        get { false }
        set { /* 固定 */ }
    }
}
