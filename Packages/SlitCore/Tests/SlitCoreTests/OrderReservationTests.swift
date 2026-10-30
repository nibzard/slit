import Foundation
import Testing
@testable import SlitCore

/// An in-memory `OrderReservationStore` for termination-boundary tests.
/// A confirmed replace models an atomic file replacement. An injected
/// failure models a torn write: the attempt is recorded, the previous
/// record stays in place, and the caller sees an error.
actor FakeOrderReservationStore: OrderReservationStore {
    struct InjectedFailure: Error { let attempt: Int }

    private(set) var confirmed: OrderHighWatermarkRecord?
    private(set) var attempted: [OrderHighWatermarkRecord] = []
    private(set) var confirmedReplacements = 0
    private var failuresToInject = 0

    func seed(_ record: OrderHighWatermarkRecord) {
        confirmed = record
    }

    func injectFailure(onNextReplacements count: Int) {
        failuresToInject = count
    }

    func load() throws -> OrderHighWatermarkRecord? {
        confirmed
    }

    func replace(_ record: OrderHighWatermarkRecord) throws {
        attempted.append(record)
        guard failuresToInject > 0 else {
            confirmed = record
            confirmedReplacements += 1
            return
        }
        failuresToInject -= 1
        throw InjectedFailure(attempt: attempted.count)
    }
}

/// Durable-order allocation across termination boundaries. Every fixture is
/// synthetic; no file or device is involved.
struct OrderReservationTests {
    @Test func reservationConfirmsTheHighWatermarkBeforeReturningValues() async throws {
        let store = FakeOrderReservationStore()
        var allocator = OrderAllocator(store: store)
        let block = try await allocator.recover(
            highestCommitted: nil, highestRecoverable: nil, reserveCount: 4
        )
        #expect(block.values == LibraryOrder(1)...LibraryOrder(4))
        let confirmed = await store.confirmed
        #expect(confirmed == OrderHighWatermarkRecord(
            schemaVersion: SlitDefaults.orderHighWatermarkSchemaVersion, highestReserved: 4
        ))
        let confirmedReplacements = await store.confirmedReplacements
        #expect(confirmedReplacements == 1)
    }

    @Test func consumptionDrawsFromTheReservedBlockThenRejectsExplicitly() async throws {
        let store = FakeOrderReservationStore()
        var allocator = OrderAllocator(store: store)
        _ = try await allocator.recover(
            highestCommitted: nil, highestRecoverable: nil, reserveCount: 2
        )
        #expect(try allocator.consumeNextOrder() == LibraryOrder(1))
        #expect(try allocator.consumeNextOrder() == LibraryOrder(2))
        #expect(throws: OrderReservationFailure.exhausted) {
            try allocator.consumeNextOrder()
        }
        // Exhaustion is an in-memory rejection. No reservation write runs.
        let attempted = await store.attempted
        #expect(attempted.count == 1)
        #expect(allocator.isExhausted)
    }

    @Test func consumptionBeforeRecoveryIsRejectedExplicitly() {
        let store = FakeOrderReservationStore()
        var allocator = OrderAllocator(store: store)
        #expect(throws: OrderReservationFailure.notInitialized) {
            try allocator.consumeNextOrder()
        }
    }

    @Test func aCountBelowOneCannotReserveAnyValue() async throws {
        let store = FakeOrderReservationStore()
        var allocator = OrderAllocator(store: store)
        await #expect(throws: OrderReservationFailure.invalidCount(0)) {
            try await allocator.recover(
                highestCommitted: nil, highestRecoverable: nil, reserveCount: 0
            )
        }
        let attempted = await store.attempted
        #expect(attempted.isEmpty)
    }

    /// A background refill extends above the persisted high-watermark. Values
    /// of the earlier block that were not consumed remain consumable.
    @Test func refillBeforeExhaustionExtendsAboveThePersistedHighWatermark() async throws {
        let store = FakeOrderReservationStore()
        var allocator = OrderAllocator(store: store)
        _ = try await allocator.recover(
            highestCommitted: nil, highestRecoverable: nil, reserveCount: 4
        )
        _ = try allocator.consumeNextOrder()
        _ = try allocator.consumeNextOrder()
        #expect(allocator.availableReservedCount == 2)

        let extensionBlock = try await allocator.reserve(count: 4)
        #expect(extensionBlock.values == LibraryOrder(5)...LibraryOrder(8))
        let confirmed = await store.confirmed
        #expect(confirmed?.highestReserved == 8)

        var consumed: [LibraryOrder] = []
        while !allocator.isExhausted {
            consumed.append(try allocator.consumeNextOrder())
        }
        #expect(consumed.map(\.value) == [3, 4, 5, 6, 7, 8])
    }

    /// A torn high-watermark replacement hands out no value. The retry
    /// reserves the same range safely because nothing was returned before.
    @Test func tornWriteConfirmsNothingAndKeepsThePreviousFloor() async throws {
        let store = FakeOrderReservationStore()
        await store.seed(OrderHighWatermarkRecord(
            schemaVersion: SlitDefaults.orderHighWatermarkSchemaVersion, highestReserved: 10
        ))
        await store.injectFailure(onNextReplacements: 1)
        var allocator = OrderAllocator(store: store)
        do {
            _ = try await allocator.recover(
                highestCommitted: nil, highestRecoverable: nil, reserveCount: 2
            )
            Issue.record("Expected a store failure")
            return
        } catch let error as OrderReservationFailure {
            guard case let .store(service) = error else {
                Issue.record("Expected a store failure, got \(error)")
                return
            }
            #expect(service.code == "order.high-watermark.replace")
        }
        #expect(allocator.availableReservedCount == 0)
        #expect(throws: OrderReservationFailure.notInitialized) {
            try allocator.consumeNextOrder()
        }
        // The torn attempt targeted 12 but confirmed nothing. The persisted
        // record still holds 10, so the retry reserves 11 and 12.
        let confirmedAfterTornWrite = await store.confirmed
        #expect(confirmedAfterTornWrite?.highestReserved == 10)
        let attempted = await store.attempted
        #expect(attempted.count == 1)

        let block = try await allocator.recover(
            highestCommitted: nil, highestRecoverable: nil, reserveCount: 2
        )
        #expect(block.values == LibraryOrder(11)...LibraryOrder(12))
        #expect(try allocator.consumeNextOrder() == LibraryOrder(11))
        #expect(try allocator.consumeNextOrder() == LibraryOrder(12))
    }

    /// Recovery resumes above the largest committed, recoverable, and
    /// reserved value. A stale reservation file cannot cause reuse.
    @Test func recoveryResumesAboveCommittedRecoverableAndReservedValues() async throws {
        let store = FakeOrderReservationStore()
        await store.seed(OrderHighWatermarkRecord(
            schemaVersion: SlitDefaults.orderHighWatermarkSchemaVersion, highestReserved: 5
        ))
        var allocator = OrderAllocator(store: store)
        let block = try await allocator.recover(
            highestCommitted: LibraryOrder(10),
            highestRecoverable: LibraryOrder(12),
            reserveCount: 4
        )
        #expect(block.values.lowerBound.value > 12)
        #expect(block.values.lowerBound.value > 10)
        #expect(block.values.lowerBound.value > 5)
        #expect(block.values == LibraryOrder(13)...LibraryOrder(16))
        let confirmed = await store.confirmed
        #expect(confirmed?.highestReserved == 16)
    }

    /// Termination between the persisted replacement and consumption leaves
    /// the whole block unused. A later allocator never reuses those values.
    @Test func crashAfterPersistButBeforeConsumptionNeverReusesValues() async throws {
        let store = FakeOrderReservationStore()
        var first = OrderAllocator(store: store)
        _ = try await first.recover(highestCommitted: nil, highestRecoverable: nil, reserveCount: 8)
        var beforeCrash: [LibraryOrder] = []
        for _ in 0..<3 { beforeCrash.append(try first.consumeNextOrder()) }

        var second = OrderAllocator(store: store)
        let block = try await second.recover(
            highestCommitted: beforeCrash.last, highestRecoverable: nil, reserveCount: 4
        )
        #expect(block.values == LibraryOrder(9)...LibraryOrder(12))
        var afterCrash: [LibraryOrder] = []
        for _ in 0..<2 { afterCrash.append(try second.consumeNextOrder()) }

        let all = beforeCrash + afterCrash
        #expect(Set(all.map(\.value)).count == all.count)
        #expect(afterCrash.allSatisfy { $0.value > 8 })
    }

    /// Repeated recovery in one process allocates disjoint blocks. The
    /// persisted high-watermark is one of the compared categories.
    @Test func recoveryRunTwiceAllocatesDisjointBlocksWithNoDuplicates() async throws {
        let store = FakeOrderReservationStore()
        var allocator = OrderAllocator(store: store)
        let first = try await allocator.recover(
            highestCommitted: nil, highestRecoverable: nil, reserveCount: 4
        )
        let second = try await allocator.recover(
            highestCommitted: nil, highestRecoverable: nil, reserveCount: 4
        )
        #expect(first.values == LibraryOrder(1)...LibraryOrder(4))
        #expect(second.values == LibraryOrder(5)...LibraryOrder(8))
        #expect(first.values.upperBound < second.values.lowerBound)

        var consumed: [LibraryOrder] = []
        while !allocator.isExhausted {
            consumed.append(try allocator.consumeNextOrder())
        }
        #expect(consumed.map(\.value) == [1, 2, 3, 4, 5, 6, 7, 8])
        #expect(Set(consumed.map(\.value)).count == consumed.count)
    }

    /// The reservation fails explicitly at the top of the 64-bit order space.
    /// No value wraps around to a small order.
    @Test func overflowFailsExplicitlyWithoutWraparound() async throws {
        let store = FakeOrderReservationStore()
        await store.seed(OrderHighWatermarkRecord(
            schemaVersion: SlitDefaults.orderHighWatermarkSchemaVersion, highestReserved: UInt64.max - 2
        ))
        var allocator = OrderAllocator(store: store)
        await #expect(throws: OrderReservationFailure.overflow(from: UInt64.max - 2, count: 5)) {
            try await allocator.recover(
                highestCommitted: nil, highestRecoverable: nil, reserveCount: 5
            )
        }
        // Three values above a floor of `UInt64.max - 2` still cross the top,
        // so this count fails too.
        await #expect(throws: OrderReservationFailure.overflow(from: UInt64.max - 2, count: 3)) {
            try await allocator.recover(
                highestCommitted: nil, highestRecoverable: nil, reserveCount: 3
            )
        }
        let attempted = await store.attempted
        #expect(attempted.isEmpty)

        // Two values are exactly what remains: `max - 1` and `max`.
        let block = try await allocator.recover(
            highestCommitted: nil, highestRecoverable: nil, reserveCount: 2
        )
        #expect(block.values == LibraryOrder(UInt64.max - 1)...LibraryOrder(UInt64.max))
        #expect(try allocator.consumeNextOrder() == LibraryOrder(UInt64.max - 1))
        #expect(try allocator.consumeNextOrder() == LibraryOrder(UInt64.max))
        #expect(throws: OrderReservationFailure.exhausted) {
            try allocator.consumeNextOrder()
        }
        await #expect(throws: OrderReservationFailure.overflow(from: UInt64.max, count: 1)) {
            try await allocator.reserve(count: 1)
        }
    }

    /// A persisted record from a different schema version fails the load by
    /// name. The allocator never misreads such a file as a low floor.
    @Test func mismatchedHighWatermarkSchemaVersionFailsTheLoad() async throws {
        let store = FakeOrderReservationStore()
        await store.seed(OrderHighWatermarkRecord(
            schemaVersion: SlitDefaults.orderHighWatermarkSchemaVersion + 1, highestReserved: 10
        ))
        var allocator = OrderAllocator(store: store)
        await #expect(throws: OrderReservationFailure.store(ServiceFailure(
            code: "order.high-watermark.schema",
            message: "Found schema version \(SlitDefaults.orderHighWatermarkSchemaVersion + 1); expected \(SlitDefaults.orderHighWatermarkSchemaVersion)"
        ))) {
            try await allocator.recover(
                highestCommitted: nil, highestRecoverable: nil, reserveCount: 4
            )
        }
        #expect(allocator.persistedThrough == nil)
        let attempted = await store.attempted
        #expect(attempted.isEmpty)
    }

    /// Consumption never performs file operations, so the shutter path cannot
    /// trigger a disk allocation.
    @Test func consumptionPerformsNoStoreOperations() async throws {
        let store = FakeOrderReservationStore()
        var allocator = OrderAllocator(store: store)
        _ = try await allocator.recover(
            highestCommitted: nil, highestRecoverable: nil, reserveCount: 3
        )
        _ = try allocator.consumeNextOrder()
        _ = try allocator.consumeNextOrder()
        let confirmedReplacements = await store.confirmedReplacements
        #expect(confirmedReplacements == 1)
        let attempted = await store.attempted
        #expect(attempted.count == 1)
    }
}
