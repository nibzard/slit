import Foundation
import Testing
@testable import SlitCore

struct DiagnosticsEventTests {
    /// Collects every key in an encoded record, including nested objects.
    private func allKeys(in json: Any, into keys: inout Set<String>) {
        if let object = json as? [String: Any] {
            for (key, value) in object {
                keys.insert(key)
                allKeys(in: value, into: &keys)
            }
        } else if let array = json as? [Any] {
            for element in array {
                allKeys(in: element, into: &keys)
            }
        }
    }

    @Test func stopwatchMeasuresThroughTheInjectedClockOnly() {
        var clock = ManualDiagnosticsClock(startMilliseconds: 1_000)
        var stopwatch = MonotonicStopwatch(clock: clock)
        clock.advance(byMilliseconds: 37)
        stopwatch.stop(clock: clock)
        #expect(stopwatch.duration?.milliseconds == 37)
    }

    @Test func regressedClockProducesNullDurationNotZero() {
        var clock = ManualDiagnosticsClock(startMilliseconds: 5_000)
        var stopwatch = MonotonicStopwatch(clock: clock)
        clock.advance(byMilliseconds: -100)
        stopwatch.stop(clock: clock)
        #expect(stopwatch.duration == nil)
        let event = DiagnosticsEvent(
            kind: .phaseDuration, metric: .requestOverhead,
            durationMilliseconds: stopwatch.duration?.milliseconds
        )
        #expect(event.durationMilliseconds == nil)
    }

    @Test func unstoppedStopwatchStaysUnavailable() {
        let clock = ManualDiagnosticsClock()
        let stopwatch = MonotonicStopwatch(clock: clock)
        #expect(stopwatch.duration == nil)
    }

    /// The encoded form can only contain keys from the closed allowlist.
    /// No pixel, location, photograph name, or path field exists.
    @Test func encodedKeysStayInsideTheClosedAllowlist() throws {
        let event = DiagnosticsEvent(
            sequence: 42,
            kind: .phaseDuration,
            metric: .callbackLatency,
            callbackPhase: .didFinishProcessingPhoto,
            durationMilliseconds: 128,
            captureId: UUID(),
            sessionId: UUID(),
            input: .hardwarePrimary,
            outcome: .rejected,
            rejectionCategory: .capacityReached,
            failureCode: .saveRetained,
            pendingCount: 1,
            queueLimit: 2,
            occupiedSlots: 2,
            peakMemoryBytes: 67_108_864,
            previewStallCount: 3,
            thermalState: .serious,
            configuration: DiagnosticsEvent.Configuration(
                appBuild: "Slit-Dev-1", osBuild: "22A1", deviceModel: "iPhone17,4",
                rawPixelFormatCode: "HGVD", formatMaximumWidth: 8_064,
                formatMaximumHeight: 6_048, focusMode: .locked, captureSlotLimit: 2
            )
        )
        let data = try JSONEncoder().encode(event)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var keys = Set<String>()
        allKeys(in: json, into: &keys)
        #expect(keys == DiagnosticsEvent.wireKeys)
    }

    @Test func encodedLineRoundTripsThroughJSON() throws {
        let original = DiagnosticsEvent(
            sequence: 7, kind: .phaseDuration, metric: .storageLatency,
            durationMilliseconds: nil, captureId: UUID(), sessionId: UUID(),
            thermalState: .fair
        )
        let decoded = try #require(DiagnosticsEvent.fromJSONLine(original.encodedLine()))
        #expect(decoded == original)
    }

    /// The synthesized encoder omits an unavailable key entirely; it writes
    /// no explicit null and never a fabricated zero. Decoding returns the
    /// measurement as unavailable either way.
    @Test func unavailableMeasurementsOmitTheKeyInsteadOfWritingZero() throws {
        let event = DiagnosticsEvent(
            kind: .phaseDuration, metric: .coldStart, durationMilliseconds: nil
        )
        let line = try event.encodedLine()
        #expect(!line.contains("durationMilliseconds"))
        #expect(DiagnosticsEvent.fromJSONLine(line)?.durationMilliseconds == nil)
    }

    @Test func malformedAndUnsupportedLinesDecodeToNil() {
        #expect(DiagnosticsEvent.fromJSONLine("") == nil)
        #expect(DiagnosticsEvent.fromJSONLine("   \n") == nil)
        #expect(DiagnosticsEvent.fromJSONLine("not json") == nil)
        #expect(DiagnosticsEvent.fromJSONLine("{\"schemaVersion\":9,\"kind\":\"attempt\"}") == nil)
        #expect(DiagnosticsEvent.fromJSONLine("{\"schemaVersion\":1,\"kind\":\"notAKind\"}") == nil)
    }

    @Test func inputSourceMapsFromTheSharedCaptureContract() {
        #expect(DiagnosticsEvent.InputSource(.onscreen) == .onscreen)
        #expect(DiagnosticsEvent.InputSource(.hardwarePrimary) == .hardwarePrimary)
        #expect(DiagnosticsEvent.InputSource(.hardwareSecondary) == .hardwareSecondary)
    }
}
