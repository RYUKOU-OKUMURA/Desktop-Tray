import SwiftUI

/// 左端吸着ガイド（要件定義 §8.1 / §17 必須アニメーション）。
/// トレイドラッグ中に左端 snap 領域に入ったときだけ表示される。
struct SnapGuideOverlay: View {
    let frame: CGRect

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                snapGuide
                Spacer()
            }
            Spacer()
        }
        .frame(width: frame.width, height: frame.height)
        .transition(.opacity.combined(with: .move(edge: .leading)))
        .animation(Animations.snapGuide, value: frame)
        .allowsHitTesting(false)
    }

    private var snapGuide: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 2
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
            .frame(width: 40, height: 220)
            .padding(.leading, 8)
            .accessibilityHidden(true)
    }
}
