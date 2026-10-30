import Foundation
import Testing
@testable import SlitCore

struct CaptureContractTests {
    @Test func durableOrderDoesNotDependOnSessionOrCompletion() {
        let first = CaptureIdentity(captureId: UUID(), sessionId: UUID(), requestOrdinal: 99,
                                    libraryOrder: LibraryOrder(200))
        let later = CaptureIdentity(captureId: UUID(), sessionId: UUID(), requestOrdinal: 1,
                                    libraryOrder: LibraryOrder(205))
        #expect([later, first].sorted { $0.libraryOrder < $1.libraryOrder } == [first, later])
        #expect(ReservedOrderBlock(values: LibraryOrder(201)...LibraryOrder(210)).values.contains(later.libraryOrder))
    }

    @Test func retainedFailureKeepsIdentityAndSlotAcrossRetry() throws {
        let identity = CaptureIdentity(captureId: UUID(), sessionId: UUID(), requestOrdinal: 1,
                                       libraryOrder: LibraryOrder(10))
        var admission = CaptureAdmission(capacity: 1)
        let context = CaptureAdmission.Context(isActive: true, isCaptureVisible: true,
                                               isOutputReady: true, isStorageWritable: true)
        try admission.reserve(id: identity.captureId, context: context)
        try admission.transition(id: identity.captureId, to: .delivered)
        try admission.transition(id: identity.captureId, to: .saving)
        let result = CommitResult.retained(RetainedSave(identity: identity, token: UUID()),
                                          ServiceFailure(code: "write", message: "Injected write failure"))
        guard case let .retained(retained, _) = result else { Issue.record("Expected retained bytes"); return }
        try admission.transition(id: retained.identity.captureId, to: .saveFailed)
        #expect(throws: CaptureAdmission.Rejection.capacityReached) {
            try admission.reserve(id: UUID(), context: context)
        }
        try admission.transition(id: retained.identity.captureId, to: .saving)
        #expect(retained.identity == identity)
        #expect(admission.slots.count == 1)
        try admission.didCommit(id: retained.identity.captureId)
        #expect(admission.slots.isEmpty)
    }
}
