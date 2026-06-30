import SwiftUI

/// 左端に表示する収納トレイの縦タブ列（Fix G）。
/// 小さなガラス pill で各トレイを表し、下部に新規作成・管理画面への導線を置く。
struct TabRailView: View {
    let tabs: [TabRailEntry]
    let onExpand: (UUID) -> Void
    let onNewTray: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: TrayTheme.tabSpacing) {
            ForEach(tabs) { tab in
                TabRailTabView(tab: tab) {
                    onExpand(tab.id)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button(action: onNewTray) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("tray.new", comment: ""))

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("tray.management.title", comment: ""))
            }
            .foregroundStyle(.secondary)
        }
        .padding(.top, TrayTheme.tabRailTopPadding)
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
        .frame(width: TrayTheme.collapsedTabWidth + 8)
    }
}

struct TabRailEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
    let color: TrayColor
    let itemCount: Int
    let isSmart: Bool

    var shortLabel: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map(String.init) ?? "?"
    }
}

private struct TabRailTabView: View {
    let tab: TabRailEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(tab.shortLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(tab.itemCount)")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                if tab.isSmart {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8))
                        .foregroundStyle(.purple)
                }
            }
            .frame(width: TrayTheme.collapsedTabWidth, height: TrayTheme.collapsedTabHeight)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(tab.color.swiftUIColor.opacity(0.7))
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(tab.name) \(NSLocalizedString("tray.collapse", comment: ""))"))
        .accessibilityHint(Text(NSLocalizedString("tray.expand", comment: "")))
    }
}
