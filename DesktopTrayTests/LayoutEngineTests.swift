import XCTest
@testable import DesktopTray

final class LayoutEngineTests: XCTestCase {
    private let engine = LayoutEngine(
        snapThreshold: 20,
        collapsedTabWidth: 32,
        sideRailWidth: 56,
        minTrayHeight: 260
    )

    func test_shouldSnap_trueWhenWithinThreshold() {
        let nearLeft = CGRect(x: 60, y: 100, width: 400, height: 300)
        XCTAssertTrue(engine.shouldSnap(frame: nearLeft))
    }

    func test_shouldSnap_falseWhenFarFromLeft() {
        let farFromLeft = CGRect(x: 200, y: 100, width: 400, height: 300)
        XCTAssertFalse(engine.shouldSnap(frame: farFromLeft))
    }

    func test_collapsedTabFrame_isPlacedAtLeftEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let tab = engine.collapsedTabFrame(index: 0, screen: screen)

        XCTAssertEqual(tab.origin.x, 0)
        XCTAssertEqual(tab.width, 32)
        XCTAssertEqual(tab.height, TrayTheme.collapsedTabHeight)
    }

    func test_tabRailWindowFrame_includesTabsAndFooter() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = engine.tabRailWindowFrame(tabCount: 3, screen: screen)

        let expectedTabsHeight = 3 * TrayTheme.collapsedTabHeight + 2 * TrayTheme.tabSpacing
        let expectedHeight = TrayTheme.tabRailTopPadding + expectedTabsHeight + TrayTheme.tabRailFooterHeight

        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.width, 40)
        XCTAssertEqual(frame.height, expectedHeight)
        XCTAssertEqual(frame.maxY, screen.maxY)
    }

    func test_collapsedEdgeFrame_slidesOffscreen() {
        let saved = CGRect(x: 200, y: 100, width: 400, height: 300)
        let collapsed = engine.collapsedEdgeFrame(saved: saved, tabWidth: 32)

        XCTAssertEqual(collapsed.width, 400)
        XCTAssertEqual(collapsed.height, 300)
        XCTAssertEqual(collapsed.origin.y, 100)
        XCTAssertEqual(collapsed.minX, -368)
        XCTAssertEqual(collapsed.maxX, 32)
    }

    func test_expandedFrame_clampsToScreenWhenOffscreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let offscreen = CGRect(x: -100, y: -100, width: 400, height: 300)
        let expanded = engine.expandedFrame(saved: offscreen, screen: screen)

        XCTAssertGreaterThanOrEqual(expanded.minX, 32 + 16)
        XCTAssertGreaterThanOrEqual(expanded.minY, 8)
    }

    func test_expandedFrame_enforcesMinHeight() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let tooShort = CGRect(x: 200, y: 200, width: 400, height: 50)
        let expanded = engine.expandedFrame(saved: tooShort, screen: screen)

        XCTAssertEqual(expanded.height, 260)
    }

    func test_clampToVisibleFrames_pullsBackIntoBounds() {
        let frame = CGRect(x: -200, y: -200, width: 400, height: 300)
        let clamped = engine.clampToVisibleFrames(frame)

        XCTAssertGreaterThanOrEqual(clamped.minX, 0)
        XCTAssertGreaterThanOrEqual(clamped.minY, 0)
    }

    func test_clampToVisibleFrames_keepsInBoundsFrame() {
        let frame = CGRect(x: 200, y: 200, width: 400, height: 300)
        let clamped = engine.clampToVisibleFrames(frame)

        XCTAssertEqual(clamped, frame)
    }
}
