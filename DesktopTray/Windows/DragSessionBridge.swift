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

extension NSPasteboard.PasteboardType {
    /// トレイアイテムのドラッグ&ドロップ専用のペーストボード型（アプリ内限定）。
    static let trayItem = NSPasteboard.PasteboardType("com.desktoptray.tray-item")
}

/// トレイアイテムのアプリ内ドラッグ状態を保持する（不具合修正: トレイ間移動）。
/// 各トレイは別ウィンドウ（`NSPanel`）のため、SwiftUI の `.draggable`/`.dropDestination` は
/// 別ウィンドウ発のドラッグを確実に受け取れない（クロスウィンドウD&Dの信頼性問題）。
/// 全トレイが同一プロセスであることを利用し、ペイロードをペーストボードでシリアライズせず
/// このコーディネータで直接受け渡す（`IconProvider.shared` 等と同じ単純なシングルトン方式）。
/// ペーストボードには型登録のみ行い、ドラッグを認識させる（実データは持たせない）。
@MainActor
final class TrayItemDragCoordinator {
    static let shared = TrayItemDragCoordinator()

    private(set) var current: TrayItemTransfer?

    private init() {}

    func begin(_ transfer: TrayItemTransfer) {
        current = transfer
    }

    func clear() {
        current = nil
    }
}

/// 別トレイ（別ウィンドウ）からドラッグされたアイテムを受け取る NSView サブクラス。
/// `FileDropView` と同じ構造（`NSDraggingDestination` + hitTest 透過）を踏襲することで、
/// SwiftUI のクロスウィンドウ D&D の不確実性を回避する（不具合修正: トレイ間移動）。
/// ペイロードは `TrayItemDragCoordinator` から読む。
@MainActor
final class TrayItemDropView: NSView {
    var trayID: UUID = UUID()
    var itemFrameTracker: ItemFrameTracker?
    /// 同一トレイ内での並び替えが確定したとき呼ばれる（itemID, newIndex）。
    var onReorder: ((UUID, Int) -> Void)?
    /// 別トレイからアイテムが移動してきたとき呼ばれる（itemID, sourceTrayID）。
    var onMove: ((UUID, UUID) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.trayItem])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.trayItem])
    }

    /// マウスクリックは透過する（`FileDropView` と同じ理由）。
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        .move
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let transfer = TrayItemDragCoordinator.shared.current else { return false }

        let location = flippedLocation(for: sender.draggingLocation)
        if transfer.sourceTrayID == trayID {
            onReorder?(transfer.itemID, nearestIndex(for: location))
        } else {
            onMove?(transfer.itemID, transfer.sourceTrayID)
        }
        return true
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        TrayItemDragCoordinator.shared.clear()
    }

    /// window 座標（左下原点）→ SwiftUI 座標（左上原点）へ変換。
    /// `TrayPanel.isDraggableBackgroundPoint`（PanelSubclasses.swift）と同じ式。
    private func flippedLocation(for locationInWindow: NSPoint) -> CGPoint {
        let local = convert(locationInWindow, from: nil)
        return CGPoint(x: local.x, y: bounds.height - local.y)
    }

    /// ドロップ位置を含む、または中心が最も近いアイテムのインデックスを返す。
    /// アイテムが1つもない場合は 0。
    private func nearestIndex(for point: CGPoint) -> Int {
        guard let frames = itemFrameTracker?.itemFrames, !frames.isEmpty else { return 0 }
        if let containingIndex = frames.firstIndex(where: { $0.contains(point) }) {
            return containingIndex
        }
        var nearestIndex = frames.count - 1
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        for (index, rect) in frames.enumerated() {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let distance = hypot(center.x - point.x, center.y - point.y)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestIndex = index
            }
        }
        return nearestIndex
    }
}
