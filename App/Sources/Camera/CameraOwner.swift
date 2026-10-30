// ABOUTME: Production camera owner: one serial queue owns the AVCaptureSession, the frozen WP-01 configuration, admission slots, and photo delegates.
// ABOUTME: Publishes value-only state updates; no platform object except the preview-attachable session escapes the owner.

import AVFoundation
import AVKit
import SlitCore

#if DEBUG
/// Diagnostic launch modes for isolating camera-subsystem failures on a device.
/// Select with `--camera-mode=<mode>`; see docs/handoff reports for the matrix.
enum CameraMode: String {
    case full
    case previewOnly = "preview-only"
    case rawOnly = "raw-only"
    case noChurn = "no-churn"
    /// Restores the v1-v4 lifecycle: the session stops on every non-active scene phase.
    case churn = "churn"

    static let current: CameraMode = {
        let prefix = "--camera-mode="
        guard let flag = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else { return .full }
        return CameraMode(rawValue: String(flag.dropFirst(prefix.count))) ?? .full
    }()
}
#endif

/// Queue confinement: all mutable state and AVFoundation objects stay on `queue`.
/// Delegate callbacks copy file bytes and hop to `queue` before touching state.
/// The session constant is shared only so the preview layer can attach it;
/// configuration and capture remain owned by this executor.
/// Per-request abandonment keeps a lost terminal callback from leaking a slot.
final class CameraOwner: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    enum Phase: Equatable, Sendable {
        case permissionNeeded, denied, starting, ready, suspended, unavailable(String)
    }

    enum Feedback: Equatable, Sendable {
        case accepted
        case busy
        case captureFailed(String)
        case notSaved(String)

        var message: String {
            switch self {
            case .accepted: return ""
            case .busy: return "Busy"
            case .captureFailed(let reason): return "Couldn't capture. \(reason)"
            case .notSaved(let reason): return "Photo not saved. \(reason)"
            }
        }
    }

    struct Update: Sendable {
        let phase: Phase
        let occupiedSlots: Int
        let feedback: Feedback?
        let isRunning: Bool
        let isInterrupted: Bool
        let readinessReady: Bool
        var canCapture: Bool {
            phase == .ready && occupiedSlots < SlitDefaults.maximumCaptureSlots
        }
    }

    private struct InFlight {
        let admissionId: UUID
        var bytes: Data?
        var error: String?
    }

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "slit.camera")
    private var admission = CaptureAdmission(capacity: SlitDefaults.maximumCaptureSlots)
    private var readinessObservation: NSKeyValueObservation?
    private var interruptionObservation: NSKeyValueObservation?
    private var wasInterruptedObserver: NSObjectProtocol?
    private var interruptionEndedObserver: NSObjectProtocol?
    private var runtimeErrorObserver: NSObjectProtocol?
    private var rawFormat: OSType?
    private var configured = false
    private var previewAttached = false
    private var startWaitingForPreview = false
    private let expectsPreviewAttachment: Bool
    private var phase: Phase = .permissionNeeded
    /// Two independent input gates: scene activation and capture-screen visibility.
    /// Collapsing them into one flag strands capture after a transient `.inactive` episode.
    private var appActive = true
    private var screenVisible = true
    private var sessionActive = false
    private var inFlight: [Int64: InFlight] = [:]
    private var retainedDelegates: [Int64: CameraOwner] = [:]
    private let publish: @Sendable (Update) -> Void

    /// A terminal callback that never arrives must not hold a slot forever.
    private static let terminalCallbackTimeoutSeconds: TimeInterval = 15

    init(publish: @escaping @Sendable (Update) -> Void) {
        self.publish = publish
        #if DEBUG
        self.expectsPreviewAttachment = CameraMode.current != .rawOnly
        #else
        self.expectsPreviewAttachment = true
        #endif
        super.init()
    }

    deinit {
        for observer in [wasInterruptedObserver, interruptionEndedObserver, runtimeErrorObserver] {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }

    func start() {
        queue.async {
            self.appActive = true
            self.startOnQueue()
        }
    }

    /// Runs on the main thread right after the preview layer receives the session.
    /// The session starts only after this call, so the layer never joins a session that already runs.
    func previewDidAttach() {
        queue.async {
            guard !self.previewAttached else { return }
            self.previewAttached = true
            CameraDiagnostics.event("preview layer attached")
            guard self.startWaitingForPreview, !self.sessionActive else { return }
            self.startWaitingForPreview = false
            self.runSession()
        }
    }

    /// Transient inactivity (app-switcher peek, control center, launch flicker)
    /// disables input only. Stopping the session on every `.inactive` flip churns
    /// startRunning/stopRunning, which is a daemon-stability risk, so the session
    /// itself stops only on real backgrounding via `stop()`.
    func suspendInput() {
        queue.async {
            self.appActive = false
            self.emit(feedback: nil)
        }
    }

    func stop() {
        queue.async {
            #if DEBUG
            if CameraMode.current == .noChurn {
                CameraDiagnostics.event("stop suppressed (no-churn mode)")
                return
            }
            #endif
            CameraDiagnostics.event("stopRunning begin")
            self.sessionActive = false
            self.startWaitingForPreview = false
            self.appActive = false
            if self.session.isRunning { self.session.stopRunning() }
            CameraDiagnostics.event("stopRunning end")
            self.enter(.suspended)
        }
    }

    func requestPermission() {
        queue.async { self.startOnQueue() }
    }

    func setCaptureVisible(_ visible: Bool) {
        queue.async {
            self.screenVisible = visible
            self.emit(feedback: nil)
        }
    }

    func capture() {
        queue.async { self.captureOnQueue() }
    }

    func hardware(source: String, phase: AVCaptureEventPhase) {
        queue.async {
            guard phase == .ended else { return }
            self.captureOnQueue()
        }
    }

    // MARK: - Queue-confined internals

    private func startOnQueue() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            CameraDiagnostics.event("authorization denied")
            enter(.denied)
            return
        case .notDetermined:
            enter(.permissionNeeded)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                guard let self else { return }
                self.queue.async {
                    if allowed { self.startConfiguredSession() } else { self.enter(.denied) }
                }
            }
        default:
            startConfiguredSession()
        }
    }

    private func startConfiguredSession() {
        if sessionActive { return }
        enter(.starting)
        do {
            if !configured { try configure() }
        } catch {
            CameraDiagnostics.event("configure failed \(error)")
            enter(.unavailable("Camera configuration failed"))
            return
        }
        if expectsPreviewAttachment && !previewAttached {
            // Canon (AVCam): the preview layer holds the session before the session runs.
            startWaitingForPreview = true
            return
        }
        runSession()
    }

    private func runSession() {
        CameraDiagnostics.event("startRunning begin")
        session.startRunning()
        // startRunning reports failure only through isRunning; keeping sessionActive
        // true on a failed start would wedge the unavailable state with no retry.
        sessionActive = session.isRunning
        CameraDiagnostics.event("startRunning end isRunning=\(session.isRunning)")
        enter(session.isRunning ? .ready : .unavailable("Session did not start"))
    }

    private func configure() throws {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        else { throw ConfigureError.noRearMainCamera }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw ConfigureError.cannotAttachInput }
        session.addInput(input)
        // Mark configured before the mode branch below so every mode configures exactly once.
        configured = true
        registerSessionObservers()
        CameraDiagnostics.event("configured mode=\(currentModeName)")
        #if DEBUG
        // preview-only mode isolates the preview layer from the raw photo output.
        if CameraMode.current == .previewOnly { return }
        #endif
        guard session.canAddOutput(output) else {
            session.removeInput(input)
            throw ConfigureError.cannotAttachOutput
        }
        session.addOutput(output)
        // Frozen by the WP-01 decision: 4032x3024 raw, speed prioritization, no acceleration.
        guard let format = output.availableRawPhotoPixelFormatTypes.first(where: {
            AVCapturePhotoOutput.isBayerRAWPixelFormat($0)
        }) else { throw ConfigureError.noBayerRawFormat }
        try camera.lockForConfiguration()
        camera.videoZoomFactor = 1.0
        camera.focusMode = .continuousAutoFocus
        camera.exposureMode = .continuousAutoExposure
        camera.whiteBalanceMode = .continuousAutoWhiteBalance
        camera.unlockForConfiguration()
        if let size = camera.activeFormat.supportedMaxPhotoDimensions.first(where: { $0.width == 4032 && $0.height == 3024 }) {
            output.maxPhotoDimensions = size
        }
        output.maxPhotoQualityPrioritization = .speed
        output.isLivePhotoCaptureEnabled = false
        if output.isAppleProRAWSupported { output.isAppleProRAWEnabled = false }
        if output.isResponsiveCaptureSupported { output.isResponsiveCaptureEnabled = false }
        if output.isFastCapturePrioritizationSupported { output.isFastCapturePrioritizationEnabled = false }
        if output.isZeroShutterLagSupported { output.isZeroShutterLagEnabled = false }
        if output.isAutoDeferredPhotoDeliverySupported { output.isAutoDeferredPhotoDeliveryEnabled = false }
        rawFormat = format
        readinessObservation = output.observe(\.captureReadiness, options: [.initial, .new]) { [weak self] _, _ in
            self?.queue.async { self?.emit(feedback: nil) }
        }
        interruptionObservation = session.observe(\.isInterrupted, options: [.new]) { [weak self] session, _ in
            self?.queue.async {
                guard let self, self.sessionActive else { return }
                self.enter(session.isInterrupted ? .suspended : .ready)
            }
        }
    }

    /// Canon (AVCam): observe interruption and runtime errors; if media services were reset
    /// and the last start succeeded, restart the session so the app recovers with the subsystem.
    private func registerSessionObservers() {
        wasInterruptedObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil
        ) { [weak self] note in
            CameraDiagnostics.event("wasInterrupted \(String(describing: note.userInfo))")
            self?.queue.async { self?.emit(feedback: nil) }
        }
        interruptionEndedObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
        ) { [weak self] _ in
            CameraDiagnostics.event("interruptionEnded")
            self?.queue.async {
                guard let self, self.sessionActive, !self.session.isRunning else { return }
                self.runSession()
            }
        }
        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { [weak self] note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? NSError
            CameraDiagnostics.event("runtimeError \(error.map { "\($0.domain) code=\($0.code)" } ?? "unspecified")")
            self?.queue.async {
                guard let self, let error, self.sessionActive else { return }
                if error.code == AVError.mediaServicesWereReset.rawValue {
                    self.runSession()
                } else if !self.session.isRunning {
                    // A dead session must surface as unavailable with a retry path,
                    // not a ready shutter that silently rejects every press.
                    self.sessionActive = false
                    self.startWaitingForPreview = false
                    self.enter(.unavailable("Session error: \(self.failureText(error))"))
                }
            }
        }
    }

    private var currentModeName: String {
        #if DEBUG
        return CameraMode.current.rawValue
        #else
        return "release"
        #endif
    }

    private func captureOnQueue() {
        guard case .ready = phase else { emit(feedback: .busy); return }
        guard let rawFormat else { emit(feedback: nil); return }
        let context = CaptureAdmission.Context(
            isActive: appActive && sessionActive,
            isCaptureVisible: appActive && screenVisible,
            isOutputReady: output.captureReadiness == .ready && session.isRunning && !session.isInterrupted,
            isStorageWritable: true
        )
        let id = UUID()
        do { try admission.reserve(id: id, context: context) } catch {
            if case CaptureAdmission.Rejection.capacityReached = error { emit(feedback: .busy) } else { emit(feedback: nil) }
            return
        }
        let settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        settings.maxPhotoDimensions = output.maxPhotoDimensions
        settings.photoQualityPrioritization = .speed
        settings.flashMode = .off
        inFlight[settings.uniqueID] = InFlight(admissionId: id)
        retainedDelegates[settings.uniqueID] = self
        let uniqueID = settings.uniqueID
        queue.asyncAfter(deadline: .now() + Self.terminalCallbackTimeoutSeconds) { [weak self] in
            self?.abandonInFlight(uniqueID: uniqueID)
        }
        CameraDiagnostics.event("capture begin")
        emit(feedback: .accepted)
        output.capturePhoto(with: settings, delegate: self)
    }

    private func abandonInFlight(uniqueID: Int64) {
        guard inFlight[uniqueID] != nil else { return }
        let flight = inFlight.removeValue(forKey: uniqueID)
        retainedDelegates.removeValue(forKey: uniqueID)
        if let id = flight?.admissionId { releaseAdmission(id: id) }
        emit(feedback: .captureFailed("The camera did not finish the request"))
    }

    // MARK: - AVCapturePhotoCaptureDelegate (value copies hop to the queue)

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let uniqueID = photo.resolvedSettings.uniqueID
        let bytes = photo.isRawPhoto ? photo.fileDataRepresentation() : nil
        let failure = error.map(failureText)
        queue.async {
            guard var flight = self.inFlight[uniqueID] else { return }
            flight.bytes = bytes
            flight.error = failure
            self.inFlight[uniqueID] = flight
            if bytes != nil {
                try? self.admission.transition(id: flight.admissionId, to: .delivered)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let uniqueID = resolvedSettings.uniqueID
        let failure = error.map(failureText)
        CameraDiagnostics.event("capture end \(failure ?? "ok")")
        queue.async {
            guard let flight = self.inFlight.removeValue(forKey: uniqueID) else { return }
            self.retainedDelegates.removeValue(forKey: uniqueID)
            defer { self.emit(feedback: nil) }
            guard let bytes = flight.bytes, !bytes.isEmpty else {
                self.releaseAdmission(id: flight.admissionId)
                self.emit(feedback: .captureFailed(failure ?? flight.error ?? "No raw photograph delivered"))
                return
            }
            // No OriginalStore is connected yet (WP-04). The bytes are discarded
            // explicitly and the slot releases through the honest failure path.
            self.releaseAdmission(id: flight.admissionId)
            self.emit(feedback: .notSaved("Storage is not connected in this build."))
        }
    }

    // MARK: - State plumbing

    private func releaseAdmission(id: UUID) {
        try? admission.releaseFailedRequest(id: id)
    }

    private func enter(_ next: Phase) {
        phase = next
        emit(feedback: nil)
    }

    private func emit(feedback: Feedback?) {
        publish(Update(phase: phase,
                       occupiedSlots: admission.slots.count,
                       feedback: feedback,
                       isRunning: session.isRunning,
                       isInterrupted: session.isInterrupted,
                       readinessReady: output.captureReadiness == .ready))
    }

    private enum ConfigureError: Error {
        case noRearMainCamera, cannotAttachInput, cannotAttachOutput, noBayerRawFormat
    }

    private func failureText(_ error: Error) -> String {
        let value = error as NSError
        return "\(value.domain) code=\(value.code)"
    }
}
