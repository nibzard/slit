import XCTest
@testable import SlitCore

final class FocusOperationTests: XCTestCase {
    func testReplacementIgnoresOldCompletion() {
        var focus = FocusOperation()
        let old = focus.begin(), current = focus.begin()
        XCTAssertFalse(focus.confirmLock(old))
        XCTAssertFalse(focus.isLocked)
        XCTAssertTrue(focus.confirmLock(current))
        XCTAssertTrue(focus.isLocked)
    }

    func testRestartInvalidatesCallbacksAndClearsLock() {
        var focus = FocusOperation()
        let old = focus.begin()
        focus.restartSession()
        XCTAssertFalse(focus.confirmLock(old))
        let current = focus.begin()
        XCTAssertTrue(focus.confirmLock(current))
        focus.restartSession()
        XCTAssertFalse(focus.isLocked)
    }

    func testLeavingCaptureCancelsPendingButRetainsVerifiedLock() {
        var focus = FocusOperation()
        let cancelled = focus.begin()
        focus.cancelPending()
        XCTAssertFalse(focus.confirmLock(cancelled))
        let verified = focus.begin()
        XCTAssertTrue(focus.confirmLock(verified))
        focus.cancelPending()
        XCTAssertTrue(focus.isLocked)
        focus.unlock()
        XCTAssertFalse(focus.isLocked)
    }
}
