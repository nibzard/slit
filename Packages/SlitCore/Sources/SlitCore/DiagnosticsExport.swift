import Foundation

/// The only way an export starts. The single case is the More screen's
/// Share diagnostics action, chosen by the user. There is no other
/// constructor path, no scheduler, and no network API in this package, so
/// records cannot leave the device except through this user action.
public enum DiagnosticsExportTrigger: Equatable, Sendable {
    case userSelectedShareDiagnostics
}

/// A user's explicit request to share the bounded diagnostics log.
public struct DiagnosticsExportRequest: Equatable, Sendable {
    public let trigger: DiagnosticsExportTrigger

    public init(trigger: DiagnosticsExportTrigger) {
        self.trigger = trigger
    }
}

/// What an export contains, derived from the current index. Segment names
/// are relative; the payload never carries absolute paths.
public struct DiagnosticsExportPlan: Equatable, Sendable {
    public let request: DiagnosticsExportRequest
    /// Oldest first, matching eviction order.
    public let segmentNames: [String]
    public let totalByteCount: UInt64
    /// The byte budget the payload respects. It equals the rotation policy
    /// limit, so an export can never exceed the store's own ceiling.
    public let byteLimit: UInt64

    /// `totalByteCount` must not exceed `byteLimit`. The planner guarantees
    /// this by dropping the oldest segments first; the initializer trusts
    /// its caller instead of trapping in release builds.
    public init(
        request: DiagnosticsExportRequest,
        segmentNames: [String],
        totalByteCount: UInt64,
        byteLimit: UInt64
    ) {
        self.request = request
        self.segmentNames = segmentNames
        self.totalByteCount = totalByteCount
        self.byteLimit = byteLimit
    }
}

/// The fixed, relative file name of an exported payload. It carries no
/// timestamp because package logic has no clock; the app may date the share
/// presentation, not this name.
public let diagnosticsExportFileName = "slit-diagnostics.jsonl"

/// Builds export plans from a rotation index. All functions are pure; the
/// app performs the actual file copy when the user confirms sharing.
public struct DiagnosticsExportPlanner: Sendable {
    public let policy: DiagnosticsRotationPolicy

    public init(policy: DiagnosticsRotationPolicy = .standard) {
        self.policy = policy
    }

    /// An empty store exports nothing. A store within the budget exports
    /// every segment that survives rotation, oldest first. An index that
    /// totals above the budget keeps its newest segments and drops the
    /// oldest first, the same order as eviction. A lone segment that alone
    /// breaks the budget is dropped too, so the payload never exceeds the
    /// ceiling even when that empties the export.
    public func plan(_ request: DiagnosticsExportRequest, index: [DiagnosticsSegment]) -> DiagnosticsExportPlan {
        var included = index.sorted { $0.ordinal < $1.ordinal }
        // `total` is always the exact sum of the bytes in `included`, so
        // subtracting an evicted segment's count cannot underflow.
        var total = included.reduce(UInt64(0)) { $0 + $1.byteCount }
        while total > policy.totalByteLimit && !included.isEmpty {
            total -= included.removeFirst().byteCount
        }
        return DiagnosticsExportPlan(
            request: request,
            segmentNames: included.map(\.name),
            totalByteCount: total,
            byteLimit: policy.totalByteLimit
        )
    }
}
