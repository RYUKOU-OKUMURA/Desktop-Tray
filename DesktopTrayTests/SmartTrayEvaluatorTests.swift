import XCTest
@testable import DesktopTray

final class SmartTrayEvaluatorTests: XCTestCase {
    private let evaluator = SmartTrayEvaluator()

    private func makeItem(name: String, ext: String = "", creationDate: Date? = nil) -> DesktopItem {
        let path = ext.isEmpty ? "/Users/demo/Desktop/\(name)" : "/Users/demo/Desktop/\(name).\(ext)"
        return DesktopItem(
            url: URL(fileURLWithPath: path),
            name: path as NSString? != nil ? (path as NSString).lastPathComponent : name,
            isDirectory: false,
            creationDate: creationDate,
            contentModificationDate: nil
        )
    }

    func test_filenameContainsAny_matchesCaseInsensitive() {
        let rule = SmartTrayRule(kind: .filenameContainsAny(["スクリーンショット", "Screenshot"]))
        let matching = makeItem(name: "screenshot 2026-06-30 at 12.00.00.png")
        let nonMatching = makeItem(name: "report.pdf")

        XCTAssertTrue(evaluator.matches(rule: rule, item: matching))
        XCTAssertFalse(evaluator.matches(rule: rule, item: nonMatching))
    }

    func test_filenameContainsAny_matchesJapanese() {
        let rule = SmartTrayRule(kind: .filenameContainsAny(["スクリーンショット"]))
        let matching = makeItem(name: "スクリーンショット 2026-06-30.png")

        XCTAssertTrue(evaluator.matches(rule: rule, item: matching))
    }

    func test_fileExtensionIn_matchesLowercased() {
        let rule = SmartTrayRule(kind: .fileExtensionIn(["pdf"]))
        let pdf = makeItem(name: "spec", ext: "pdf")
        let uppercase = makeItem(name: "spec", ext: "PDF")
        let png = makeItem(name: "image", ext: "png")

        XCTAssertTrue(evaluator.matches(rule: rule, item: pdf))
        XCTAssertTrue(evaluator.matches(rule: rule, item: uppercase))
        XCTAssertFalse(evaluator.matches(rule: rule, item: png))
    }

    func test_fileExtensionIn_multipleExtensions() {
        let rule = SmartTrayRule(
            kind: .fileExtensionIn(["png", "jpg", "jpeg", "webp", "heic", "gif"])
        )
        XCTAssertTrue(evaluator.matches(rule: rule, item: makeItem(name: "a", ext: "png")))
        XCTAssertTrue(evaluator.matches(rule: rule, item: makeItem(name: "a", ext: "jpg")))
        XCTAssertTrue(evaluator.matches(rule: rule, item: makeItem(name: "a", ext: "jpeg")))
        XCTAssertTrue(evaluator.matches(rule: rule, item: makeItem(name: "a", ext: "webp")))
        XCTAssertTrue(evaluator.matches(rule: rule, item: makeItem(name: "a", ext: "heic")))
        XCTAssertTrue(evaluator.matches(rule: rule, item: makeItem(name: "a", ext: "gif")))
        XCTAssertFalse(evaluator.matches(rule: rule, item: makeItem(name: "a", ext: "pdf")))
        XCTAssertFalse(evaluator.matches(rule: rule, item: makeItem(name: "a", ext: "txt")))
    }

    func test_createdWithinDays_withinBoundary() {
        let rule = SmartTrayRule(kind: .createdWithinDays(7))
        let recent = makeItem(name: "new", creationDate: Date().addingTimeInterval(-3 * 86_400))
        let old = makeItem(name: "old", creationDate: Date().addingTimeInterval(-30 * 86_400))
        let noDate = makeItem(name: "nodate", creationDate: nil)

        XCTAssertTrue(evaluator.matches(rule: rule, item: recent))
        XCTAssertFalse(evaluator.matches(rule: rule, item: old))
        XCTAssertFalse(evaluator.matches(rule: rule, item: noDate))
    }

    func test_createdWithinDays_exactlyAtBoundary() {
        let rule = SmartTrayRule(kind: .createdWithinDays(7))
        // 6日23時間前 → still within 7 days
        let justInside = makeItem(
            name: "edge",
            creationDate: Date().addingTimeInterval(-(6 * 86_400 + 3600))
        )
        XCTAssertTrue(evaluator.matches(rule: rule, item: justInside))
    }

    func test_evaluate_returnsMatchesForEachSmartTray() {
        let screenshots = SmartTrayPresets.screenshots
        let pdf = SmartTrayPresets.pdf
        let images = SmartTrayPresets.images
        let trays = [screenshots, pdf, images]

        let items = [
            makeItem(name: "screenshot 2026", ext: "png"),
            makeItem(name: "spec", ext: "pdf"),
            makeItem(name: "design", ext: "png"),
            makeItem(name: "notes", ext: "txt"),
        ]

        let results = evaluator.evaluate(items: items, trays: trays)

        XCTAssertEqual(results[screenshots.id]?.count, 1)
        XCTAssertEqual(results[pdf.id]?.count, 1)
        XCTAssertEqual(results[images.id]?.count, 2)
    }

    /// 再評価のたびに ID が変わると、ドラッグ中の識別子（`TrayItemTransfer.itemID`）や
    /// アイコンキャッシュが無効化されてしまう（不具合修正: スマートトレイからのドラッグ移動）。
    /// 同じ URL には常に同じ ID が振られることを確認する。
    func test_evaluate_assignsStableIDsAcrossReevaluation() {
        let pdf = SmartTrayPresets.pdf
        let trays = [pdf]
        let items = [makeItem(name: "spec", ext: "pdf")]

        let first = evaluator.evaluate(items: items, trays: trays)
        let second = evaluator.evaluate(items: items, trays: trays)

        let firstID = first[pdf.id]?.first?.id
        let secondID = second[pdf.id]?.first?.id
        XCTAssertNotNil(firstID)
        XCTAssertEqual(firstID, secondID)
    }

    func test_evaluate_uncategorized_excludesManualAssignedAndSmartMatched() {
        let screenshots = SmartTrayPresets.screenshots
        let pdf = SmartTrayPresets.pdf
        let uncategorized = SmartTrayPresets.uncategorized
        let manual = Tray(
            name: "Manual",
            type: .manual,
            color: .blue,
            frame: TrayFrame(width: 400, height: 300),
            items: [TrayItem(url: URL(fileURLWithPath: "/Users/demo/Desktop/manual.txt"), sortIndex: 0)]
        )
        let trays = [manual, screenshots, pdf, uncategorized]

        let items = [
            makeItem(name: "manual", ext: "txt"),       // 手動所属 → 未分類除外
            makeItem(name: "screenshot 2026", ext: "png"), // スマート screenshot 該当 → 未分類除外
            makeItem(name: "spec", ext: "pdf"),          // スマート pdf 該当 → 未分類除外
            makeItem(name: "random", ext: "md"),         // どこにも該当しない → 未分類
        ]

        let results = evaluator.evaluate(items: items, trays: trays)

        XCTAssertEqual(results[uncategorized.id]?.count, 1)
        XCTAssertEqual(results[uncategorized.id]?[0].url.lastPathComponent, "random.md")
    }

    func test_evaluate_sameFileAppearsInMultipleSmartTrays() {
        // スクショ + 画像 の両方に png スクショが表示される（要件定義 §9.5）
        let screenshots = SmartTrayPresets.screenshots
        let images = SmartTrayPresets.images
        let trays = [screenshots, images]

        let screenshotPng = makeItem(name: "screenshot 2026", ext: "png")
        let items = [screenshotPng]

        let results = evaluator.evaluate(items: items, trays: trays)

        XCTAssertEqual(results[screenshots.id]?.count, 1)
        XCTAssertEqual(results[images.id]?.count, 1)
        XCTAssertEqual(results[screenshots.id]?[0].url, screenshotPng.url)
        XCTAssertEqual(results[images.id]?[0].url, screenshotPng.url)
    }

    func test_evaluate_emptyItems_returnsEmptyForAll() {
        let trays = SmartTrayPresets.all
        let results = evaluator.evaluate(items: [], trays: trays)
        for tray in trays {
            XCTAssertEqual(results[tray.id]?.count, 0, "\(tray.name) should be empty")
        }
    }
}
