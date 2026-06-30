import SwiftUI

/// アニメーション要件（要件定義 §17）を集約する。
/// `accessibilityDisplayShouldReduceMotion` を見て spring を短縮/無効化する（技術スタック v0.1 §6.3）。
enum Animations {
    /// Reduce Motion が有効か。UI スレッドから参照する。
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// 収納/展開用 spring。Reduce Motion 時は素早い linear に切り替える。
    static var collapse: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.34, dampingFraction: 0.78)
    }

    /// タブ → 展開の spring。少し弾性を持たせる。
    static var expand: Animation {
        reduceMotion
            ? .easeOut(duration: 0.14)
            : .spring(response: 0.42, dampingFraction: 0.72)
    }

    /// アイテム追加時のフェード。
    static var itemAppear: Animation {
        reduceMotion
            ? .easeOut(duration: 0.1)
            : .easeInOut(duration: 0.18)
    }

    /// ホバー浮き。
    static var hover: Animation {
        reduceMotion
            ? .easeOut(duration: 0.08)
            : .spring(response: 0.22, dampingFraction: 0.82)
    }

    /// ドラッグ追従用（即時追随しつつ慣性で揺らさない）。
    static var drag: Animation {
        reduceMotion
            ? .easeOut(duration: 0.06)
            : .interactiveSpring(response: 0.18, dampingFraction: 0.9)
    }

    /// 吸着ガイドのフェード。
    static var snapGuide: Animation {
        .easeInOut(duration: 0.16)
    }
}
