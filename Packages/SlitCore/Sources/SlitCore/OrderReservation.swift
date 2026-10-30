import Foundation

/// The persisted content of `order-high-watermark.json`.
/// The file records the highest reserved library-order value, whether or not
/// that value was consumed or committed. It is not rebuildable from committed
/// bundles alone, because reserved values can outlive them.
public struct OrderHighWatermarkRecord: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let highestReserved: UInt64

    public init(schemaVersion: Int, highestReserved: UInt64) {
        self.schemaVersion = schemaVersion
        self.highestReserved = highestReserved
    }
}

/// File operations for the durable order reservation. The App storage worker
/// implements this protocol in T008; the SlitCore package performs no file I/O.
/// `replace` must durably install the new record before it returns, using the
/// same atomic-replacement rule as bundle commits. A failed or torn replace
/// must throw and leave the previous record in place.
public protocol OrderReservationStore: Sendable {
    /// Return the persisted record, or nil when no reservation file exists.
    func load() async throws -> OrderHighWatermarkRecord?
    /// Atomically replace the persisted record.
    func replace(_ record: OrderHighWatermarkRecord) async throws
}

/// Every failure the durable order allocator reports.
/// `exhausted` is the typed rejection for capture admission: it means no safe
/// reserved value remains. The camera owner rejects the request briefly and
/// never allocates a value on the shutter path.
public enum OrderReservationFailure: Error, Equatable, Sendable {
    /// Every reserved value in the current block is consumed.
    /// Reserve a new block in the background, then admit capture again.
    case exhausted
    /// The allocator has no reserved block yet. Run recovery at launch first.
    case notInitialized
    /// A reservation count below one cannot reserve any value.
    case invalidCount(UInt64)
    /// The reservation would pass the highest 64-bit library order.
    /// The failure is explicit; the value never wraps around to zero.
    case overflow(from: UInt64, count: UInt64)
    /// The store did not confirm the high-watermark replacement.
    /// No value from the unconfirmed replacement can be handed out.
    case store(ServiceFailure)
}

/// A durable library-order allocator owned by one serial executor.
/// It is a value type, like `CaptureAdmission`; only its owning executor may
/// mutate the authoritative instance.
///
/// The store persists every new high-watermark before any new value becomes
/// consumable. Termination at any boundary therefore leaves gaps at worst,
/// never a reused value. Recovery resumes above the largest committed,
/// recoverable, and reserved value.
public struct OrderAllocator: Sendable {
    private let store: any OrderReservationStore
    /// The next value this process may consume, or nil when the final value
    /// of a block was consumed or no block is reserved yet.
    public private(set) var nextUnconsumed: LibraryOrder?
    /// The highest value in the current reserved block.
    public private(set) var reservedThrough: LibraryOrder?
    /// The highest value the store has confirmed, or nil before recovery.
    public private(set) var persistedThrough: UInt64?

    public init(store: any OrderReservationStore) {
        self.store = store
    }

    /// The number of values this process can still consume without new I/O.
    public var availableReservedCount: UInt64 {
        guard let next = nextUnconsumed, let through = reservedThrough, next <= through else {
            return 0
        }
        let span = through.value - next.value
        return span == UInt64.max ? UInt64.max : span + 1
    }

    public var isExhausted: Bool {
        availableReservedCount == 0
    }

    /// Resume above every known order and reserve the first block.
    /// Call once at launch, after reconciliation reports the highest committed
    /// and recoverable orders. Repeated calls remain safe: the persisted
    /// high-watermark is one of the compared categories, so a second recovery
    /// reserves above the first.
    public mutating func recover(
        highestCommitted: LibraryOrder?,
        highestRecoverable: LibraryOrder?,
        reserveCount: UInt64
    ) async throws -> ReservedOrderBlock {
        let floor = max(
            max(highestCommitted?.value ?? 0, highestRecoverable?.value ?? 0),
            try await loadPersistedThrough() ?? 0
        )
        return try await extendReservation(above: floor, count: reserveCount)
    }

    /// Reserve another block before the current one is exhausted.
    /// This call performs store I/O; keep it off the shutter path. Values of
    /// the current block that are not consumed remain consumable; gaps are valid.
    public mutating func reserve(count: UInt64) async throws -> ReservedOrderBlock {
        guard let persistedThrough else { throw OrderReservationFailure.notInitialized }
        return try await extendReservation(above: persistedThrough, count: count)
    }

    /// Return the next reserved value from memory. No disk allocation runs
    /// here. Throws `exhausted` when no safe reserved value remains; reject
    /// the admission briefly in that case and refill in the background.
    public mutating func consumeNextOrder() throws -> LibraryOrder {
        guard let next = nextUnconsumed, let through = reservedThrough, next <= through else {
            if persistedThrough == nil { throw OrderReservationFailure.notInitialized }
            throw OrderReservationFailure.exhausted
        }
        if next.value == UInt64.max {
            nextUnconsumed = nil
        } else {
            nextUnconsumed = LibraryOrder(next.value + 1)
        }
        return next
    }

    /// Read the persisted high-watermark once. The allocator keeps the value
    /// in memory afterwards so consumption never performs file reads. A
    /// record written under a different schema version fails the store read
    /// by name; misreading it could rewind the high-watermark.
    private mutating func loadPersistedThrough() async throws -> UInt64? {
        if let persistedThrough { return persistedThrough }
        do {
            guard let record = try await store.load() else { return nil }
            guard record.schemaVersion == SlitDefaults.orderHighWatermarkSchemaVersion else {
                throw OrderReservationFailure.store(ServiceFailure(
                    code: "order.high-watermark.schema",
                    message: "Found schema version \(record.schemaVersion); expected \(SlitDefaults.orderHighWatermarkSchemaVersion)"
                ))
            }
            return record.highestReserved
        } catch let failure as OrderReservationFailure {
            throw failure
        } catch {
            throw OrderReservationFailure.store(
                ServiceFailure(code: "order.high-watermark.read", message: String(describing: error))
            )
        }
    }

    /// Persist first, then publish the new range. Nothing below returns a
    /// value the store has not confirmed, and an unconfirmed replacement
    /// leaves the in-memory cursor unchanged.
    private mutating func extendReservation(
        above floor: UInt64, count: UInt64
    ) async throws -> ReservedOrderBlock {
        guard count >= 1 else { throw OrderReservationFailure.invalidCount(count) }
        let upper = floor.addingReportingOverflow(count)
        guard !upper.overflow else { throw OrderReservationFailure.overflow(from: floor, count: count) }
        do {
            try await store.replace(
                OrderHighWatermarkRecord(
                    schemaVersion: SlitDefaults.orderHighWatermarkSchemaVersion,
                    highestReserved: upper.partialValue
                )
            )
        } catch {
            throw OrderReservationFailure.store(
                ServiceFailure(code: "order.high-watermark.replace", message: String(describing: error))
            )
        }
        persistedThrough = upper.partialValue
        reservedThrough = LibraryOrder(upper.partialValue)
        if nextUnconsumed == nil { nextUnconsumed = LibraryOrder(floor + 1) }
        return ReservedOrderBlock(values: LibraryOrder(floor + 1)...LibraryOrder(upper.partialValue))
    }
}
