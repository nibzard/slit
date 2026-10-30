import Foundation
import Testing
@testable import SlitCore

/// In-memory segment store for tests. It records every create and delete.
actor MemoryDiagnosticsStore: DiagnosticsSegmentStore {
    enum StoreError: Error, Equatable {
        case segmentExists(String)
        case unknownSegment(String)
    }

    private(set) var lines: [String: [String]] = [:]
    private(set) var createdNames: [String] = []
    private(set) var deletedNames: [String] = []

    func createSegment(named name: String) throws {
        guard lines[name] == nil else { throw StoreError.segmentExists(name) }
        lines[name] = []
        createdNames.append(name)
    }

    func deleteSegments(named names: [String]) throws {
        for name in names {
            guard lines.removeValue(forKey: name) != nil else {
                throw StoreError.unknownSegment(name)
            }
            deletedNames.append(name)
        }
    }

    func append(line: String, to segment: String) throws -> UInt64 {
        guard let existing = lines[segment] else { throw StoreError.unknownSegment(segment) }
        let updated = existing + [line]
        lines[segment] = updated
        return updated.reduce(UInt64(0)) { $0 + UInt64($1.utf8.count) + 1 }
    }
}

struct DiagnosticsRotationTests {
    private let policy = DiagnosticsRotationPolicy(
        totalByteLimit: 1_000, segmentByteTrigger: 400, maximumSegmentCount: 3
    )
    private var rotation: DiagnosticsRotation { DiagnosticsRotation(policy: policy) }

    @Test func standardPolicyMatchesTheFiveMegabyteSpecificationBudget() {
        #expect(DiagnosticsRotationPolicy.standard.totalByteLimit == 5 * 1_024 * 1_024)
        #expect(DiagnosticsRotationPolicy.standard.segmentByteTrigger == 256 * 1_024)
        #expect(DiagnosticsRotationPolicy.standard.maximumSegmentCount == 20)
        #expect(DiagnosticsSegment(ordinal: 7, byteCount: 0).name == "000007.jsonl")
    }

    @Test func emptyIndexOpensTheFirstSegment() {
        let plan = rotation.plan(index: [], incomingByteCount: 100)
        #expect(plan.segmentToOpen == 1)
        #expect(plan.targetSegmentName == "000001.jsonl")
        #expect(plan.segmentsToDelete.isEmpty)
        #expect(!plan.isRefused)
        #expect(plan.projectedTotalBytes == 100)
        #expect(plan.projectedSegmentCount == 1)
    }

    @Test func writingBelowTheTriggerAppendsToTheNewestSegment() {
        let index = [
            DiagnosticsSegment(ordinal: 1, byteCount: 100),
            DiagnosticsSegment(ordinal: 2, byteCount: 100),
        ]
        let plan = rotation.plan(index: index, incomingByteCount: 50)
        #expect(plan.segmentToOpen == nil)
        #expect(plan.targetSegmentName == "000002.jsonl")
        #expect(plan.segmentsToDelete.isEmpty)
        #expect(plan.projectedTotalBytes == 250)
    }

    @Test func reachingTheExactByteLimitEvictsNothing() {
        let index = [
            DiagnosticsSegment(ordinal: 1, byteCount: 300),
            DiagnosticsSegment(ordinal: 2, byteCount: 300),
        ]
        let plan = rotation.plan(index: index, incomingByteCount: 400)
        #expect(plan.segmentsToDelete.isEmpty)
        #expect(plan.projectedTotalBytes == 1_000)
        #expect(plan.projectedSegmentCount == 2)
    }

    @Test func oneByteOverTheLimitEvictsOnlyTheOldestSegment() {
        let index = [
            DiagnosticsSegment(ordinal: 1, byteCount: 300),
            DiagnosticsSegment(ordinal: 2, byteCount: 300),
        ]
        let plan = rotation.plan(index: index, incomingByteCount: 401)
        #expect(plan.segmentsToDelete == ["000001.jsonl"])
        #expect(plan.projectedTotalBytes == 701)
        #expect(plan.targetSegmentName == "000002.jsonl")
    }

    @Test func evictionRemovesOldestFirstUntilTheBudgetHolds() {
        let index = [
            DiagnosticsSegment(ordinal: 3, byteCount: 100),
            DiagnosticsSegment(ordinal: 1, byteCount: 500),
            DiagnosticsSegment(ordinal: 2, byteCount: 900),
        ]
        // Total 1,500 plus 100 incoming. Evicting ordinal 1 leaves 1,100,
        // still over the budget, so ordinal 2 goes next and 200 remain.
        let plan = rotation.plan(index: index, incomingByteCount: 100)
        #expect(plan.segmentsToDelete == ["000001.jsonl", "000002.jsonl"])
        #expect(plan.projectedTotalBytes == 200)
        #expect(plan.projectedSegmentCount == 1)
    }

    @Test func fileCountCapEvictsEvenWhenBytesFit() {
        let tightCount = DiagnosticsRotationPolicy(
            totalByteLimit: 1_000, segmentByteTrigger: 400, maximumSegmentCount: 2
        )
        let index = [
            DiagnosticsSegment(ordinal: 1, byteCount: 100),
            DiagnosticsSegment(ordinal: 2, byteCount: 400),
        ]
        // The trigger opens segment 3, so the count reaches three and the
        // oldest segment must go even though the bytes fit the budget.
        let plan = DiagnosticsRotation(policy: tightCount)
            .plan(index: index, incomingByteCount: 100)
        #expect(plan.segmentToOpen == 3)
        #expect(plan.segmentsToDelete == ["000001.jsonl"])
        #expect(plan.projectedTotalBytes == 500)
        #expect(plan.projectedSegmentCount == 2)
    }

    @Test func sizeTriggerClosesTheActiveSegmentWithoutDeletingIt() {
        let index = [
            DiagnosticsSegment(ordinal: 1, byteCount: 400),
            DiagnosticsSegment(ordinal: 2, byteCount: 400),
        ]
        // Ordinal 2 reached the 400-byte trigger, so the record opens
        // segment 3. Total 800 plus 200 fits, so nothing is deleted.
        let plan = rotation.plan(index: index, incomingByteCount: 200)
        #expect(plan.segmentToOpen == 3)
        #expect(plan.targetSegmentName == "000003.jsonl")
        #expect(plan.segmentsToDelete.isEmpty)
        #expect(plan.projectedSegmentCount == 3)
    }

    @Test func recordLargerThanTheWholeBudgetIsRefused() {
        let index = [DiagnosticsSegment(ordinal: 1, byteCount: 500)]
        let plan = rotation.plan(index: index, incomingByteCount: 1_001)
        #expect(plan.isRefused)
        #expect(plan.refusal == .recordExceedsTotalLimit)
        #expect(plan.segmentsToDelete.isEmpty)
        #expect(plan.projectedTotalBytes == 500)
    }

    @Test func loneActiveSegmentOverTheBudgetRollsToAFreshSegment() {
        // The 900-byte segment reached the 400-byte trigger, so the trigger
        // closes it and opens segment 5. The 1,050-byte total then breaks
        // the 1,000-byte budget, and eviction removes the closed segment 4.
        let index = [DiagnosticsSegment(ordinal: 4, byteCount: 900)]
        let plan = rotation.plan(index: index, incomingByteCount: 150)
        #expect(plan.segmentsToDelete == ["000004.jsonl"])
        #expect(plan.segmentToOpen == 5)
        #expect(plan.targetSegmentName == "000005.jsonl")
        #expect(plan.projectedTotalBytes == 150)
        #expect(plan.projectedSegmentCount == 1)
    }

    /// The retire branch proper: the lone segment sits below the trigger,
    /// so nothing opens, and it alone breaks the budget. There is no closed
    /// segment to evict, so the active segment itself retires and a fresh
    /// segment takes the record.
    @Test func loneActiveSegmentBelowTheTriggerRetiresWhenItAloneBreaksTheBudget() {
        let retirePolicy = DiagnosticsRotationPolicy(
            totalByteLimit: 1_000, segmentByteTrigger: 900, maximumSegmentCount: 3
        )
        let index = [DiagnosticsSegment(ordinal: 4, byteCount: 800)]
        let plan = DiagnosticsRotation(policy: retirePolicy)
            .plan(index: index, incomingByteCount: 300)
        #expect(plan.segmentsToDelete == ["000004.jsonl"])
        #expect(plan.segmentToOpen == 5)
        #expect(plan.targetSegmentName == "000005.jsonl")
        #expect(plan.projectedTotalBytes == 300)
        #expect(plan.projectedSegmentCount == 1)
    }

    @Test func projectedIndexAppliesOpeningEvictionAndAppending() {
        let index = [
            DiagnosticsSegment(ordinal: 1, byteCount: 500),
            DiagnosticsSegment(ordinal: 2, byteCount: 300),
        ]
        let rotation = self.rotation
        let plan = rotation.plan(index: index, incomingByteCount: 300)
        #expect(plan.segmentsToDelete == ["000001.jsonl"])
        #expect(plan.targetSegmentName == "000002.jsonl")
        let projected = rotation.projectedIndex(
            after: plan, index: index, incomingByteCount: 300
        )
        #expect(projected.map(\.name) == ["000002.jsonl"])
        #expect(projected.map(\.byteCount) == [600])
        #expect(
            rotation.accountedTotalBytes(index: projected, incomingByteCount: 0) == 600
        )
    }

    @Test func endToEndWritesStayBoundedAcrossManyRecords() async throws {
        let store = MemoryDiagnosticsStore()
        var index: [DiagnosticsSegment] = []
        let rotation = self.rotation
        var totalAtWrite = UInt64(0)
        // Many records that individually exceed a tenth of the budget force
        // repeated eviction.
        for counter in 0..<200 {
            let line = String(repeating: "x", count: 60 + (counter % 7))
            let result = try await rotation.write(line: line, index: &index, store: store)
            guard case let .written(_, total) = result else {
                Issue.record("Expected a written record")
                return
            }
            totalAtWrite = total
            #expect(total <= policy.totalByteLimit)
            #expect(index.count <= policy.maximumSegmentCount)
        }
        #expect(totalAtWrite > 0)
        #expect(index.map(\.ordinal) == index.map(\.ordinal).sorted())
        let names = Set(index.map(\.name))
        let storeNames = await store.deletedNames
        #expect(storeNames.filter { names.contains($0) }.isEmpty)
    }

    @Test func refusedRecordLeavesTheStoreUntouched() async throws {
        let store = MemoryDiagnosticsStore()
        var index = [DiagnosticsSegment(ordinal: 1, byteCount: 100)]
        let oversized = String(repeating: "x", count: 1_100)
        let result = try await rotation.write(line: oversized, index: &index, store: store)
        #expect(result == .refused(.recordExceedsTotalLimit))
        #expect(index.map(\.byteCount) == [100])
        let created = await store.createdNames
        #expect(created.isEmpty)
    }
}
