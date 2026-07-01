import XCTest
@testable import DesktopTray

final class TrayEngineTests: XCTestCase {
    private func makeManualTray(id: UUID = UUID(), items: [TrayItem] = []) -> Tray {
        Tray(
            id: id,
            name: "Test",
            type: .manual,
            color: .blue,
            frame: TrayFrame(width: 400, height: 300),
            items: items
        )
    }

    func test_assignToTray_addsItemWhenNotPresent() {
        var trays = [makeManualTray()]
        let url = URL(fileURLWithPath: "/Users/demo/Desktop/file.pdf")
        let engine = TrayEngine()

        let added = engine.assignToTray(url: url, to: trays[0].id, in: &trays)

        XCTAssertTrue(added)
        XCTAssertEqual(trays[0].items.count, 1)
        XCTAssertEqual(trays[0].items[0].url, url)
        XCTAssertEqual(trays[0].items[0].sortIndex, 0)
    }

    func test_assignToTray_isIdempotent() {
        let url = URL(fileURLWithPath: "/Users/demo/Desktop/file.pdf")
        var trays = [makeManualTray(items: [TrayItem(url: url, sortIndex: 0)])]
        let engine = TrayEngine()

        let added = engine.assignToTray(url: url, to: trays[0].id, in: &trays)

        XCTAssertFalse(added)
        XCTAssertEqual(trays[0].items.count, 1)
    }

    func test_assignToTray_rejectsSmartTray() {
        let smartTray = Tray(
            name: "Smart",
            type: .smart,
            color: .pink,
            frame: TrayFrame(width: 400, height: 300),
            rule: SmartTrayRule(kind: .fileExtensionIn(["pdf"]))
        )
        var trays = [smartTray]
        let engine = TrayEngine()

        let added = engine.assignToTray(
            url: URL(fileURLWithPath: "/Users/demo/Desktop/file.pdf"),
            to: smartTray.id,
            in: &trays
        )

        XCTAssertFalse(added)
        XCTAssertTrue(trays[0].items.isEmpty)
    }

    func test_removeFromTray_removesAndReindexes() {
        let urls = (0..<3).map { i in
            URL(fileURLWithPath: "/Users/demo/Desktop/file\(i).pdf")
        }
        let items = urls.enumerated().map { TrayItem(url: $0.element, sortIndex: $0.offset) }
        var trays = [makeManualTray(items: items)]
        let engine = TrayEngine()

        let removed = engine.removeFromTray(url: urls[1], from: trays[0].id, in: &trays)

        XCTAssertTrue(removed)
        XCTAssertEqual(trays[0].items.count, 2)
        XCTAssertEqual(trays[0].items[0].url, urls[0])
        XCTAssertEqual(trays[0].items[0].sortIndex, 0)
        XCTAssertEqual(trays[0].items[1].url, urls[2])
        XCTAssertEqual(trays[0].items[1].sortIndex, 1)
    }

    func test_reorder_movesItemAndReindexes() {
        let urls = (0..<3).map { i in
            URL(fileURLWithPath: "/Users/demo/Desktop/file\(i).pdf")
        }
        let items = urls.enumerated().map { TrayItem(url: $0.element, sortIndex: $0.offset) }
        var trays = [makeManualTray(items: items)]
        let engine = TrayEngine()

        let result = engine.reorder(url: urls[2], in: trays[0].id, to: 0, in: &trays)

        XCTAssertTrue(result)
        XCTAssertEqual(trays[0].items[0].url, urls[2])
        XCTAssertEqual(trays[0].items[1].url, urls[0])
        XCTAssertEqual(trays[0].items[2].url, urls[1])
        XCTAssertEqual(trays[0].items.map(\.sortIndex), [0, 1, 2])
    }

    func test_moveBetweenTrays_movesItem() {
        let url = URL(fileURLWithPath: "/Users/demo/Desktop/file.pdf")
        let from = makeManualTray(items: [TrayItem(url: url, sortIndex: 0)])
        let to = makeManualTray()
        var trays = [from, to]
        let engine = TrayEngine()

        let moved = engine.moveBetweenTrays(
            url: url,
            from: from.id,
            to: to.id,
            in: &trays
        )

        XCTAssertTrue(moved)
        XCTAssertTrue(trays[0].items.isEmpty)
        XCTAssertEqual(trays[1].items.count, 1)
        XCTAssertEqual(trays[1].items[0].url, url)
    }

    func test_moveBetweenTrays_toSameTrayIsNoop() {
        let url = URL(fileURLWithPath: "/Users/demo/Desktop/file.pdf")
        let tray = makeManualTray(items: [TrayItem(url: url, sortIndex: 0)])
        var trays = [tray]
        let engine = TrayEngine()

        let moved = engine.moveBetweenTrays(
            url: url,
            from: tray.id,
            to: tray.id,
            in: &trays
        )

        XCTAssertFalse(moved)
        XCTAssertEqual(trays[0].items.count, 1)
    }

    /// スマートトレイ（例:「未分類」）は実体としての所属配列を持たないため、
    /// そこからのドラッグ移動は移動先の手動トレイへの追加として扱われる（不具合修正）。
    func test_moveBetweenTrays_fromSmartTrayAssignsToDestination() {
        let url = URL(fileURLWithPath: "/Users/demo/Desktop/file.pdf")
        let smartTray = Tray(
            name: "未分類",
            type: .smart,
            color: .gray,
            frame: TrayFrame(width: 400, height: 300),
            rule: SmartTrayRule(kind: .uncategorized)
        )
        let manualTray = makeManualTray()
        var trays = [smartTray, manualTray]
        let engine = TrayEngine()

        let moved = engine.moveBetweenTrays(
            url: url,
            from: smartTray.id,
            to: manualTray.id,
            in: &trays
        )

        XCTAssertTrue(moved)
        XCTAssertEqual(trays[1].items.count, 1)
        XCTAssertEqual(trays[1].items[0].url, url)
    }

    /// スマートトレイへは手動で追加できないため、移動先がスマートトレイなら no-op のまま。
    func test_moveBetweenTrays_toSmartTrayIsNoop() {
        let url = URL(fileURLWithPath: "/Users/demo/Desktop/file.pdf")
        let manualTray = makeManualTray(items: [TrayItem(url: url, sortIndex: 0)])
        let smartTray = Tray(
            name: "PDF",
            type: .smart,
            color: .pink,
            frame: TrayFrame(width: 400, height: 300),
            rule: SmartTrayRule(kind: .fileExtensionIn(["pdf"]))
        )
        var trays = [manualTray, smartTray]
        let engine = TrayEngine()

        let moved = engine.moveBetweenTrays(
            url: url,
            from: manualTray.id,
            to: smartTray.id,
            in: &trays
        )

        XCTAssertFalse(moved)
        XCTAssertEqual(trays[0].items.count, 1)
    }

    func test_updateTrayLayout_setsFrameAndCollapsed() {
        let tray = makeManualTray()
        var trays = [tray]
        let engine = TrayEngine()
        let newFrame = TrayFrame(x: 100, y: 200, width: 300, height: 250)

        engine.updateTrayLayout(
            trayID: tray.id,
            frame: newFrame,
            collapsed: true,
            in: &trays
        )

        XCTAssertEqual(trays[0].frame, newFrame)
        XCTAssertTrue(trays[0].isCollapsed)
    }

    func test_collapseAll_assignsTabIndexSequentially() {
        let trays = (0..<3).map { i in
            makeManualTray(items: [])
        }
        var mutable = trays
        let engine = TrayEngine()

        engine.collapseAll(in: &mutable)

        XCTAssertTrue(mutable.allSatisfy(\.isCollapsed))
        XCTAssertEqual(mutable.map(\.tabIndex), [0, 1, 2])
    }

    func test_deleteTray_doesNotAffectOthers() {
        let t1 = makeManualTray()
        let t2 = makeManualTray()
        var trays = [t1, t2]
        let engine = TrayEngine()

        let deleted = engine.deleteTray(id: t1.id, in: &trays)

        XCTAssertTrue(deleted)
        XCTAssertEqual(trays.count, 1)
        XCTAssertEqual(trays[0].id, t2.id)
    }

    func test_renameTray_updatesName() {
        let tray = makeManualTray()
        var trays = [tray]
        let engine = TrayEngine()

        let renamed = engine.renameTray(id: tray.id, name: "  素材  ", in: &trays)

        XCTAssertTrue(renamed)
        XCTAssertEqual(trays[0].name, "素材")
    }

    func test_renameTray_rejectsEmptyName() {
        let tray = makeManualTray()
        var trays = [tray]
        let engine = TrayEngine()

        let renamed = engine.renameTray(id: tray.id, name: "   ", in: &trays)

        XCTAssertFalse(renamed)
        XCTAssertEqual(trays[0].name, "Test")
    }
}
