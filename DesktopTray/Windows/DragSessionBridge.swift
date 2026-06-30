import AppKit
import SwiftUI

/// ドラッグ中の状態を View 層へ伝えるブリッジ（アーキテクチャ v0.1 §3.2）。
/// - トレイドラッグ中の snap 判定（LayoutEngine 連携）
/// - Finder からの外部 D&D 受け取り（Phase 2 で FileDropDelegate と統合）
@MainActor
final class DragSessionBridge: ObservableObject {
    @Published var isSnapArmed: Bool = false
    @Published var isDraggingTray: Bool = false
    @Published var snapGuideFrame: CGRect?

    private let layoutEngine: LayoutEngine

    init(layoutEngine: LayoutEngine = LayoutEngine()) {
        self.layoutEngine = layoutEngine
    }

    /// トレイドラッグ開始。
    func beginTrayDrag() {
        isDraggingTray = true
        isSnapArmed = false
    }

    /// トレイドラッグ中の frame 更新。左端 snap 領域に入ったら snap arm を ON。
    func updateTrayDrag(frame: CGRect) {
        guard isDraggingTray else { return }
        let shouldSnap = layoutEngine.shouldSnap(frame: frame)
        if shouldSnap != isSnapArmed {
            isSnapArmed = shouldSnap
            if shouldSnap {
                let visible = LayoutEngine.combinedVisibleFrame()
                snapGuideFrame = CGRect(
                    x: visible.minX + layoutEngine.sideRailWidth,
                    y: visible.minY,
                    width: layoutEngine.collapsedTabWidth,
                    height: visible.height
                )
            } else {
                snapGuideFrame = nil
            }
        }
    }

    /// トレイドラッグ終了。snap が arm されていれば収納確定を返す。
    @discardableResult
    func endTrayDrag() -> Bool {
        let didSnap = isSnapArmed
        isDraggingTray = false
        isSnapArmed = false
        snapGuideFrame = nil
        return didSnap
    }
}

/// Finder からのファイルドロップを受け取る NSView サブクラス。
/// `NSDraggingDestination` を実装し、ドロップされた file URL をコールバックで返す。
/// `hitTest` で nil を返すことでマウスクリックを透過し、下層の SwiftUI ボタン等を
/// ブロックしない。ドラッグ操作は hitTest と独立して機能するためファイルドロップは維持される。
@MainActor
final class FileDropView: NSView {
    var onDropURLs: (([URL]) -> Void)?
    var highlightOnDrag: Bool = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    /// マウスクリックは透過する。ドラッグ受け取りは registerForDraggedTypes で独立処理される。
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        highlightOnDrag = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        highlightOnDrag = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        let fileURLs = urls.filter { ($0 as NSURL).isFileURL }
        guard !fileURLs.isEmpty else { return false }
        onDropURLs?(fileURLs)
        highlightOnDrag = false
        return true
    }
}

/// SwiftUI から `FileDropView` を扱うためのラッパー。
struct FileDropRepresentable: NSViewRepresentable {
    let onDrop: ([URL]) -> Void
    let isActive: Bool

    func makeNSView(context: Context) -> FileDropView {
        let view = FileDropView()
        view.onDropURLs = { urls in
            DispatchQueue.main.async {
                onDrop(urls)
            }
        }
        return view
    }

    func updateNSView(_ nsView: FileDropView, context: Context) {
        nsView.onDropURLs = { urls in
            DispatchQueue.main.async {
                onDrop(urls)
            }
        }
    }
}
