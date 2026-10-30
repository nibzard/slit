import Foundation

/// A point on a monotonic clock. The origin is unspecified and app-local.
/// It is not wall-clock time and carries no date, so it cannot leak a
/// photograph timestamp into diagnostics.
public struct DiagnosticsInstant: Equatable, Comparable, Sendable {
    public let millisecondsSinceReference: Int64

    public init(millisecondsSinceReference: Int64) {
        self.millisecondsSinceReference = millisecondsSinceReference
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.millisecondsSinceReference < rhs.millisecondsSinceReference
    }

    /// Returns nil when the end precedes the start. A clock that moved
    /// backwards produces an unavailable measurement, not a fabricated zero.
    public static func duration(from start: Self, to end: Self) -> MonotonicDuration? {
        guard end >= start else { return nil }
        return MonotonicDuration(
            milliseconds: end.millisecondsSinceReference - start.millisecondsSinceReference
        )
    }
}

/// A measured duration in whole milliseconds. The unit is part of the name.
public struct MonotonicDuration: Equatable, Sendable {
    public let milliseconds: Int64

    public init(milliseconds: Int64) {
        self.milliseconds = milliseconds
    }
}

/// The only time source inside SlitCore diagnostics. Package logic never
/// reads a system clock, `Date`, or `ContinuousClock` directly; the app
/// injects one implementation at the ownership boundary. Tests inject a
/// stepped clock.
public protocol DiagnosticsClock: Sendable {
    /// Returns the current monotonic instant. Implementations must move
    /// forward only, but consumers still guard against regressions.
    func now() -> DiagnosticsInstant
}

/// Measures one phase between two `now()` readings of an injected clock.
/// A stopwatch that never stopped, or a clock that regressed, reports nil.
public struct MonotonicStopwatch: Equatable, Sendable {
    public let start: DiagnosticsInstant
    public private(set) var end: DiagnosticsInstant?

    public init(clock: any DiagnosticsClock) {
        start = clock.now()
    }

    public mutating func stop(clock: any DiagnosticsClock) {
        end = clock.now()
    }

    /// Unavailable measurements stay nil. The encoded record omits their
    /// keys; it never writes a fabricated zero.
    public var duration: MonotonicDuration? {
        guard let end else { return nil }
        return DiagnosticsInstant.duration(from: start, to: end)
    }
}

/// A clock for tests and previews. It never advances by itself. It is a
/// class, so every holder shares one time line: a clock stepped after a
/// recorder captured it still moves that recorder's stopwatches. The body
/// mutates only from the single test thread, hence unchecked sendability.
public final class ManualDiagnosticsClock: DiagnosticsClock, @unchecked Sendable {
    public private(set) var instant: DiagnosticsInstant

    public init(startMilliseconds: Int64 = 0) {
        instant = DiagnosticsInstant(millisecondsSinceReference: startMilliseconds)
    }

    public func now() -> DiagnosticsInstant { instant }

    public func advance(byMilliseconds milliseconds: Int64) {
        instant = DiagnosticsInstant(
            millisecondsSinceReference: instant.millisecondsSinceReference + milliseconds
        )
    }
}
