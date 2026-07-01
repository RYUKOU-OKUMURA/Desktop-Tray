import SwiftUI

/// トレイ本体のビュー（要件定義 §5.4 / §6.2 / §16）。
/// ガラス背景は `TrayWindowController` 側の `NSVisualEffectView` (contentView) が提供する。
/// 収納 UI は TabRail が担うため、本 View は展開パネルのみ描画する（Fix G）。
struct TrayPanelView: View {
    /// アイテム矩形をトラッキングするための座標空間名。`TrayItemView` の GeometryReader が参照する。
    static let itemCoordinateSpace = "TrayPanelView.items"

    let tray: Tray
    let trayID: UUID
    let items: [TrayItemPresentation]
    let iconProvider: (TrayItemPresentation) -> NSImage?
    let onItemDoubleClick: (TrayItemPresentation) -> Void
    let onItemReveal: (TrayItemPresentation) -> Void
    let onItemUnassign: (TrayItemPresentation) -> Void
    let onCollapse: () -> Void
    let onReorder: (UUID, Int) -> Void
    let onMoveFromOtherTray: (UUID, UUID) -> Void
    @Binding var toastMessage: String?

    @Environment(\.itemFrameTracker) private var itemFrameTracker

    var body: some View {
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
        .coordinateSpace(name: Self.itemCoordinateSpace)
        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
            itemFrameTracker.itemFrames = frames
        }
        .toast(message: $toastMessage)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(tray.name))
    }

    private func handleDrop(transfers: [TrayItemTransfer], location: CGPoint) -> Bool {
        guard let transfer = transfers.first else { return false }
        if transfer.sourceTrayID == trayID {
            let index = nearestIndex(for: location, itemCount: items.count)
            onReorder(transfer.itemID, index)
        } else {
            onMoveFromOtherTray(transfer.itemID, transfer.sourceTrayID)
        }
        return true
    }

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
            .help(NSLocalizedString("tray.collapse", comment: ""))
            .accessibilityLabel(Text(NSLocalizedString("tray.collapse", comment: "")))
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
