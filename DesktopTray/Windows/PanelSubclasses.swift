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
