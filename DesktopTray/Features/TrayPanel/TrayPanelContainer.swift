import SwiftUI

/// `TrayPanelView` と `TrayPanelViewModel` を結合するコンテナ。
/// `@Observable` ViewModel の binding を View へ安全に渡すための中間層。
/// AppCoordinator が生成し、`OverlayWindowManager` のコンテンツとして表示する。
struct TrayPanelContainer: View {
    let tray: Tray
    @Bindable var viewModel: TrayPanelViewModel
    /// `TrayItem` 群（URL 復元用）。Presentation には URL を持たせないため、
    /// ダブルクリック / Finder 表示 / トレイから外す / D&D 移動 のアクションで id 経由で引き当てる。
    let sourceItems: [TrayItem]
    let onCollapse: () -> Void
    let onUnassign: (TrayItemPresentation) -> Void
    let onFileDrop: ([URL]) -> Void

    var body: some View {
        TrayPanelView(
            tray: tray,
            trayID: tray.id,
            items: viewModel.presentations,
            iconProvider: { presentation in
                viewModel.icon(for: presentation)
            },
            onItemDoubleClick: { presentation in
                if let item = sourceItems.first(where: { $0.id == presentation.id }) {
                    viewModel.open(url: item.url)
                }
            },
            onItemReveal: { presentation in
                if let item = sourceItems.first(where: { $0.id == presentation.id }) {
                    viewModel.reveal(url: item.url)
                }
            },
            onItemUnassign: onUnassign,
            onCollapse: onCollapse,
            toastMessage: $viewModel.toastMessage
        )
        .overlay {
            FileDropRepresentable(
                onDrop: onFileDrop,
                isActive: true
            )
        }
    }
}
