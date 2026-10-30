#if DEBUG
import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Queue confinement: all mutable state and AVFoundation objects stay on `queue`.
/// Delegate callbacks copy file bytes before enqueueing. The worker receives only values.
/// No session, device, output, or mutable report escapes this owner.
final class CapabilityProbe: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    struct Update: Sendable {
        let text: String
        let files: [URL]
        let canCapture: Bool
        let canRetry: Bool
    }
    private let queue = DispatchQueue(label: "slit.capability.camera")
    private let worker = DispatchQueue(label: "slit.capability.files", qos: .utility)
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var readinessObservation: NSKeyValueObservation?
    private var rawFormat: OSType?
    private var report: [String: String] = [:]
    private var events: [String] = []
    private var pendingID: Int64?
    private var delivered: Data?
    private var captureError: String?
    private var working = false
    private var active = false
    private var inputEnabled = true
    private var retainedForRetry: Data?
    private var artifactID = UUID()
    private var retainedDelegate: CapabilityProbe?
    private var requestedInstant: ContinuousClock.Instant?
    private var files: [URL] = []
    private let publish: @Sendable (Update) -> Void

    init(publish: @escaping @Sendable (Update) -> Void) {
        self.publish = publish
        super.init()
    }

    func start() {
        queue.async { self.active = true }
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
            guard let self else { return }
            self.queue.async {
                guard self.active else { return }
                guard allowed else { self.record("Camera permission denied"); return }
                do {
                    if self.device == nil { try self.configure() }
                    self.session.startRunning()
                    self.record("Session start returned; running=\(self.session.isRunning)")
                } catch { self.record("Unsupported or unavailable: \(probeFailure(error))") }
            }
        }
    }

    func stop() {
        queue.async {
            self.active = false
            self.session.stopRunning()
            self.record("Session stopped; pending delivery remains owned")
        }
    }

    private func configure() throws {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        else { throw ProbeError.failed("Physical rear main camera absent") }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw ProbeError.failed("Cannot attach input") }
        session.addInput(input)
        guard session.canAddOutput(output) else {
            session.removeInput(input)
            throw ProbeError.failed("Cannot attach photo output")
        }
        session.addOutput(output)
        // Query only after connecting the physical input and the photo output.
        let formats = output.availableRawPhotoPixelFormatTypes.filter {
            AVCapturePhotoOutput.isBayerRAWPixelFormat($0)
        }
        let dimensions = camera.activeFormat.supportedMaxPhotoDimensions
        report["cameraDeviceType"] = camera.deviceType.rawValue
        report["position"] = "back"
        report["activeFormat"] = String(describing: camera.activeFormat)
        report["availableRawFormats"] = output.availableRawPhotoPixelFormatTypes.map(String.init).joined(separator: ",")
        report["bayerRawFormats"] = formats.map(String.init).joined(separator: ",")
        report["supportedMaxDimensions"] = dimensions.map { "\($0.width)x\($0.height)" }.joined(separator: ",")
        report["continuousAutofocus"] = String(camera.isFocusModeSupported(.continuousAutoFocus))
        report["autofocus"] = String(camera.isFocusModeSupported(.autoFocus))
        report["focusPointOfInterest"] = String(camera.isFocusPointOfInterestSupported)
        report["lockedFocus"] = String(camera.isFocusModeSupported(.locked))
        report["customLensLock"] = String(camera.isLockingFocusWithCustomLensPositionSupported)
        report["exposureBiasRangeEV"] = "\(camera.minExposureTargetBias)...\(camera.maxExposureTargetBias)"
        report["continuousExposure"] = String(camera.isExposureModeSupported(.continuousAutoExposure))
        report["continuousWhiteBalance"] = String(camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance))
        report["focusLockExecution"] = "NOT RUN; support flags do not prove lens lock or optical sharpness"
        report["configurationStatus"] = "Provisional probe selection; T006 must freeze measured settings"
        do {
            guard let format = formats.first,
                  let size = dimensions.min(by: { Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height) }),
                  camera.isFocusModeSupported(.continuousAutoFocus), camera.isFocusModeSupported(.autoFocus),
                  camera.isFocusModeSupported(.locked), camera.isFocusPointOfInterestSupported,
                  camera.isLockingFocusWithCustomLensPositionSupported,
                  camera.isExposureModeSupported(.continuousAutoExposure),
                  camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)
            else { throw ProbeError.failed("Required Bayer raw, dimensions, focus, or automatic exposure support absent") }
            try camera.lockForConfiguration()
            camera.videoZoomFactor = 1.0
            camera.focusMode = .continuousAutoFocus
            camera.exposureMode = .continuousAutoExposure
            camera.whiteBalanceMode = .continuousAutoWhiteBalance
            camera.unlockForConfiguration()
            output.maxPhotoDimensions = size
            output.maxPhotoQualityPrioritization = .speed
            output.isLivePhotoCaptureEnabled = false
            if output.isAppleProRAWSupported { output.isAppleProRAWEnabled = false }
            if output.isResponsiveCaptureSupported { output.isResponsiveCaptureEnabled = false }
            if output.isFastCapturePrioritizationSupported { output.isFastCapturePrioritizationEnabled = false }
            if output.isZeroShutterLagSupported { output.isZeroShutterLagEnabled = false }
            if output.isAutoDeferredPhotoDeliverySupported { output.isAutoDeferredPhotoDeliveryEnabled = false }
            rawFormat = format
            device = camera
            report["zoomFactor"] = String(Double(camera.videoZoomFactor))
            report["requestedRawFormat"] = String(format)
            report["requestedMaximumDimensions"] = "\(size.width)x\(size.height)"
            report["qualityPriority"] = "speed"
            report["acceleration"] = "responsive=false; fast=false; zeroShutterLag=false; deferred=false"
            report["probeSlotLimit"] = "1 (includes writing and decoding); product starts with at most 2"
            report["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
            report["appBuild"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
            readinessObservation = output.observe(\.captureReadiness, options: [.initial, .new]) { [weak self] output, _ in
                let value = String(describing: output.captureReadiness)
                self?.queue.async { [weak self] in self?.record("readiness=\(value)") }
            }
        } catch {
            session.removeOutput(output)
            session.removeInput(input)
            throw error
        }
    }

    func setInputEnabled(_ enabled: Bool) {
        queue.async { self.inputEnabled = enabled; self.record("Input enabled=\(enabled)") }
    }

    func hardware(source: String, phase: String) {
        queue.async {
            self.record("hardware \(source) \(phase)")
            if phase == "ended" { self.captureOnQueue(source: source) }
        }
    }

    func capture() { queue.async { self.captureOnQueue(source: "onscreen") } }

    private func captureOnQueue(source: String) {
        guard active, inputEnabled, session.isRunning, !session.isInterrupted, !working,
              output.captureReadiness == .ready, let rawFormat else {
            record("Rejected \(source); no request queued")
            return
        }
        working = true
        delivered = nil
        captureError = nil
        files = []
        let settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        settings.maxPhotoDimensions = output.maxPhotoDimensions
        settings.photoQualityPrioritization = .speed
        settings.flashMode = .off
        artifactID = UUID()
        retainedDelegate = self
        pendingID = settings.uniqueID
        requestedInstant = ContinuousClock.now
        report["captureSource"] = source
        report["neutralDecode"] = "NOT RUN"
        record("Accepted raw request \(settings.uniqueID)")
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        let bytes = photo.isRawPhoto ? photo.fileDataRepresentation() : nil
        let dimensions = photo.resolvedSettings.rawPhotoDimensions
        let failure = error.map(probeFailure)
        queue.async {
            guard self.pendingID == id else { return }
            self.delivered = bytes
            if let start = self.requestedInstant {
                self.report["requestToProcessingCallbackMilliseconds"] = String(probeMilliseconds(start.duration(to: ContinuousClock.now)))
            }
            self.captureError = failure
            self.report["deliveredRawDimensions"] = "\(dimensions.width)x\(dimensions.height)"
            self.record("didFinishProcessingPhoto; rawBytes=\(bytes?.count ?? 0)")
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let id = resolvedSettings.uniqueID
        let failure = error.map(probeFailure)
        queue.async {
            guard self.pendingID == id else { return }
            self.pendingID = nil
            self.retainedDelegate = nil
            guard let bytes = self.delivered, !bytes.isEmpty else {
                self.working = false
                self.record("Capture failed: \(failure ?? self.captureError ?? "No raw bytes delivered")")
                return
            }
            // Preserve delivered bytes even if a later terminal callback reports an error.
            self.report["captureError"] = failure ?? self.captureError ?? "none"
            self.delivered = nil
            self.writeArtifacts(bytes)
        }
    }

    func retryWrite() {
        queue.async {
            guard let bytes = self.retainedForRetry else { return }
            self.retainedForRetry = nil
            self.writeArtifacts(bytes)
        }
    }

    private func writeArtifacts(_ bytes: Data) {
        var evidence = report
        evidence["events"] = events.joined(separator: "\n")
        let snapshot = evidence
        let id = artifactID
        record("Writing probe artifacts")
        worker.async {
            let result = ProbeArtifacts.write(id: id, bytes: bytes, report: snapshot)
            self.queue.async {
                // A failed write retains the exact bytes and the occupied probe slot.
                self.retainedForRetry = result.complete ? nil : bytes
                self.working = !result.complete
                self.files = result.files
                self.report["artifactResult"] = result.message
                self.record("Probe processing finished. This is not a library commit.")
            }
        }
    }

    private func record(_ event: String) {
        events.append(event)
        if events.count > 128 { events.removeFirst(events.count - 128) }
        let text = report.keys.sorted().map { "\($0): \(report[$0]!)" }.joined(separator: "\n")
            + "\n\n" + events.joined(separator: "\n")
        publish(Update(text: text, files: files,
                       canCapture: active && inputEnabled && session.isRunning && !session.isInterrupted && !working && output.captureReadiness == .ready,
                       canRetry: retainedForRetry != nil))
    }
}

private func probeMilliseconds(_ duration: Duration) -> Double {
    let value = duration.components
    return Double(value.seconds) * 1_000 + Double(value.attoseconds) / 1_000_000_000_000_000
}

private enum ProbeError: Error { case failed(String) }

private func probeFailure(_ error: Error) -> String {
    if let probeError = error as? ProbeError, case let .failed(message) = probeError { return message }
    // Platform descriptions can contain absolute paths. Export only the domain and code.
    let value = error as NSError
    return "\(value.domain) code=\(value.code)"
}

private enum ProbeArtifacts {
    struct Result: Sendable { let files: [URL]; let message: String; let complete: Bool }

    static func write(id: UUID, bytes: Data, report: [String: String]) -> Result {
        let writeStarted = ContinuousClock.now
        var evidence = report
        var files: [URL] = []
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            let folder = root.appendingPathComponent("SlitCapabilityProbe/\(id.uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let original = folder.appendingPathComponent("original.dng")
            if !FileManager.default.fileExists(atPath: original.path) {
                try bytes.write(to: original, options: .atomic)
            }
            files.append(original)
            // Read back and compare exact bytes; never rewrite the original for orientation.
            guard try Data(contentsOf: original) == bytes else { throw ProbeError.failed("Original byte mismatch") }
            evidence["byteCount"] = String(bytes.count)
            evidence["originalByteComparison"] = "equal"
            evidence["writeAndByteComparisonMilliseconds"] = String(probeMilliseconds(writeStarted.duration(to: ContinuousClock.now)))
            let decodeStarted = ContinuousClock.now
            do {
                guard let source = CGImageSourceCreateWithURL(original as CFURL, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
                      let width = properties[kCGImagePropertyPixelWidth as String] as? NSNumber,
                      let height = properties[kCGImagePropertyPixelHeight as String] as? NSNumber,
                      properties[kCGImagePropertyDNGDictionary as String] != nil
                else { throw ProbeError.failed("Unreadable DNG container or missing dimensions") }
                let containerDimensions = "\(width.intValue)x\(height.intValue)"
                evidence["containerDimensions"] = containerDimensions
                guard containerDimensions == report["deliveredRawDimensions"] else {
                    throw ProbeError.failed("Container dimensions differ from delivered raw dimensions")
                }
                evidence["deliveredOrientationEXIF"] = String(describing: properties[kCGImagePropertyOrientation as String])
                guard let raw = CIRAWFilter(imageURL: original) else { throw ProbeError.failed("CIRAWFilter rejected DNG") }
                evidence["decoderVersion"] = raw.decoderVersion.rawValue
                evidence["decoderPolicy"] = "Core Image defaults, as-shot neutral; no creative filter; decoder applies orientation once"
                // Bound output size. Full-resolution decoder memory still requires device measurement.
                raw.scaleFactor = min(1, 1024 / Float(max(width.intValue, height.intValue)))
                guard let image = raw.outputImage,
                      let rendered = CIContext().createCGImage(image, from: image.extent)
                else { throw ProbeError.failed("Raw development failed") }
                let preview = folder.appendingPathComponent("neutral.jpg")
                guard let destination = CGImageDestinationCreateWithURL(preview as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
                else { throw ProbeError.failed("Cannot create neutral image") }
                CGImageDestinationAddImage(destination, rendered, nil)
                guard CGImageDestinationFinalize(destination) else { throw ProbeError.failed("Cannot finish neutral image") }
                files.append(preview)
                evidence["neutralDecode"] = "Rendered \(rendered.width)x\(rendered.height); visual inspection pending"
            } catch { evidence["neutralDecode"] = "FAILED: \(probeFailure(error)); original preserved" }
            evidence["neutralDecodeMilliseconds"] = String(probeMilliseconds(decodeStarted.duration(to: ContinuousClock.now)))
            let reportURL = folder.appendingPathComponent("probe.json")
            let data = try JSONEncoder().encode(evidence)
            try data.write(to: reportURL, options: .atomic)
            files.append(reportURL)
            return Result(files: files, message: evidence["neutralDecode"] ?? "Unknown decode result", complete: true)
        } catch { return Result(files: files, message: "Probe file failure: \(probeFailure(error)). Existing artifacts and bytes retained; retry is available.", complete: false) }
    }
}
#endif
