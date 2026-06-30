import XCTest
@testable import DesktopTray

/// 結合テスト（アーキテクチャ v0.1 §11.2）。
/// Desktop 変更 → 再評価、収納→復元、stale file 耐性 などドメイン層中心のデータフローを検証する。
@MainActor
final class IntegrationTests: XCTestCase {
    private func makeDesktopItem(named name: String, ext: String? = nil) -> DesktopItem {
        let path: String
        if let ext {
            path = "/Users/demo/Desktop/\(name).\(ext)"
        } else {
            path = "/Users/demo/Desktop/\(name)"
        }
        return DesktopItem(
            url: URL(fileURLWithPath: path),
            name: (path as NSString).lastPathComponent,
            isDirectory: false,
            creationDate: Date(),
            contentModificationDate: nil
        )
    }

    func test_desktopChange_triggersSmartReevaluation() {
        let engine = TrayEngine()
        let evaluator = SmartTrayEvaluator()
        let vm = TrayListViewModel(engine: engine, evaluator: evaluator)
        vm.setTrays(SmartTrayPresets.all)

        // 初期: デスクトップ空 → 全スマートトレイ空
        vm.updateDesktopItems([])
        XCTAssertTrue(vm.smartResults.values.allSatisfy { $0.isEmpty })

        // PDF 追加
        let pdf = makeDesktopItem(named: "spec", ext: "pdf")
        vm.updateDesktopItems([pdf])

        let pdfTray = vm.trays.first { $0.name == "PDF" }!
        XCTAssertEqual(vm.smartResults[pdfTray.id]?.count, 1)

        // PDF 削除（デスクトップから消える）
        vm.updateDesktopItems([])
        XCTAssertEqual(vm.smartResults[pdfTray.id]?.count, 0)
    }

    func test_collapseAndExpand_preservesTrayMembershipAndLayout() {
        let engine = TrayEngine()
        let evaluator = SmartTrayEvaluator()
        let vm = TrayListViewModel(engine: engine, evaluator: evaluator)

        let url = URL(fileURLWithPath: "/Users/demo/Desktop/file.pdf")
        var trays = [
            Tray(name: "Manual", type: .manual, color: .blue, frame: TrayFrame(x: 100, y: 100, width: 400, height: 300))
        ]
        engine.assignToTray(url: url, to: trays[0].id, in: &trays)
        vm.setTrays(trays)

        // 収納
        engine.updateTrayLayout(trayID: trays[0].id, frame: trays[0].frame, collapsed: true, in: &trays)
        vm.setTrays(trays)
        XCTAssertTrue(vm.trays[0].isCollapsed)

        // 展開
        engine.updateTrayLayout(trayID: trays[0].id, frame: trays[0].frame, collapsed: false, in: &trays)
        vm.setTrays(trays)
        XCTAssertFalse(vm.trays[0].isCollapsed)
        XCTAssertEqual(vm.trays[0].items.count, 1) // membership は維持
    }

    func test_staleItem_doesNotCrashEvaluator() {
        let engine = TrayEngine()
        let evaluator = SmartTrayEvaluator()
        let vm = TrayListViewModel(engine: engine, evaluator: evaluator)

        // 手動トレイに存在しない URL を登録（stale 相当）
        let deletedURL = URL(fileURLWithPath: "/Users/demo/Desktop/deleted.pdf")
        var trays = [
            Tray(
                name: "Manual",
                type: .manual,
                color: .blue,
                frame: TrayFrame(width: 400, height: 300),
                items: [TrayItem(url: deletedURL, sortIndex: 0, stale: true)]
            )
        ]
        // スマートプリセット追加
        trays.append(contentsOf: SmartTrayPresets.all)
        vm.setTrays(trays)

        // 実在アイテムは空 → deleted はどこにも現れないはず
        vm.updateDesktopItems([])

        let uncategorized = vm.trays.first { $0.rule?.kind == .uncategorized }!
        XCTAssertEqual(vm.smartResults[uncategorized.id]?.count, 0)

        // 手動トレイの items は変わらず 1 件（stale のまま）
        XCTAssertEqual(vm.trays[0].items.count, 1)
        XCTAssertTrue(vm.trays[0].items[0].stale)
    }

    func test_fileDrop_thenUnassign_thenSmartReevaluate() {
        let engine = TrayEngine()
        let evaluator = SmartTrayEvaluator()
        let vm = TrayListViewModel(engine: engine, evaluator: evaluator)

        let manual = Tray(name: "Manual", type: .manual, color: .blue, frame: TrayFrame(width: 400, height: 300))
        let uncategorized = SmartTrayPresets.uncategorized
        vm.setTrays([manual, uncategorized])

        let url = URL(fileURLWithPath: "/Users/demo/Desktop/file.md")
        vm.updateDesktopItems([
            DesktopItem(
                url: url,
                name: "file.md",
                isDirectory: false,
                creationDate: Date(),
                contentModificationDate: nil
            )
        ])

        // 未分類に file.md が現れるはず
        XCTAssertEqual(vm.smartResults[uncategorized.id]?.count, 1)

        // 手動トレイへ追加 → 未分類から外れる
        vm.assign(url: url, to: manual.id)
        vm.reevaluateSmart()
        XCTAssertEqual(vm.smartResults[uncategorized.id]?.count, 0)

        // 手動から外す → 未分類に戻る
        vm.unassign(url: url, from: manual.id)
        vm.reevaluateSmart()
        XCTAssertEqual(vm.smartResults[uncategorized.id]?.count, 1)
    }

    func test_persistenceRoundTrip_preservesCollapsedAndItems() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopTrayIT-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = PersistenceStore(directoryURL: tempDir)

        let url = URL(fileURLWithPath: "/Users/demo/Desktop/spec.pdf")
        let tray = Tray(
            name: "あとで読む",
            type: .manual,
            color: .blue,
            frame: TrayFrame(x: 120, y: 80, width: 400, height: 300),
            isCollapsed: true,
            tabIndex: 2,
            items: [TrayItem(url: url, sortIndex: 0)]
        )
        let snapshot = PersistenceStore.Snapshot(
            schemaVersion: PersistenceStore.currentSchemaVersion,
            trays: [tray],
            displayMode: .safe
        )

        try store.saveSync(snapshot)
        let loaded = store.loadSync()

        XCTAssertEqual(loaded.trays.count, 1)
        XCTAssertTrue(loaded.trays[0].isCollapsed)
        XCTAssertEqual(loaded.trays[0].tabIndex, 2)
        XCTAssertEqual(loaded.trays[0].items.count, 1)
        XCTAssertEqual(loaded.trays[0].items[0].url, url)
    }
}
