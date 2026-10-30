import Foundation

/// These value contracts contain no platform capture objects or filesystem operations.
/// The versioned JSON codec and validation belong to WP-04 (T007).
public struct CaptureIdentity: Hashable, Sendable {
    public let captureId: UUID
    public let sessionId: UUID
    public let requestOrdinal: UInt64
    public let libraryOrder: LibraryOrder

    public init(captureId: UUID, sessionId: UUID, requestOrdinal: UInt64, libraryOrder: LibraryOrder) {
        self.captureId = captureId
        self.sessionId = sessionId
        self.requestOrdinal = requestOrdinal
        self.libraryOrder = libraryOrder
    }
}

public struct LibraryOrder: Hashable, Comparable, Sendable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }
}

/// Returned only after the high-watermark replacement finishes. Gaps are valid.
/// The camera owner consumes this range in memory; exhaustion rejects admission.
public struct ReservedOrderBlock: Equatable, Sendable {
    public let values: ClosedRange<LibraryOrder>
    public init(values: ClosedRange<LibraryOrder>) { self.values = values }
}

public enum CaptureInput: String, Sendable { case onscreen, hardwarePrimary, hardwareSecondary }
public enum CaptureOrientation: String, Sendable { case portrait, landscapeLeft, landscapeRight }
public enum RequestedFocus: String, Sendable { case continuous, acquiring, locking, verifiedLocked }
public enum PhotoQuality: String, Sendable { case speed }
public enum OriginalValidation: String, Sendable { case readableContainer }

public struct PixelDimensions: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public init(width: Int, height: Int) { self.width = width; self.height = height }
}

public struct RequestedCapture: Equatable, Sendable {
    public let rawPixelFormat: UInt32
    public let maximumDimensions: PixelDimensions
    public let qualityPriority: PhotoQuality
    public let exposureCompensationEV: Double
    public let orientation: CaptureOrientation
    public let focusState: RequestedFocus
    public let input: CaptureInput

    public init(rawPixelFormat: UInt32, maximumDimensions: PixelDimensions, qualityPriority: PhotoQuality, exposureCompensationEV: Double, orientation: CaptureOrientation, focusState: RequestedFocus, input: CaptureInput) {
        self.rawPixelFormat = rawPixelFormat
        self.maximumDimensions = maximumDimensions
        self.qualityPriority = qualityPriority
        self.exposureCompensationEV = exposureCompensationEV
        self.orientation = orientation
        self.focusState = focusState
        self.input = input
    }
}

public struct DeliveredCapture: Equatable, Sendable {
    public let dimensions: PixelDimensions?
    public let orientationEXIF: Int?
    public let exposureTimeSeconds: Double?
    public let sensitivityISO: Double?
    public let apertureFNumber: Double?
    public let focalLengthMillimeters: Double?

    public init(dimensions: PixelDimensions?, orientationEXIF: Int?, exposureTimeSeconds: Double?, sensitivityISO: Double?, apertureFNumber: Double?, focalLengthMillimeters: Double?) {
        self.dimensions = dimensions
        self.orientationEXIF = orientationEXIF
        self.exposureTimeSeconds = exposureTimeSeconds
        self.sensitivityISO = sensitivityISO
        self.apertureFNumber = apertureFNumber
        self.focalLengthMillimeters = focalLengthMillimeters
    }
}

public struct CaptureEnvironment: Equatable, Sendable {
    public let appBuild: String
    public let osBuild: String
    public let deviceModel: String
    public let cameraDeviceType: String
    public let cameraPosition: String
    public let zoomFactor: Double

    public init(appBuild: String, osBuild: String, deviceModel: String, cameraDeviceType: String, cameraPosition: String, zoomFactor: Double) {
        self.appBuild = appBuild
        self.osBuild = osBuild
        self.deviceModel = deviceModel
        self.cameraDeviceType = cameraDeviceType
        self.cameraPosition = cameraPosition
        self.zoomFactor = zoomFactor
    }
}

public struct PhaseDuration: Equatable, Sendable {
    public let name: String
    public let milliseconds: Double

    public init(name: String, milliseconds: Double) {
        self.name = name
        self.milliseconds = milliseconds
    }
}

public struct OriginalDescriptor: Equatable, Sendable {
    public let fileName: String
    public let byteCount: UInt64
    public let validation: OriginalValidation

    public init(fileName: String, byteCount: UInt64, validation: OriginalValidation) {
        self.fileName = fileName
        self.byteCount = byteCount
        self.validation = validation
    }
}

public struct RecoveryMetadata: Equatable, Sendable {
    public let wasRecovered: Bool
    public let unavailableFields: [String]

    public init(wasRecovered: Bool, unavailableFields: [String]) {
        self.wasRecovered = wasRecovered
        self.unavailableFields = unavailableFields
    }
}

public struct CaptureMetadata: Equatable, Sendable {
    public let schemaVersion: Int
    public let identity: CaptureIdentity
    public let requestedAtUTC: Date?
    public let committedAtUTC: Date?
    public let environment: CaptureEnvironment?
    public let requested: RequestedCapture?
    public let delivered: DeliveredCapture
    public let timing: [PhaseDuration]
    public let original: OriginalDescriptor
    public let recovery: RecoveryMetadata

    public init(schemaVersion: Int, identity: CaptureIdentity, requestedAtUTC: Date?, committedAtUTC: Date?, environment: CaptureEnvironment?, requested: RequestedCapture?, delivered: DeliveredCapture, timing: [PhaseDuration], original: OriginalDescriptor, recovery: RecoveryMetadata) {
        self.schemaVersion = schemaVersion
        self.identity = identity
        self.requestedAtUTC = requestedAtUTC
        self.committedAtUTC = committedAtUTC
        self.environment = environment
        self.requested = requested
        self.delivered = delivered
        self.timing = timing
        self.original = original
        self.recovery = recovery
    }
}

public struct DeliveredOriginal: Equatable, Sendable {
    public let identity: CaptureIdentity
    public let bytes: Data
    public let metadata: CaptureMetadata

    public init(identity: CaptureIdentity, bytes: Data, metadata: CaptureMetadata) {
        self.identity = identity
        self.bytes = bytes
        self.metadata = metadata
    }
}

public struct CommittedCapture: Equatable, Sendable {
    public let identity: CaptureIdentity
    public let originalURL: URL
    public let metadata: CaptureMetadata
    public let previewURL: URL?

    public init(identity: CaptureIdentity, originalURL: URL, metadata: CaptureMetadata, previewURL: URL?) {
        self.identity = identity
        self.originalURL = originalURL
        self.metadata = metadata
        self.previewURL = previewURL
    }
}

public struct RetainedSave: Equatable, Sendable {
    public let identity: CaptureIdentity
    public let token: UUID

    public init(identity: CaptureIdentity, token: UUID) {
        self.identity = identity
        self.token = token
    }
}

public struct ServiceFailure: Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ReconciliationPage: Equatable, Sendable {
    public let committed: [CommittedCapture]
    public let outcomes: [RecoveryOutcome]
    public let nextCursor: UUID?
    public let highestObservedOrder: LibraryOrder?

    public init(committed: [CommittedCapture], outcomes: [RecoveryOutcome], nextCursor: UUID?, highestObservedOrder: LibraryOrder?) {
        self.committed = committed
        self.outcomes = outcomes
        self.nextCursor = nextCursor
        self.highestObservedOrder = highestObservedOrder
    }
}

public enum CommitResult: Equatable, Sendable {
    /// The complete bundle has committed. An index failure cannot undo this result.
    case committed(CommittedCapture, indexRepairNeeded: Bool)
    /// The store owns the bytes or recoverable staging. The slot remains occupied.
    case retained(RetainedSave, ServiceFailure)
    /// No recoverable data remains. The caller may release the slot.
    case lost(CaptureIdentity, ServiceFailure)
}

public enum DiscardResult: Equatable, Sendable {
    /// Returned only after the store disposes of the retained unsaved data.
    case discarded(CaptureIdentity)
    case refused(ServiceFailure)
}

public enum RecoveryOutcome: Equatable, Sendable {
    case recovered(CaptureIdentity)
    case isolated(captureId: UUID?, reason: ServiceFailure)
    case unavailable(captureId: UUID?, reason: ServiceFailure)
    case indexRepairNeeded
}

public enum CaptureServiceEvent: Equatable, Sendable {
    case accepted(CaptureIdentity)
    case delivered(CaptureIdentity)
    case captureFailed(CaptureIdentity, ServiceFailure)
    case storage(CommitResult)
    case previewFailed(CaptureIdentity, ServiceFailure)
    case sessionUnavailable(ServiceFailure)
}

/// A separate storage executor implements these operations. It never requests an exposure.
/// All identity and metadata identifiers must agree, or submission fails explicitly.
/// Submit transfers retention responsibility to the store until commit, loss, or discard.
public protocol OriginalStore: Sendable {
    /// Persist the reservation before returning. Recover above all known orders first.
    func reserveOrders(count: UInt64) async throws -> ReservedOrderBlock
    func submit(_ original: DeliveredOriginal) async -> CommitResult
    /// Reuse the retained identity and exact bytes. Never allocate another order.
    func retry(_ retained: RetainedSave) async -> CommitResult
    /// Confirmed identity must match the retained item. Refuse committed items and stale tokens.
    func discard(_ retained: RetainedSave, confirmedCaptureId: UUID) async -> DiscardResult
    func readCommitted(captureId: UUID) async throws -> CommittedCapture?
    /// Bound each scan. Return each page in ascending library order; preserve unknown data.
    /// Repeated full scans must not duplicate bundles or reuse orders.
    func reconcile(cursor: UUID?, limit: Int) async throws -> ReconciliationPage
}
