import Foundation
import XCTest
@testable import SlitCore

final class CaptureAdmissionTests: XCTestCase {
    private let ready = CaptureAdmission.Context(
        isActive: true, isCaptureVisible: true, isOutputReady: true, isStorageWritable: true
    )

    /// Reserve one slot and drive it to the named phase through accepted transitions.
    private func gateWithSlot(at phase: CaptureAdmission.Phase, id: UUID) throws -> CaptureAdmission {
        var gate = CaptureAdmission()
        try gate.reserve(id: id, context: ready)
        switch phase {
        case .requested:
            break
        case .delivered:
            try gate.transition(id: id, to: .delivered)
        case .saving:
            try gate.transition(id: id, to: .delivered)
            try gate.transition(id: id, to: .saving)
        case .saveFailed:
            try gate.transition(id: id, to: .delivered)
            try gate.transition(id: id, to: .saving)
            try gate.transition(id: id, to: .saveFailed)
        }
        return gate
    }

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

    /// The table admits only requested to delivered, delivered to saving,
    /// saving to saveFailed, and saveFailed to saving. Every other pair fails,
    /// including same-phase transitions such as delivered to delivered.
    func testInvalidTransitionsAreRejectedAndKeepTheCurrentPhase() throws {
        let accepted: [CaptureAdmission.Phase: CaptureAdmission.Phase] = [
            .requested: .delivered,
            .delivered: .saving,
            .saving: .saveFailed,
            .saveFailed: .saving
        ]
        for current in [CaptureAdmission.Phase.requested, .delivered, .saving, .saveFailed] {
            for next in [CaptureAdmission.Phase.requested, .delivered, .saving, .saveFailed]
            where accepted[current] != next {
                let id = UUID()
                var gate = try gateWithSlot(at: current, id: id)
                XCTAssertThrowsError(try gate.transition(id: id, to: next)) {
                    XCTAssertEqual($0 as? CaptureAdmission.Rejection, .invalidTransition)
                }
                XCTAssertEqual(gate.slots[id], current)
            }
        }
    }

    /// Only a slot in the saving phase may commit. A commit from any other
    /// phase is refused, so retained bytes cannot be released by accident.
    func testCommitBeforeSavingOrAfterFailureThrowsInvalidTransition() throws {
        for phase in [CaptureAdmission.Phase.requested, .delivered, .saveFailed] {
            let id = UUID()
            var gate = try gateWithSlot(at: phase, id: id)
            XCTAssertThrowsError(try gate.didCommit(id: id)) {
                XCTAssertEqual($0 as? CaptureAdmission.Rejection, .invalidTransition)
            }
            XCTAssertEqual(gate.slots[id], phase)
        }
    }

    /// Current behavior: an unknown identifier is refused with unknownIdentifier
    /// and never removes another request's slot.
    func testReleaseOfAnUnknownIdentifierIsRejectedAndKeepsOccupiedSlots() throws {
        var gate = CaptureAdmission()
        XCTAssertThrowsError(try gate.releaseFailedRequest(id: UUID())) {
            XCTAssertEqual($0 as? CaptureAdmission.Rejection, .unknownIdentifier)
        }
        XCTAssertTrue(gate.slots.isEmpty)
        let retained = UUID()
        try gate.reserve(id: retained, context: ready)
        XCTAssertThrowsError(try gate.releaseFailedRequest(id: UUID())) {
            XCTAssertEqual($0 as? CaptureAdmission.Rejection, .unknownIdentifier)
        }
        XCTAssertEqual(gate.slots, [retained: .requested])
    }

    /// Current behavior: release does not check the phase. The caller owns the
    /// data and confirms its release before calling this method.
    func testReleaseRemovesTheSlotFromAnyPhase() throws {
        for phase in [CaptureAdmission.Phase.requested, .delivered, .saving, .saveFailed] {
            let id = UUID()
            var gate = try gateWithSlot(at: phase, id: id)
            try gate.releaseFailedRequest(id: id)
            XCTAssertNil(gate.slots[id])
        }
    }

    func testReservedOrderBlockIncludesItsFirstAndLastOrder() {
        let block = ReservedOrderBlock(values: LibraryOrder(41)...LibraryOrder(48))
        XCTAssertEqual(block.values.lowerBound, LibraryOrder(41))
        XCTAssertEqual(block.values.upperBound, LibraryOrder(48))
        XCTAssertTrue(block.values.contains(block.values.lowerBound))
        XCTAssertTrue(block.values.contains(block.values.upperBound))
        XCTAssertFalse(block.values.contains(LibraryOrder(40)))
        XCTAssertFalse(block.values.contains(LibraryOrder(49)))
    }

    func testTwoOrderBlockReservesExactlyItsTwoBounds() {
        let block = ReservedOrderBlock(values: LibraryOrder(7)...LibraryOrder(8))
        XCTAssertEqual(block.values.lowerBound, LibraryOrder(7))
        XCTAssertEqual(block.values.upperBound, LibraryOrder(8))
        XCTAssertTrue(block.values.contains(LibraryOrder(7)))
        XCTAssertTrue(block.values.contains(LibraryOrder(8)))
        XCTAssertFalse(block.values.contains(LibraryOrder(6)))
        XCTAssertFalse(block.values.contains(LibraryOrder(9)))
    }

    /// Equal bounds reserve a single order. The range is closed, so the block
    /// is never empty and lowerBound equals upperBound.
    func testEqualBoundsReserveExactlyOneOrder() {
        let block = ReservedOrderBlock(values: LibraryOrder(5)...LibraryOrder(5))
        XCTAssertEqual(block.values.lowerBound, block.values.upperBound)
        XCTAssertTrue(block.values.contains(LibraryOrder(5)))
        XCTAssertFalse(block.values.contains(LibraryOrder(4)))
        XCTAssertFalse(block.values.contains(LibraryOrder(6)))
    }
}
