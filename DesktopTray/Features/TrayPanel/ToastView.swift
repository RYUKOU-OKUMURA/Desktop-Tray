import SwiftUI

/// 軽いフィードバックトースト（要件定義 §7.2）。
/// 「あとで読むに追加しました」のような一時メッセージを画面下中央に表示する。
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassBackground(cornerRadius: 14, lineWidth: 0.5, material: .hudWindow)
            .transition(
                .opacity
                    .combined(with: .move(edge: .bottom))
                    .combined(with: .scale(scale: 0.95))
            )
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(Text(message))
    }
}

/// トースト出現を管理する修飾子。短時間で自動消去する。
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let duration: TimeInterval

    func body(content: Content) -> some View {
        ZStack {
            content
            if let message {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .padding(.bottom, 32)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .onChange(of: message) { _, newValue in
            guard newValue != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                withAnimation(Animations.itemAppear) {
                    self.message = nil
                }
            }
        }
    }
}

extension View {
    func toast(message: Binding<String?>, duration: TimeInterval = 1.8) -> some View {
        modifier(ToastModifier(message: message, duration: duration))
    }
}
