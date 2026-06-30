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

/// 左レール用のカスタム `NSPanel`。画面左端に固定表示する。
final class SideRailPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 収納タブ表示用の小型パネル。
final class TrayTabPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
