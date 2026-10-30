import Foundation

/// Assigns monotonic sequence numbers and builds events from an injected
/// clock. The recorder holds no queue, file, or platform object. The app
/// owns one recorder per process and forwards sealed events to its bounded
/// store.
public struct DiagnosticsRecorder: Sendable {
    public let clock: any DiagnosticsClock
    public private(set) var nextSequence: UInt64

    public init(clock: any DiagnosticsClock) {
        self.clock = clock
        nextSequence = 1
    }

    /// Fills in the event's sequence number and advances the counter.
    /// Sealing the same event twice renumbers it; callers seal once.
    public mutating func seal(_ event: DiagnosticsEvent) -> DiagnosticsEvent {
        var sealed = event
        sealed.sequence = nextSequence
        nextSequence += 1
        return sealed
    }

    /// Starts one phase measurement now.
    public func stopwatch() -> MonotonicStopwatch {
        MonotonicStopwatch(clock: clock)
    }

    // MARK: Duration events

    /// Cold start: launch instrumentation to a visible preview and an
    /// eligible shutter.
    public mutating func coldStart(
        _ stopwatch: MonotonicStopwatch, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .phaseDuration, metric: .coldStart,
            durationMilliseconds: stopwatch.duration?.milliseconds,
            sessionId: sessionId
        ))
    }

    /// Warm resume: foreground activation to a visible preview and an
    /// eligible shutter.
    public mutating func warmResume(
        _ stopwatch: MonotonicStopwatch, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .phaseDuration, metric: .warmResume,
            durationMilliseconds: stopwatch.duration?.milliseconds,
            sessionId: sessionId
        ))
    }

    /// Request overhead: input handler entry to the photo capture request
    /// call.
    public mutating func requestOverhead(
        _ stopwatch: MonotonicStopwatch, captureId: UUID?, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .phaseDuration, metric: .requestOverhead,
            durationMilliseconds: stopwatch.duration?.milliseconds,
            captureId: captureId, sessionId: sessionId
        ))
    }

    /// Acceptance feedback: accepted input to visible feedback beginning.
    public mutating func acceptanceFeedback(
        _ stopwatch: MonotonicStopwatch, captureId: UUID?, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .phaseDuration, metric: .acceptanceFeedback,
            durationMilliseconds: stopwatch.duration?.milliseconds,
            captureId: captureId, sessionId: sessionId
        ))
    }

    /// Callback latency: input to the named platform callback. A proxy for
    /// pipeline responsiveness, not exact exposure time.
    public mutating func callbackLatency(
        _ stopwatch: MonotonicStopwatch, phase: DiagnosticsEvent.CallbackPhase,
        captureId: UUID?, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .phaseDuration, metric: .callbackLatency,
            callbackPhase: phase,
            durationMilliseconds: stopwatch.duration?.milliseconds,
            captureId: captureId, sessionId: sessionId
        ))
    }

    /// Storage latency: complete raw delivery to bundle commit.
    public mutating func storageLatency(
        _ stopwatch: MonotonicStopwatch, captureId: UUID?, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .phaseDuration, metric: .storageLatency,
            durationMilliseconds: stopwatch.duration?.milliseconds,
            captureId: captureId, sessionId: sessionId
        ))
    }

    /// Backlog drain: last accepted request to all remaining successful
    /// commits or explicit failures. `pendingCount` is the depth that
    /// remained at the end of the drain, normally zero.
    public mutating func backlogDrain(
        _ stopwatch: MonotonicStopwatch, pendingCount: Int,
        captureId: UUID?, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .phaseDuration, metric: .backlogDrain,
            durationMilliseconds: stopwatch.duration?.milliseconds,
            captureId: captureId, sessionId: sessionId,
            pendingCount: pendingCount
        ))
    }

    // MARK: Count and context events

    /// One application-observed attempt. Rejected attempts carry a category
    /// and no capture identifier, because admission never reserved one.
    public mutating func attempt(
        input: DiagnosticsEvent.InputSource,
        outcome: DiagnosticsEvent.AttemptOutcome,
        rejection: DiagnosticsEvent.RejectionCategory? = nil,
        captureId: UUID? = nil,
        sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .attempt, captureId: captureId, sessionId: sessionId,
            input: input, outcome: outcome, rejectionCategory: rejection
        ))
    }

    /// The slot limit and occupancy at this moment, including retained
    /// failed saves.
    public mutating func queueLimits(
        limit: Int, occupied: Int, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .queueLimits, sessionId: sessionId,
            queueLimit: limit, occupiedSlots: occupied
        ))
    }

    /// One configuration snapshot for the run ahead.
    public mutating func configuration(
        _ snapshot: DiagnosticsEvent.Configuration, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .configurationSnapshot, sessionId: sessionId,
            configuration: snapshot
        ))
    }

    /// A thermal state transition or the state observed at a boundary.
    public mutating func thermal(
        _ state: DiagnosticsEvent.ThermalState, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .thermalState, sessionId: sessionId, thermalState: state
        ))
    }

    /// Resource use: peak memory, pending saves, and preview stalls.
    public mutating func resourceUse(
        peakMemoryBytes: UInt64,
        pendingCount: Int,
        occupiedSlots: Int,
        previewStallCount: UInt64,
        thermalState: DiagnosticsEvent.ThermalState,
        sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .resourceUse, sessionId: sessionId,
            pendingCount: pendingCount, occupiedSlots: occupiedSlots,
            peakMemoryBytes: peakMemoryBytes,
            previewStallCount: previewStallCount,
            thermalState: thermalState
        ))
    }

    /// Records a terminal failure with its code. The failure keeps its own
    /// event so rejection counts and failure counts stay separate.
    public mutating func failure(
        code: DiagnosticsEvent.FailureCode,
        captureId: UUID?, sessionId: UUID?
    ) -> DiagnosticsEvent {
        seal(DiagnosticsEvent(
            kind: .attempt, captureId: captureId, sessionId: sessionId,
            failureCode: code
        ))
    }
}
