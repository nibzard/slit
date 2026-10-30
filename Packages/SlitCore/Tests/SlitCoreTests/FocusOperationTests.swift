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

    /// A new long press while a lock is verified starts a replacement
    /// acquisition. The verified state clears first, so the interface cannot
    /// report the old lock while the replacement settles.
    func testBeginWhileVerifiedClearsLockAndStartsReplacementAcquisition() {
        var focus = FocusOperation()
        let first = focus.begin()
        XCTAssertTrue(focus.confirmLock(first))
        XCTAssertTrue(focus.isLocked)
        let replacement = focus.begin()
        XCTAssertFalse(focus.isLocked)
        XCTAssertEqual(focus.pending, replacement)
        XCTAssertEqual(replacement.session, first.session)
        XCTAssertFalse(focus.confirmLock(first))
        XCTAssertFalse(focus.isLocked)
        XCTAssertTrue(focus.confirmLock(replacement))
        XCTAssertTrue(focus.isLocked)
        XCTAssertNil(focus.pending)
    }

    /// A completion token from an earlier session changes nothing. It cannot
    /// install a lock and cannot displace the pending acquisition of the
    /// current session.
    func testStaleCompletionAfterSessionChangeChangesNothing() {
        var focus = FocusOperation()
        let stale = focus.begin()
        let staleSession = focus.session
        focus.restartSession()
        XCTAssertNotEqual(focus.session, staleSession)
        XCTAssertFalse(focus.confirmLock(stale))
        XCTAssertFalse(focus.isLocked)
        XCTAssertNil(focus.pending)
        let current = focus.begin()
        XCTAssertFalse(focus.confirmLock(stale))
        XCTAssertFalse(focus.isLocked)
        XCTAssertEqual(focus.pending, current)
        XCTAssertTrue(focus.confirmLock(current))
        XCTAssertTrue(focus.isLocked)
    }
}
