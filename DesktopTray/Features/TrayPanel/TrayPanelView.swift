import SwiftUI

/// トレイ本体のビュー（要件定義 §5.4 / §6.2 / §16）。
/// ガラス背景は `TrayWindowController` 側の `NSVisualEffectView` (contentView) が提供するため、
/// SwiftUI 側は背景透明のコンテンツのみ描画する（Fix A）。
///
/// 収納状態（Fix D）: パネルは左端画面外へスライドし、左端 40px だけ覗く。
/// SwiftUI は収納中 `collapsedTab` を描画し、全面タップで `onExpand` を発火する。
///
/// アイテム D&D（Fix F）: 展開中のグリッドが `dropDestination` となり、
/// 同一トレイ内なら並び替え、別トレイからなら移動を受ける。
struct TrayPanelView: View {
    let tray: Tray
    let trayID: UUID
    let items: [TrayItemPresentation]
    let iconProvider: (TrayItemPresentation) -> NSImage?
    let onItemDoubleClick: (TrayItemPresentation) -> Void
    let onItemReveal: (TrayItemPresentation) -> Void
    let onItemUnassign: (TrayItemPresentation) -> Void
    let onCollapse: () -> Void
    let onExpand: () -> Void
    let onReorder: (UUID, Int) -> Void
    let onMoveFromOtherTray: (UUID, UUID) -> Void
    @Binding var toastMessage: String?

    var body: some View {
        if tray.isCollapsed {
            collapsedTab
        } else {
            expandedPanel
        }
    }

    // MARK: - Collapsed (左端タブ)

    private var collapsedTab: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Circle()
                    .fill(tray.color.swiftUIColor)
                    .frame(width: 10, height: 10)
                Text(shortLabel)
                    .font(.headline)
                    .frame(width: 28)
                    .lineLimit(1)
                Text("\(items.count)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if tray.isSmart {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            }
            .frame(width: TrayTheme.collapsedTabWidth, height: 92)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { onExpand() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(tray.name) 収納タブ"))
        .accessibilityHint(Text("クリックで展開"))
    }

    private var shortLabel: String {
        let trimmed = tray.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map(String.init) ?? "?"
    }

    // MARK: - Expanded

    private var expandedPanel: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                LazyVGrid(
                    columns: gridColumns,
                    spacing: TrayTheme.itemSpacing
                ) {
                    ForEach(items) { item in
                        TrayItemView(
                            presentation: item,
                            icon: iconProvider(item),
                            trayID: trayID,
                            onDoubleClick: { onItemDoubleClick(item) },
                            onReveal: { onItemReveal(item) },
                            onUnassign: { onItemUnassign(item) }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .animation(Animations.itemAppear, value: items.count)
                .dropDestination(for: TrayItemTransfer.self) { transfers, location in
                    handleDrop(transfers: transfers, location: location)
                }
            }
        }
        .frame(
            width: max(TrayTheme.trayWidthRange.lowerBound, 360),
            height: max(TrayTheme.trayHeightRange.lowerBound, 260)
        )
        .toast(message: $toastMessage)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(tray.name))
    }

    private func handleDrop(transfers: [TrayItemTransfer], location: CGPoint) -> Bool {
        guard let transfer = transfers.first else { return false }
        if transfer.sourceTrayID == trayID {
            // 同一トレイ内 → 並び替え
            let index = nearestIndex(for: location, itemCount: items.count)
            onReorder(transfer.itemID, index)
        } else {
            // 別トレイ → 移動
            onMoveFromOtherTray(transfer.itemID, transfer.sourceTrayID)
        }
        return true
    }

    /// ドロップ位置から最寄りのグリッドインデックスを概算する。
    /// 4列グリッドを前提とし、セル高さは経験値で約100px。
    private func nearestIndex(for location: CGPoint, itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        let columns = gridColumns.count
        let estimatedRowHeight: CGFloat = 100
        let estimatedCellWidth: CGFloat = 90
        let row = max(0, Int(location.y / estimatedRowHeight))
        let col = min(columns - 1, max(0, Int(location.x / estimatedCellWidth)))
        let index = min(itemCount, row * columns + col)
        return max(0, index)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tray.color.swiftUIColor)
                .frame(width: 8, height: 8)

            Text(tray.name)
                .font(.headline)
                .foregroundStyle(TrayTheme.headerTitle)
                .lineLimit(1)

            if tray.isSmart {
                SmartBadge()
            }

            Spacer()

            countBadge

            Button(action: onCollapse) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("収納")
            .accessibilityLabel(Text("収納"))
        }
    }

    private var countBadge: some View {
        Text("\(items.count)")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(TrayTheme.headerSubtitle)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.14))
            .clipShape(Capsule())
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: TrayTheme.itemSpacing),
            count: 4
        )
    }
}

/// Smart トレイ識別バッジ（要件定義 §9.3）。
struct SmartBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .semibold))
            Text("Smart")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.purple)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(Color.purple.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityLabel(Text("スマートトレイ"))
    }
}
