import SwiftUI

/// 単一ファイル/フォルダ表示（要件定義 §16）。
/// ホバーで軽く浮く、ファイル名は2行までで省略、stale は灰色オーバーレイ。
/// 右クリックメニュー: 開く / Finder で表示 / トレイから外す（要件定義 §7.6）。
/// ドラッグで他トレイへ移動・同一トレイ内で並び替えができる（Fix F）。
struct TrayItemView: View {
    let presentation: TrayItemPresentation
    let icon: NSImage?
    let trayID: UUID
    let onDoubleClick: () -> Void
    let onReveal: () -> Void
    let onUnassign: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            iconView
                .frame(width: TrayTheme.itemIconSize, height: TrayTheme.itemIconSize)
                .scaleEffect(isHovered ? 1.03 : 1.0)
                .shadow(
                    color: .black.opacity(isHovered ? 0.22 : 0.08),
                    radius: isHovered ? 6 : 2,
                    x: 0,
                    y: isHovered ? 3 : 1
                )
                .animation(Animations.hover, value: isHovered)

            Text(presentation.displayName)
                .font(.caption)
                .foregroundStyle(presentation.stale ? TrayTheme.staleOverlay : .primary)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(8)
        .opacity(presentation.stale ? 0.55 : 1.0)
        .overlay(alignment: .topTrailing) {
            if presentation.stale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(4)
            }
        }
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: onDoubleClick)
        .draggable(TrayItemTransfer(itemID: presentation.id, sourceTrayID: trayID))
        .contextMenu {
            Button {
                onDoubleClick()
            } label: {
                Label(NSLocalizedString("item.open", comment: ""), systemImage: "arrow.up.forward.app")
            }
            Button {
                onReveal()
            } label: {
                Label(NSLocalizedString("item.reveal", comment: ""), systemImage: "magnifyingglass")
            }
            Divider()
            Button(role: .destructive) {
                onUnassign()
            } label: {
                Label(NSLocalizedString("item.unassign", comment: ""), systemImage: "minus.circle")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(presentation.displayName))
        .accessibilityHint(Text("ダブルクリックで開く、ドラッグで移動"))
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.25))
                .overlay(
                    Image(systemName: presentation.isDirectory ? "folder" : "doc")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                )
        }
    }
}
