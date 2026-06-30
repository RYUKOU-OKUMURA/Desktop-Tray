import XCTest
@testable import DesktopTray

final class LayoutEngineTests: XCTestCase {
    private let engine = LayoutEngine(
        snapThreshold: 20,
        collapsedTabWidth: 40,
        sideRailWidth: 56,
        minTrayHeight: 260
    )

    func test_shouldSnap_trueWhenWithinThreshold() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let nearLeft = CGRect(x: 60, y: 100, width: 400, height: 300) // 60 < 56+20=76

        XCTAssertTrue(engine.shouldSnap(frame: nearLeft))
        _ = screen // unused
    }

    func test_shouldSnap_falseWhenFarFromLeft() {
        let farFromLeft = CGRect(x: 200, y: 100, width: 400, height: 300)

        XCTAssertFalse(engine.shouldSnap(frame: farFromLeft))
    }

    func test_collapsedEdgeFrame_slidesOffscreen() {
        let saved = CGRect(x: 200, y: 100, width: 400, height: 300)
        let collapsed = engine.collapsedEdgeFrame(saved: saved, tabWidth: 40)

        // 幅・高さ・Y位置は維持
        XCTAssertEqual(collapsed.width, 400)
        XCTAssertEqual(collapsed.height, 300)
        XCTAssertEqual(collapsed.origin.y, 100)
        // x = -(400 - 40) = -360（左端から40px覗く）
        XCTAssertEqual(collapsed.minX, -360)
        // 覗いている部分の右端 = -360 + 400 = 40
        XCTAssertEqual(collapsed.maxX, 40)
    }

    func test_collapsedEdgeFrame_preservesHeightAndY() {
        let saved = CGRect(x: 500, y: 600, width: 420, height: 280)
        let collapsed = engine.collapsedEdgeFrame(saved: saved, tabWidth: 40)

        XCTAssertEqual(collapsed.origin.y, 600)
        XCTAssertEqual(collapsed.height, 280)
        XCTAssertEqual(collapsed.minX, -380) // -(420 - 40)
    }

    func test_expandedFrame_clampsToScreenWhenOffscreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let offscreen = CGRect(x: -100, y: -100, width: 400, height: 300)
        let expanded = engine.expandedFrame(saved: offscreen, screen: screen)

        XCTAssertGreaterThanOrEqual(expanded.minX, 56 + 40 + 8) // sideRail + tabWidth + padding
        XCTAssertGreaterThanOrEqual(expanded.minY, 8)
    }

    func test_expandedFrame_enforcesMinHeight() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let tooShort = CGRect(x: 200, y: 200, width: 400, height: 50)
        let expanded = engine.expandedFrame(saved: tooShort, screen: screen)

        XCTAssertEqual(expanded.height, 260) // minTrayHeight
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
