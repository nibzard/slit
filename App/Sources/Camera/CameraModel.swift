// ABOUTME: MainActor view model that consumes CameraOwner updates and publishes interface state for Grip.
// ABOUTME: Owns no session work; it only relays value updates and user intents to the camera owner.

import AVFoundation
import AVKit

@MainActor
final class CameraModel: ObservableObject {
    @Published private(set) var phase: CameraOwner.Phase = .permissionNeeded
    @Published private(set) var canCapture = false
    @Published private(set) var feedbackMessage: String?
    @Published private(set) var acceptedFlash = false
    @Published private(set) var debugState = ""

    let owner: CameraOwner
    let session: AVCaptureSession

    private var applyUpdates: Task<Void, Never>?
    /// Separate clear tasks: one shared task lets a flash cancel a pending
    /// message clear, so an error message would stay on screen.
    private var clearFlash: Task<Void, Never>?
    private var clearMessage: Task<Void, Never>?

    init() {
        let (updates, continuation) = AsyncStream<CameraOwner.Update>.makeStream()
        owner = CameraOwner { update in continuation.yield(update) }
        session = owner.session
        applyUpdates = Task { [weak self] in
            for await update in updates {
                self?.apply(update)
            }
        }
    }

    deinit {
        applyUpdates?.cancel()
    }

    func start() { owner.start() }
    func stop() { owner.stop() }
    func suspendInput() { owner.suspendInput() }
    func previewDidAttach() { owner.previewDidAttach() }
    func requestPermission() { owner.requestPermission() }

    func setCaptureVisible(_ visible: Bool) {
        owner.setCaptureVisible(visible)
    }

    func capture() {
        owner.capture()
    }

    func hardware(source: String, phase: AVCaptureEventPhase) {
        owner.hardware(source: source, phase: phase)
    }

    private func apply(_ update: CameraOwner.Update) {
        phase = update.phase
        canCapture = update.canCapture
        debugState = "\(String(describing: update.phase)) run=\(update.isRunning) int=\(update.isInterrupted) ready=\(update.readinessReady) slots=\(update.occupiedSlots)"
        guard let feedback = update.feedback else { return }
        switch feedback {
        case .accepted:
            acceptedFlash = true
            clearFlashAfterInterval()
        case .busy, .captureFailed, .notSaved:
            feedbackMessage = feedback.message
            clearMessageAfterInterval()
        }
    }

    private func clearFlashAfterInterval() {
        clearFlash?.cancel()
        clearFlash = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.2))
            self?.acceptedFlash = false
        }
    }

    private func clearMessageAfterInterval() {
        clearMessage?.cancel()
        clearMessage = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.feedbackMessage = nil
        }
    }
}
