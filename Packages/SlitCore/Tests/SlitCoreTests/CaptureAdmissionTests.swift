import Foundation
import XCTest
@testable import SlitCore

final class CaptureAdmissionTests: XCTestCase {
    private let ready = CaptureAdmission.Context(
        isActive: true, isCaptureVisible: true, isOutputReady: true, isStorageWritable: true
    )

    func testDeliveryAndFailedSaveKeepCapacityOccupied() throws {
        var gate = CaptureAdmission()
        let first = UUID(), second = UUID(), rejected = UUID()
        try gate.reserve(id: first, context: ready)
        try gate.reserve(id: second, context: ready)
        try gate.transition(id: first, to: .delivered)
        try gate.transition(id: first, to: .saving)
        try gate.transition(id: first, to: .saveFailed)
        XCTAssertThrowsError(try gate.reserve(id: rejected, context: ready)) {
            XCTAssertEqual($0 as? CaptureAdmission.Rejection, .capacityReached)
        }
        XCTAssertNil(gate.slots[rejected])
        try gate.transition(id: first, to: .saving)
        try gate.didCommit(id: first)
        try gate.reserve(id: rejected, context: ready)
        XCTAssertEqual(gate.slots.count, 2)
    }

    func testHiddenAndBackgroundInputsDoNotReserveSlots() {
        for context in [
            CaptureAdmission.Context(isActive: false, isCaptureVisible: true, isOutputReady: true, isStorageWritable: true),
            CaptureAdmission.Context(isActive: true, isCaptureVisible: false, isOutputReady: true, isStorageWritable: true),
            CaptureAdmission.Context(isActive: true, isCaptureVisible: true, isOutputReady: false, isStorageWritable: true),
            CaptureAdmission.Context(isActive: true, isCaptureVisible: true, isOutputReady: true, isStorageWritable: false)
        ] {
            var gate = CaptureAdmission()
            XCTAssertThrowsError(try gate.reserve(id: UUID(), context: context))
            XCTAssertTrue(gate.slots.isEmpty)
        }
    }

    func testDuplicateInputAndPrematureCommitCannotReleaseData() throws {
        var gate = CaptureAdmission()
        let id = UUID()
        try gate.reserve(id: id, context: ready)
        XCTAssertThrowsError(try gate.reserve(id: id, context: ready))
        XCTAssertThrowsError(try gate.didCommit(id: id))
        XCTAssertEqual(gate.slots[id], .requested)
    }

    func testLowerCapacityKeepsExistingRequestsAndRejectsNewOnes() throws {
        var gate = CaptureAdmission()
        let a = UUID(), b = UUID()
        try gate.reserve(id: a, context: ready)
        try gate.reserve(id: b, context: ready)
        gate.setCapacity(1)
        XCTAssertEqual(gate.slots.count, 2)
        try gate.releaseFailedRequest(id: a)
        XCTAssertThrowsError(try gate.reserve(id: UUID(), context: ready))
        try gate.releaseFailedRequest(id: b)
        try gate.reserve(id: UUID(), context: ready)
    }

    func testUnknownCallbackCannotMutateAnotherRequest() throws {
        var gate = CaptureAdmission()
        let id = UUID()
        try gate.reserve(id: id, context: ready)
        XCTAssertThrowsError(try gate.transition(id: UUID(), to: .delivered))
        XCTAssertEqual(gate.slots, [id: .requested])
    }
}
