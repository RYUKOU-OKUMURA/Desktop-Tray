import SwiftUI

/// 左端収納タブ（要件定義 §6.2 収納状態 / §8.1）。
/// トレイ色・短縮名・件数小表示を持つ縦長タブ。
struct TrayTabView: View {
    let tray: Tray
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Circle()
                    .fill(tray.color.swiftUIColor)
                    .frame(width: 10, height: 10)
                Text(shortLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(tray.items.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if tray.isSmart {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .frame(width: TrayTheme.collapsedTabWidth - 4, height: 92)
        .glassBackground(
            cornerRadius: 12,
            lineWidth: 1,
            material: .sidebar
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(tray.name) 収納タブ"))
        .accessibilityHint(Text("クリックで展開"))
    }

    /// トレイ名の先頭1文字（ひらがな・カナ・英字どちらでも1文字）。
    private var shortLabel: String {
        let trimmed = tray.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first)
    }
}
