import SwiftUI

/// トレイ本体のビュー（要件定義 §5.4 / §6.2 / §16）。
/// ヘッダー（タイトル + 件数バッジ + Smart バッジ + 収納ボタン）+ アイコングリッド。
/// Phase 2 で ViewModel 由来の実データと D&D / 右クリックを統合。
struct TrayPanelView: View {
    let tray: Tray
    let items: [TrayItemPresentation]
    let iconProvider: (TrayItemPresentation) -> NSImage?
    let onItemDoubleClick: (TrayItemPresentation) -> Void
    let onItemReveal: (TrayItemPresentation) -> Void
    let onItemUnassign: (TrayItemPresentation) -> Void
    let onCollapse: () -> Void
    @Binding var toastMessage: String?

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
            }
        }
        .frame(
            width: max(TrayTheme.trayWidthRange.lowerBound, 360),
            height: max(TrayTheme.trayHeightRange.lowerBound, 260)
        )
        .glassBackground(cornerRadius: TrayTheme.cornerRadius, material: .hudWindow)
        .toast(message: $toastMessage)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(tray.name))
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
