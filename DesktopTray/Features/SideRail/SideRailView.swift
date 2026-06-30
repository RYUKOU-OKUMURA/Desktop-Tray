import SwiftUI

/// 左レール（要件定義 §15.2）。
/// 新規トレイ作成ボタン + 収納タブ一覧 + 歯車メニュー（すべて展開 / すべて収納 / 終了）。
/// 画面左端に固定表示される縦長のレール。
struct SideRailView: View {
    let collapsedTrays: [Tray]
    let onNewTray: () -> Void
    let onTabTap: (Tray) -> Void
    let onExpandAll: () -> Void
    let onCollapseAll: () -> Void
    let onQuit: () -> Void

    @State private var showMenu: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            newTrayButton

            Divider()
                .background(Color.white.opacity(0.18))
                .padding(.horizontal, 6)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(collapsedTrays) { tray in
                        TrayTabView(tray: tray, onTap: { onTabTap(tray) })
                    }
                }
                .padding(.bottom, 8)
            }

            Spacer()

            gearMenu
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .frame(width: TrayTheme.sideRailWidth)
        .frame(maxHeight: .infinity)
        .glassBackground(cornerRadius: 0, lineWidth: 0, material: .sidebar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("サイドレール"))
    }

    private var newTrayButton: some View {
        Button(action: onNewTray) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.18))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("新規トレイ")
        .accessibilityLabel(Text("新規トレイを追加"))
    }

    private var gearMenu: some View {
        Menu {
            Button("すべて展開", action: onExpandAll)
            Button("すべて収納", action: onCollapseAll)
            Divider()
            Button("Desktop Tray を終了", role: .destructive, action: onQuit)
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(Text("メニュー"))
    }
}
