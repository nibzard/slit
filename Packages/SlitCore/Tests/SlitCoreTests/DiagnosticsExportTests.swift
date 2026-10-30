import Foundation
import Testing
@testable import SlitCore

struct DiagnosticsExportTests {
    /// The trigger enum has exactly one case, and it names the user action.
    /// Automatic export has no constructor path in this package.
    @Test func exportStartsOnlyFromTheUserShareAction() {
        let request = DiagnosticsExportRequest(
            trigger: .userSelectedShareDiagnostics
        )
        #expect(request.trigger == .userSelectedShareDiagnostics)
        #expect(diagnosticsExportFileName == "slit-diagnostics.jsonl")
        #expect(!diagnosticsExportFileName.contains("/"))
    }

    @Test func planListsSegmentsOldestFirstWithBoundedTotals() {
        let planner = DiagnosticsExportPlanner()
        let request = DiagnosticsExportRequest(trigger: .userSelectedShareDiagnostics)
        let index = [
            DiagnosticsSegment(ordinal: 2, byteCount: 300),
            DiagnosticsSegment(ordinal: 1, byteCount: 200),
            DiagnosticsSegment(ordinal: 3, byteCount: 100),
        ]
        let plan = planner.plan(request, index: index)
        #expect(plan.segmentNames == ["000001.jsonl", "000002.jsonl", "000003.jsonl"])
        #expect(plan.totalByteCount == 600)
        #expect(plan.byteLimit == 5 * 1_024 * 1_024)
    }

    @Test func emptyStorePlansAnEmptyExport() {
        let planner = DiagnosticsExportPlanner()
        let request = DiagnosticsExportRequest(trigger: .userSelectedShareDiagnostics)
        let plan = planner.plan(request, index: [])
        #expect(plan.segmentNames.isEmpty)
        #expect(plan.totalByteCount == 0)
    }

    /// An index above the byte budget exports only the newest segments that
    /// fit. The oldest drop first, the same order as eviction, and planning
    /// never traps.
    @Test func indexOverTheByteBudgetDropsOldestSegmentsUntilItFits() {
        let policy = DiagnosticsRotationPolicy(
            totalByteLimit: 1_000, segmentByteTrigger: 400, maximumSegmentCount: 20
        )
        let planner = DiagnosticsExportPlanner(policy: policy)
        let request = DiagnosticsExportRequest(trigger: .userSelectedShareDiagnostics)
        let index = [
            DiagnosticsSegment(ordinal: 1, byteCount: 600),
            DiagnosticsSegment(ordinal: 2, byteCount: 500),
            DiagnosticsSegment(ordinal: 3, byteCount: 100),
        ]
        // The 1,200-byte total breaks the budget. Dropping segment 1 leaves
        // 600 bytes, which fits.
        let plan = planner.plan(request, index: index)
        #expect(plan.segmentNames == ["000002.jsonl", "000003.jsonl"])
        #expect(plan.totalByteCount == 600)
        #expect(plan.totalByteCount <= plan.byteLimit)
    }

    /// A lone segment above the whole budget exports nothing rather than a
    /// payload that breaks the byte ceiling.
    @Test func loneSegmentOverTheWholeBudgetExportsNothing() {
        let policy = DiagnosticsRotationPolicy(
            totalByteLimit: 1_000, segmentByteTrigger: 400, maximumSegmentCount: 20
        )
        let planner = DiagnosticsExportPlanner(policy: policy)
        let request = DiagnosticsExportRequest(trigger: .userSelectedShareDiagnostics)
        let index = [DiagnosticsSegment(ordinal: 3, byteCount: 1_200)]
        let plan = planner.plan(request, index: index)
        #expect(plan.segmentNames.isEmpty)
        #expect(plan.totalByteCount == 0)
        #expect(plan.totalByteCount <= plan.byteLimit)
    }
}
