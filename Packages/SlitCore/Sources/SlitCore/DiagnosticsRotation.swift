import Foundation

/// One segment of the diagnostics log. The name derives from the creation
/// ordinal and is always relative to the diagnostics cache directory, so no
/// absolute path can enter the index.
public struct DiagnosticsSegment: Equatable, Codable, Sendable {
    public let ordinal: UInt64
    public let byteCount: UInt64

    public init(ordinal: UInt64, byteCount: UInt64) {
        self.ordinal = ordinal
        self.byteCount = byteCount
    }

    public var name: String {
        let digits = String(ordinal)
        let padding = Swift.max(0, 6 - digits.count)
        return String(repeating: "0", count: padding) + digits + ".jsonl"
    }
}

/// The bounded rotation rules for the diagnostics store. The total limit
/// matches the specification's initial 5 MiB budget.
public struct DiagnosticsRotationPolicy: Equatable, Sendable {
    /// Aggregate ceiling across every segment, including the incoming record.
    public let totalByteLimit: UInt64
    /// The size trigger that rolls the active segment to a new file.
    public let segmentByteTrigger: UInt64
    /// The file count cap. Eviction enforces it even when bytes fit.
    public let maximumSegmentCount: Int

    /// The initial limits. Twenty segments of 256 KiB fill the 5 MiB budget.
    public static let standard = DiagnosticsRotationPolicy(
        totalByteLimit: UInt64(SlitDefaults.diagnosticLimitBytes),
        segmentByteTrigger: 256 * 1_024,
        maximumSegmentCount: 20
    )

    public init(totalByteLimit: UInt64, segmentByteTrigger: UInt64, maximumSegmentCount: Int) {
        precondition(totalByteLimit > 0, "A zero byte budget stores nothing")
        precondition(segmentByteTrigger > 0, "A zero segment trigger rolls every record")
        precondition(maximumSegmentCount > 0, "A zero segment cap evicts every file")
        self.totalByteLimit = totalByteLimit
        self.segmentByteTrigger = segmentByteTrigger
        self.maximumSegmentCount = maximumSegmentCount
    }
}

/// The file operations the app performs over `Caches/Slit/diagnostics`.
/// The planner is pure and never touches the filesystem; only this
/// protocol does.
public protocol DiagnosticsSegmentStore: Sendable {
    /// Creates one empty segment. It must fail when the name already exists.
    func createSegment(named name: String) async throws
    /// Deletes segment files, oldest first. Names are relative.
    func deleteSegments(named names: [String]) async throws
    /// Appends one line and its newline, then returns the segment's new
    /// total byte count.
    func append(line: String, to segment: String) async throws -> UInt64
}

/// What rotation does before one record is written.
public struct DiagnosticsRotationPlan: Equatable, Sendable {
    public enum Refusal: String, Equatable, Sendable {
        /// The record alone exceeds the whole byte budget. It is dropped,
        /// and the store never evicts everything to admit one line.
        case recordExceedsTotalLimit
    }

    /// The new segment to create, when the size trigger fired or the index
    /// is empty.
    public let segmentToOpen: UInt64?
    /// Segments to delete, oldest first.
    public let segmentsToDelete: [String]
    /// The active segment that receives the record.
    public let targetSegmentName: String
    public let isRefused: Bool
    public let refusal: Refusal?
    public let projectedTotalBytes: UInt64
    public let projectedSegmentCount: Int

    public init(
        segmentToOpen: UInt64?,
        segmentsToDelete: [String],
        targetSegmentName: String,
        isRefused: Bool,
        refusal: Refusal?,
        projectedTotalBytes: UInt64,
        projectedSegmentCount: Int
    ) {
        self.segmentToOpen = segmentToOpen
        self.segmentsToDelete = segmentsToDelete
        self.targetSegmentName = targetSegmentName
        self.isRefused = isRefused
        self.refusal = refusal
        self.projectedTotalBytes = projectedTotalBytes
        self.projectedSegmentCount = projectedSegmentCount
    }
}

/// Plans and applies bounded rotation. Planning is a pure function over an
/// in-memory index; applying goes through the store protocol and returns the
/// updated index.
public struct DiagnosticsRotation: Sendable {
    public let policy: DiagnosticsRotationPolicy

    public init(policy: DiagnosticsRotationPolicy = .standard) {
        self.policy = policy
    }

    /// Aggregate accounting: the sum of all segment byte counts in the index
    /// plus the incoming record.
    public func accountedTotalBytes(index: [DiagnosticsSegment], incomingByteCount: UInt64) -> UInt64 {
        index.reduce(into: incomingByteCount) { total, segment in
            total += segment.byteCount
        }
    }

    /// Pure rotation planning. The caller passes the index sorted or
    /// unsorted; ordering uses the creation ordinal, not array position.
    public func plan(index: [DiagnosticsSegment], incomingByteCount: UInt64) -> DiagnosticsRotationPlan {
        let ascending = index.sorted { $0.ordinal < $1.ordinal }
        let newest = ascending.last

        // A record that cannot fit even in an empty store is refused. It is
        // dropped rather than forcing deletion of every existing segment.
        if incomingByteCount > policy.totalByteLimit {
            let current = ascending.reduce(UInt64(0)) { $0 + $1.byteCount }
            return DiagnosticsRotationPlan(
                segmentToOpen: nil,
                segmentsToDelete: [],
                targetSegmentName: newest?.name ?? "000001.jsonl",
                isRefused: true,
                refusal: .recordExceedsTotalLimit,
                projectedTotalBytes: current,
                projectedSegmentCount: ascending.count
            )
        }

        var working = ascending
        var deletions: [String] = []
        var openedOrdinal: UInt64?

        if let newest {
            // The size trigger closes the active segment and starts a new
            // one. Closing does not delete; only the limits delete.
            if newest.byteCount >= policy.segmentByteTrigger {
                openedOrdinal = newest.ordinal + 1
                working.append(DiagnosticsSegment(ordinal: openedOrdinal!, byteCount: 0))
            }
        } else {
            openedOrdinal = 1
            working.append(DiagnosticsSegment(ordinal: 1, byteCount: 0))
        }

        // Account for the incoming record, then evict oldest first until
        // both the byte budget and the count cap hold. The active segment
        // is never evicted to make room while closed segments remain. When
        // the active segment alone still breaks the byte budget, it is
        // deleted and a fresh segment takes the record. A fresh segment
        // holds only the incoming record, which the refusal check above
        // already fits inside the budget, so eviction terminates.
        var projected = working.reduce(UInt64(0)) { $0 + $1.byteCount } + incomingByteCount
        while projected > policy.totalByteLimit || working.count > policy.maximumSegmentCount {
            if working.count > 1 {
                let oldest = working.removeFirst()
                deletions.append(oldest.name)
                projected = projected >= oldest.byteCount
                    ? projected - oldest.byteCount
                    : 0
            } else {
                let retired = working.removeLast()
                deletions.append(retired.name)
                openedOrdinal = retired.ordinal + 1
                working.append(DiagnosticsSegment(ordinal: openedOrdinal!, byteCount: 0))
                projected = incomingByteCount
            }
        }

        guard let target = working.last else {
            preconditionFailure("Planning always leaves one active segment")
        }

        return DiagnosticsRotationPlan(
            segmentToOpen: openedOrdinal,
            segmentsToDelete: deletions,
            targetSegmentName: target.name,
            isRefused: false,
            refusal: nil,
            projectedTotalBytes: projected,
            projectedSegmentCount: working.count
        )
    }

    /// The index after a plan is applied and one record of
    /// `incomingByteCount` bytes is appended to the target segment.
    public func projectedIndex(
        after plan: DiagnosticsRotationPlan,
        index: [DiagnosticsSegment],
        incomingByteCount: UInt64
    ) -> [DiagnosticsSegment] {
        var updated = index.filter { segment in
            !plan.segmentsToDelete.contains(segment.name)
        }
        if let ordinal = plan.segmentToOpen {
            updated.append(DiagnosticsSegment(ordinal: ordinal, byteCount: 0))
        }
        guard !plan.isRefused,
              let position = updated.lastIndex(where: { $0.name == plan.targetSegmentName })
        else { return updated.sorted { $0.ordinal < $1.ordinal } }
        updated[position] = DiagnosticsSegment(
            ordinal: updated[position].ordinal,
            byteCount: updated[position].byteCount + incomingByteCount
        )
        return updated.sorted { $0.ordinal < $1.ordinal }
    }

    /// Applies a plan through the store, appends one line, and returns the
    /// updated index and outcome. Store failures propagate; a failed apply
    /// leaves index maintenance to the caller.
    public func write(
        line: String,
        index: inout [DiagnosticsSegment],
        store: any DiagnosticsSegmentStore
    ) async throws -> DiagnosticsWriteResult {
        // The record accounts for its trailing newline.
        let incoming = UInt64(line.utf8.count) + 1
        let plan = self.plan(index: index, incomingByteCount: incoming)
        if plan.isRefused {
            return .refused(plan.refusal ?? .recordExceedsTotalLimit)
        }
        if let ordinal = plan.segmentToOpen {
            let segment = DiagnosticsSegment(ordinal: ordinal, byteCount: 0)
            try await store.createSegment(named: segment.name)
            index.append(segment)
        }
        if !plan.segmentsToDelete.isEmpty {
            try await store.deleteSegments(named: plan.segmentsToDelete)
            let names = Set(plan.segmentsToDelete)
            index.removeAll { names.contains($0.name) }
        }
        let byteCount = try await store.append(line: line, to: plan.targetSegmentName)
        if let position = index.lastIndex(where: { $0.name == plan.targetSegmentName }) {
            index[position] = DiagnosticsSegment(
                ordinal: index[position].ordinal, byteCount: byteCount
            )
        } else {
            index.append(DiagnosticsSegment(
                ordinal: plan.segmentToOpen ?? 1, byteCount: byteCount
            ))
        }
        index.sort { $0.ordinal < $1.ordinal }
        return .written(
            segmentName: plan.targetSegmentName,
            totalBytes: accountedTotalBytes(index: index, incomingByteCount: 0)
        )
    }
}

/// The result of one bounded write.
public enum DiagnosticsWriteResult: Equatable, Sendable {
    case written(segmentName: String, totalBytes: UInt64)
    case refused(DiagnosticsRotationPlan.Refusal)
}
