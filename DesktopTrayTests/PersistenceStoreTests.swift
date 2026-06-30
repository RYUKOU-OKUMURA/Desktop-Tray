import XCTest
@testable import DesktopTray

final class PersistenceStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: PersistenceStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopTrayTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = PersistenceStore(directoryURL: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        store = nil
        super.tearDown()
    }

    func test_loadSync_returnsDefaultsWhenNoFile() {
        let snapshot = store.loadSync()

        XCTAssertEqual(snapshot.schemaVersion, PersistenceStore.currentSchemaVersion)
        XCTAssertEqual(snapshot.displayMode, .safe)
        XCTAssertFalse(snapshot.trays.isEmpty)
        // 手動5 + スマート5
        XCTAssertEqual(snapshot.trays.filter(\.isSmart.negated).count, 5)
        XCTAssertEqual(snapshot.trays.filter(\.isSmart).count, 5)
    }

    func test_saveAndLoad_roundTrips() throws {
        let tray = Tray(
            name: "テスト",
            type: .manual,
            color: .purple,
            frame: TrayFrame(x: 100, y: 200, width: 400, height: 300),
            isCollapsed: false,
            tabIndex: 0,
            items: [
                TrayItem(url: URL(fileURLWithPath: "/Users/demo/Desktop/a.pdf"), sortIndex: 0),
                TrayItem(url: URL(fileURLWithPath: "/Users/demo/Desktop/b.png"), sortIndex: 1),
            ]
        )
        let original = PersistenceStore.Snapshot(
            schemaVersion: PersistenceStore.currentSchemaVersion,
            trays: [tray],
            displayMode: .safe
        )

        try store.saveSync(original)
        let loaded = store.loadSync()

        XCTAssertEqual(loaded.trays.count, 1)
        XCTAssertEqual(loaded.trays[0].name, "テスト")
        XCTAssertEqual(loaded.trays[0].color, .purple)
        XCTAssertEqual(loaded.trays[0].items.count, 2)
        XCTAssertEqual(loaded.trays[0].items[0].url.lastPathComponent, "a.pdf")
        XCTAssertEqual(loaded.trays[0].items[1].sortIndex, 1)
    }

    func test_saveAndLoad_preservesSmartRule() throws {
        let smart = Tray(
            name: "PDF",
            type: .smart,
            color: .red,
            frame: TrayFrame(width: 400, height: 260),
            rule: SmartTrayRule(kind: .fileExtensionIn(["pdf"]))
        )
        let snapshot = PersistenceStore.Snapshot(
            schemaVersion: PersistenceStore.currentSchemaVersion,
            trays: [smart],
            displayMode: .safe
        )

        try store.saveSync(snapshot)
        let loaded = store.loadSync()

        XCTAssertEqual(loaded.trays.count, 1)
        XCTAssertEqual(loaded.trays[0].rule, smart.rule)
        if case .fileExtensionIn(let exts) = loaded.trays[0].rule?.kind {
            XCTAssertEqual(exts, ["pdf"])
        } else {
            XCTFail("rule kind mismatch")
        }
    }

    func test_markStaleItems_flagsMissingURLs() {
        let existing = URL(fileURLWithPath: "/Users/demo/Desktop/exists.pdf")
        let deleted = URL(fileURLWithPath: "/Users/demo/Desktop/deleted.pdf")
        let tray = Tray(
            name: "Manual",
            type: .manual,
            color: .blue,
            frame: TrayFrame(width: 400, height: 300),
            items: [
                TrayItem(url: existing, sortIndex: 0),
                TrayItem(url: deleted, sortIndex: 1),
            ]
        )
        let snapshot = PersistenceStore.Snapshot(
            schemaVersion: PersistenceStore.currentSchemaVersion,
            trays: [tray],
            displayMode: .safe
        )

        let marked = store.markStaleItems(in: snapshot, existingURLs: [existing])

        XCTAssertEqual(marked.trays[0].items[0].stale, false)
        XCTAssertEqual(marked.trays[0].items[1].stale, true)
    }

    func test_reset_clearsAllFiles() throws {
        let snapshot = PersistenceStore.Snapshot(
            schemaVersion: PersistenceStore.currentSchemaVersion,
            trays: [],
            displayMode: .safe
        )
        try store.saveSync(snapshot)
        try store.reset()

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("trays.json").path
        ))
    }

    func test_defaultTrays_containsSmartPresets() {
        let defaults = PersistenceStore.defaultTrays()
        let smartNames = defaults.filter(\.isSmart).map(\.name)

        XCTAssertTrue(smartNames.contains { $0.contains("スクリーンショット") })
        XCTAssertTrue(smartNames.contains { $0 == "PDF" })
        XCTAssertTrue(smartNames.contains { $0 == "画像" })
        XCTAssertTrue(smartNames.contains { $0.contains("最近") })
        XCTAssertTrue(smartNames.contains { $0.contains("未分類") })
    }
}

private extension Bool {
    var negated: Bool { !self }
}
