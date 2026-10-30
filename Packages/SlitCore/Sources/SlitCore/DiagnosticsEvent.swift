import Foundation

/// One measurement, count, or context record in the bounded diagnostics log.
///
/// The type is a closed set of whitelisted primitive fields. It has no field
/// for image samples, location, photograph display names, or file paths, so
/// those values cannot enter a record through this API. Identifiers are
/// app-local UUIDs only. Durations are monotonic milliseconds. Unavailable
/// measurements are nil; the synthesized encoder omits their keys entirely,
/// never writing an explicit null or a fabricated zero.
public struct DiagnosticsEvent: Equatable, Codable, Sendable {
    /// Event families. Duration events carry a `metric` name.
    public enum Kind: String, Codable, Sendable {
        case phaseDuration
        case attempt
        case queueLimits
        case configurationSnapshot
        case thermalState
        case resourceUse
    }

    /// The named measurements of specification section 10.
    public enum Metric: String, Codable, Sendable {
        case coldStart
        case warmResume
        case requestOverhead
        case acceptanceFeedback
        /// A proxy measurement. It spans input to a named platform callback,
        /// not the exact exposure time.
        case callbackLatency
        case storageLatency
        case backlogDrain
    }

    /// The platform callback a proxy latency was measured to. These are
    /// outcome codes, not platform objects.
    public enum CallbackPhase: String, Codable, Sendable {
        case willCapture
        case didFinishCapture
        case didFinishProcessingPhoto
    }

    public enum AttemptOutcome: String, Codable, Sendable {
        case accepted
        case rejected
    }

    /// The same categories the admission rule rejects on. Hardware attempts
    /// are only logged when the app actually receives them.
    public enum RejectionCategory: String, Codable, Sendable {
        case inactive
        case screenHidden
        case outputUnavailable
        case storageBlocked
        case capacityReached
    }

    public enum FailureCode: String, Codable, Sendable {
        case captureFailed
        case saveRetained
        case saveLost
        case previewFailed
        case sessionFailed
    }

    public enum ThermalState: String, Codable, Sendable {
        case nominal, fair, serious, critical
    }

    public enum InputSource: String, Codable, Sendable {
        case onscreen
        case hardwarePrimary
        case hardwareSecondary

        /// Maps the shared capture contract's input value onto this code.
        public init(_ input: CaptureInput) {
            switch input {
            case .onscreen: self = .onscreen
            case .hardwarePrimary: self = .hardwarePrimary
            case .hardwareSecondary: self = .hardwareSecondary
            }
        }
    }

    public let schemaVersion: Int
    /// Per-process monotonic ordinal. The recorder assigns it; callers pass zero.
    public var sequence: UInt64
    public let kind: Kind
    public let metric: Metric?
    public let callbackPhase: CallbackPhase?
    public let durationMilliseconds: Int64?
    public let captureId: UUID?
    public let sessionId: UUID?
    public let input: InputSource?
    public let outcome: AttemptOutcome?
    public let rejectionCategory: RejectionCategory?
    public let failureCode: FailureCode?
    /// Pending uncommitted saves for this event's observation.
    public let pendingCount: Int?
    /// The configured capture slot limit at this event.
    public let queueLimit: Int?
    /// Slots occupied at this event, including retained failed saves.
    public let occupiedSlots: Int?
    public let peakMemoryBytes: UInt64?
    public let previewStallCount: UInt64?
    public let thermalState: ThermalState?
    public let configuration: Configuration?

    public init(
        schemaVersion: Int = 1,
        sequence: UInt64 = 0,
        kind: Kind,
        metric: Metric? = nil,
        callbackPhase: CallbackPhase? = nil,
        durationMilliseconds: Int64? = nil,
        captureId: UUID? = nil,
        sessionId: UUID? = nil,
        input: InputSource? = nil,
        outcome: AttemptOutcome? = nil,
        rejectionCategory: RejectionCategory? = nil,
        failureCode: FailureCode? = nil,
        pendingCount: Int? = nil,
        queueLimit: Int? = nil,
        occupiedSlots: Int? = nil,
        peakMemoryBytes: UInt64? = nil,
        previewStallCount: UInt64? = nil,
        thermalState: ThermalState? = nil,
        configuration: Configuration? = nil
    ) {
        precondition(schemaVersion == 1, "Only diagnostics schema version 1 exists")
        self.schemaVersion = schemaVersion
        self.sequence = sequence
        self.kind = kind
        self.metric = metric
        self.callbackPhase = callbackPhase
        self.durationMilliseconds = durationMilliseconds
        self.captureId = captureId
        self.sessionId = sessionId
        self.input = input
        self.outcome = outcome
        self.rejectionCategory = rejectionCategory
        self.failureCode = failureCode
        self.pendingCount = pendingCount
        self.queueLimit = queueLimit
        self.occupiedSlots = occupiedSlots
        self.peakMemoryBytes = peakMemoryBytes
        self.previewStallCount = previewStallCount
        self.thermalState = thermalState
        self.configuration = configuration
    }

    /// Encodes one JSON Lines record. Encoding keys stay within the closed
    /// set above; the line has no trailing newline.
    public func encodedLine() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }

    /// Decodes one JSON Lines record. Returns nil for blank or malformed
    /// lines and for records outside schema version 1.
    public static func fromJSONLine(_ line: String) -> DiagnosticsEvent? {
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let data = line.data(using: .utf8) else { return nil }
        guard let event = try? JSONDecoder().decode(DiagnosticsEvent.self, from: data) else {
            return nil
        }
        guard event.schemaVersion == 1 else { return nil }
        return event
    }

    /// Every key the wire form can contain, including nested configuration
    /// keys. Tests use this set to prove that no pixel, location, name, or
    /// path field can appear in an encoded record.
    public static let wireKeys: Set<String> = [
        "schemaVersion", "sequence", "kind", "metric", "callbackPhase",
        "durationMilliseconds", "captureId", "sessionId", "input", "outcome",
        "rejectionCategory", "failureCode", "pendingCount", "queueLimit",
        "occupiedSlots", "peakMemoryBytes", "previewStallCount",
        "thermalState", "configuration",
        "appBuild", "osBuild", "deviceModel", "rawPixelFormatCode",
        "formatMaximumWidth", "formatMaximumHeight", "focusMode",
        "captureSlotLimit",
    ]

    /// Configuration recorded once per measurement run. The dimensions are
    /// the configured maximums from the capability report, not image samples.
    public struct Configuration: Equatable, Codable, Sendable {
        public enum FocusMode: String, Codable, Sendable {
            case continuousAutofocus
            case acquiring
            case locked
        }

        public let appBuild: String
        public let osBuild: String
        public let deviceModel: String
        /// A short raw pixel format code, for example `HGVD`. At most eight
        /// characters, so a path or photograph name cannot occupy this field.
        public let rawPixelFormatCode: String
        public let formatMaximumWidth: Int
        public let formatMaximumHeight: Int
        public let focusMode: FocusMode
        public let captureSlotLimit: Int

        public init(
            appBuild: String,
            osBuild: String,
            deviceModel: String,
            rawPixelFormatCode: String,
            formatMaximumWidth: Int,
            formatMaximumHeight: Int,
            focusMode: FocusMode,
            captureSlotLimit: Int
        ) {
            precondition(
                rawPixelFormatCode.count <= 8,
                "A raw format code is at most eight characters"
            )
            self.appBuild = appBuild
            self.osBuild = osBuild
            self.deviceModel = deviceModel
            self.rawPixelFormatCode = rawPixelFormatCode
            self.formatMaximumWidth = formatMaximumWidth
            self.formatMaximumHeight = formatMaximumHeight
            self.focusMode = focusMode
            self.captureSlotLimit = captureSlotLimit
        }
    }
}
