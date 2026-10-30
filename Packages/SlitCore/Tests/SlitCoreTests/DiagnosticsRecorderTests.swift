import Foundation
import Testing
@testable import SlitCore

struct DiagnosticsRecorderTests {
    @Test func sealingAssignsMonotonicSequenceNumbers() {
        var recorder = DiagnosticsRecorder(clock: ManualDiagnosticsClock())
        let first = recorder.seal(DiagnosticsEvent(kind: .attempt, outcome: .accepted))
        let second = recorder.seal(DiagnosticsEvent(kind: .attempt, outcome: .rejected))
        let third = recorder.seal(DiagnosticsEvent(kind: .thermalState, thermalState: .nominal))
        #expect([first.sequence, second.sequence, third.sequence] == [1, 2, 3])
        #expect(recorder.nextSequence == 4)
    }

    @Test func durationEventsUseOnlyTheInjectedClock() {
        var clock = ManualDiagnosticsClock(startMilliseconds: 2_000)
        var recorder = DiagnosticsRecorder(clock: clock)
        var requestWatch = recorder.stopwatch()
        clock.advance(byMilliseconds: 18)
        requestWatch.stop(clock: clock)
        let request = recorder.requestOverhead(requestWatch, captureId: UUID(), sessionId: UUID())
        #expect(request.metric == .requestOverhead)
        #expect(request.durationMilliseconds == 18)

        var feedbackWatch = recorder.stopwatch()
        clock.advance(byMilliseconds: 40)
        feedbackWatch.stop(clock: clock)
        let feedback = recorder.acceptanceFeedback(feedbackWatch, captureId: nil, sessionId: nil)
        #expect(feedback.metric == .acceptanceFeedback)
        #expect(feedback.durationMilliseconds == 40)
        #expect(request.sequence < feedback.sequence)
    }

    @Test func callbackLatencyCarriesPhaseAndProxyMetric() {
        var recorder = DiagnosticsRecorder(clock: ManualDiagnosticsClock())
        let watch = recorder.stopwatch()
        let event = recorder.callbackLatency(
            watch, phase: .didFinishProcessingPhoto, captureId: UUID(), sessionId: UUID()
        )
        #expect(event.metric == .callbackLatency)
        #expect(event.callbackPhase == .didFinishProcessingPhoto)
        #expect(event.durationMilliseconds == nil)
    }

    @Test func rejectedAttemptsCarryCategoryAndNoCaptureIdentifier() {
        var recorder = DiagnosticsRecorder(clock: ManualDiagnosticsClock())
        let event = recorder.attempt(
            input: .onscreen, outcome: .rejected, rejection: .capacityReached, sessionId: UUID()
        )
        #expect(event.kind == .attempt)
        #expect(event.outcome == .rejected)
        #expect(event.rejectionCategory == .capacityReached)
        #expect(event.captureId == nil)
    }

    @Test func startupAndDrainEventsMapTheirFields() {
        var clock = ManualDiagnosticsClock()
        var recorder = DiagnosticsRecorder(clock: clock)
        var cold = recorder.stopwatch()
        clock.advance(byMilliseconds: 900)
        cold.stop(clock: clock)
        let session = UUID()
        #expect(recorder.coldStart(cold, sessionId: session).metric == .coldStart)
        #expect(recorder.warmResume(cold, sessionId: session).metric == .warmResume)

        var drain = recorder.stopwatch()
        clock.advance(byMilliseconds: 1_400)
        drain.stop(clock: clock)
        let backlog = recorder.backlogDrain(drain, pendingCount: 0, captureId: UUID(), sessionId: session)
        #expect(backlog.metric == .backlogDrain)
        #expect(backlog.durationMilliseconds == 1_400)
        #expect(backlog.pendingCount == 0)
    }

    @Test func contextEventsRecordLimitsConfigurationThermalAndResources() {
        var recorder = DiagnosticsRecorder(clock: ManualDiagnosticsClock())
        let session = UUID()
        let limits = recorder.queueLimits(limit: 2, occupied: 1, sessionId: session)
        #expect(limits.queueLimit == 2)
        #expect(limits.occupiedSlots == 1)

        let configuration = recorder.configuration(
            DiagnosticsEvent.Configuration(
                appBuild: "Slit-Dev-1", osBuild: "22A1", deviceModel: "iPhone17,4",
                rawPixelFormatCode: "HGVD", formatMaximumWidth: 8_064,
                formatMaximumHeight: 6_048, focusMode: .continuousAutofocus,
                captureSlotLimit: 2
            ),
            sessionId: session
        )
        #expect(configuration.kind == .configurationSnapshot)
        #expect(configuration.configuration?.captureSlotLimit == 2)

        let thermal = recorder.thermal(.fair, sessionId: session)
        #expect(thermal.thermalState == .fair)

        let resources = recorder.resourceUse(
            peakMemoryBytes: 201_326_592, pendingCount: 2, occupiedSlots: 2,
            previewStallCount: 1, thermalState: .serious, sessionId: session
        )
        #expect(resources.kind == .resourceUse)
        #expect(resources.peakMemoryBytes == 201_326_592)
        #expect(resources.previewStallCount == 1)

        let failure = recorder.failure(code: .saveRetained, captureId: UUID(), sessionId: session)
        #expect(failure.failureCode == .saveRetained)
        #expect(failure.outcome == nil)
    }
}
