import AppKit
import SwiftUI

/// `NSVisualEffectView` を SwiftUI に埋め込む Glass 背景コンポーネント。
/// 技術スタック v0.1 §6.1 に従い、`.hudWindow` / `.sidebar` 系のマテリアルをベースに
/// ライト/ダーク両環境で自然なブラーを表現する。
struct GlassBackgroundView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let emphasized: Bool

    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        emphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.emphasized = emphasized
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = emphasized
    }
}

/// SwiftUI 向けの Glass 背景 Modifier。角丸・枠線・影をセットで適用する。
struct GlassBackground: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let material: NSVisualEffectView.Material

    func body(content: Content) -> some View {
        content
            .background(
                GlassBackgroundView(material: material)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                .white.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: lineWidth
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// 半透明 Glass 背景を付与する。
    func glassBackground(
        cornerRadius: CGFloat = TrayTheme.cornerRadius,
        lineWidth: CGFloat = TrayTheme.borderWidth,
        material: NSVisualEffectView.Material = .hudWindow
    ) -> some View {
        modifier(
            GlassBackground(
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                material: material
            )
        )
    }
}
