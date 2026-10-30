import Foundation

/// The only capture metadata schema version this package reads and writes.
/// Specification 0002 section 7 fixes the field appendix for version 1.
public enum CaptureMetadataSchema {
    public static let version1 = 1
}

/// The closed set of key names the section 7 appendix defines for version 1.
/// `recovery.unavailableFields` must name keys from this set.
public enum CaptureMetadataKeys {
    public static let appendixKeys: Set<String> = [
        "schemaVersion",
        "captureId",
        "sessionId",
        "requestOrdinal",
        "libraryOrder",
        "requestedAtUTC",
        "committedAtUTC",
        "appBuild",
        "osBuild",
        "deviceModel",
        "cameraDeviceType",
        "cameraPosition",
        "zoomFactor",
        "requested",
        "requested.rawPixelFormat",
        "requested.maximumDimensions",
        "requested.qualityPriority",
        "requested.exposureCompensationEV",
        "requested.orientation",
        "requested.focusState",
        "requested.input",
        "delivered",
        "delivered.dimensions",
        "delivered.orientationEXIF",
        "delivered.exposureTimeSeconds",
        "delivered.sensitivityISO",
        "delivered.apertureFNumber",
        "delivered.focalLengthMillimeters",
        "timing",
        "original.fileName",
        "original.byteCount",
        "original.validation",
        "recovery.wasRecovered",
        "recovery.unavailableFields",
    ]
}

/// Every failure the capture metadata codec reports.
/// A field name is the appendix key, with a dotted path for nested keys.
public enum MetadataCodecFailure: Error, Equatable, Sendable {
    /// The file declares a schema version this package cannot read.
    case unsupportedVersion(found: Int?)
    /// A key the appendix defines is absent from the file.
    /// Unavailable values must be written as explicit null, never omitted.
    case missingField(String)
    /// A key the appendix marks Never null holds an explicit null.
    case nullField(String)
    /// A value is outside the closed value list for its key.
    case invalidValue(field: String, found: String)
    /// A key holds a type other than the type the appendix defines for it.
    case typeMismatch(field: String, detail: String)
    /// A flattened group mixes null and non-null keys.
    /// The appendix writes null for every key of a group, or for none.
    case partiallyNullGroup(field: String, nullKeys: [String])
}

extension MetadataCodecFailure {
    /// Convert a Foundation decoding error into the typed failure for one field.
    static func decoding(_ error: DecodingError, field: String) -> Self {
        switch error {
        case .keyNotFound(_, _):
            return .missingField(field)
        case .valueNotFound(_, _):
            return .nullField(field)
        case .typeMismatch(_, let context):
            return .typeMismatch(field: field, detail: context.debugDescription)
        case .dataCorrupted(let context):
            return .typeMismatch(field: field, detail: context.debugDescription)
        @unknown default:
            return .typeMismatch(field: field, detail: String(describing: error))
        }
    }
}

/// Decode one required key. Absence is an error; the appendix has no optional
/// omission. Null is an error because the caller asks for a non-optional value.
private func required<K: CodingKey, T: Decodable>(
    _ type: T.Type, _ key: K, _ field: String, in container: KeyedDecodingContainer<K>
) throws -> T {
    guard container.contains(key) else { throw MetadataCodecFailure.missingField(field) }
    do {
        return try container.decode(T.self, forKey: key)
    } catch let error as DecodingError {
        throw MetadataCodecFailure.decoding(error, field: field)
    }
}

/// Decode one nullable key. The key must be present; an unavailable value is
/// written as an explicit null under the section 7 rules.
private func nullable<K: CodingKey, T: Decodable>(
    _ type: T.Type, _ key: K, _ field: String, in container: KeyedDecodingContainer<K>
) throws -> T? {
    guard container.contains(key) else { throw MetadataCodecFailure.missingField(field) }
    do {
        return try container.decodeIfPresent(T.self, forKey: key)
    } catch let error as DecodingError {
        throw MetadataCodecFailure.decoding(error, field: field)
    }
}

/// Encode one nullable value as an explicit null when unavailable.
private func encodeNullable<K: CodingKey, T: Encodable>(
    _ value: T?, _ key: K, in container: inout KeyedEncodingContainer<K>
) throws {
    if let value {
        try container.encode(value, forKey: key)
    } else {
        try container.encodeNil(forKey: key)
    }
}

/// Wire form of `requested.maximumDimensions`. Width and height are pixels.
private struct DimensionsWire: Equatable, Sendable {
    var width: Int
    var height: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// The keys every dimensions object carries, under `requested` and
/// `delivered` alike.
private enum DimensionKeys: String, CodingKey {
    case width, height
}

/// Decode one nullable dimensions object under a dotted field prefix. The
/// prefix reaches every nested failure, so a missing width inside a
/// delivered measurement names `delivered.dimensions.width`, never the
/// requested path.
private func decodeDimensions<K: CodingKey>(
    _ key: K, prefix: String, in container: KeyedDecodingContainer<K>
) throws -> DimensionsWire? {
    guard container.contains(key) else { throw MetadataCodecFailure.missingField(prefix) }
    do {
        if try container.decodeNil(forKey: key) { return nil }
        let nested = try container.nestedContainer(keyedBy: DimensionKeys.self, forKey: key)
        let width = try required(Int.self, .width, "\(prefix).width", in: nested)
        let height = try required(Int.self, .height, "\(prefix).height", in: nested)
        return DimensionsWire(width: width, height: height)
    } catch let error as DecodingError {
        throw MetadataCodecFailure.decoding(error, field: prefix)
    }
}

extension DimensionsWire: Encodable {
    private enum CodingKeys: String, CodingKey {
        case width, height
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

/// Wire form of the `requested` object. Closed value fields stay strings on
/// the wire; the codec maps them to the shared value enums with validation.
private struct RequestedWire: Equatable, Sendable {
    var rawPixelFormat: UInt32
    var maximumDimensions: DimensionsWire
    var qualityPriority: String
    var exposureCompensationEV: Double
    var orientation: String
    var focusState: String
    var input: String
}

extension RequestedWire: Codable {
    private enum CodingKeys: String, CodingKey {
        case rawPixelFormat, maximumDimensions, qualityPriority
        case exposureCompensationEV, orientation, focusState, input
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawPixelFormat = try required(UInt32.self, .rawPixelFormat, "requested.rawPixelFormat", in: container)
        guard let dimensions = try decodeDimensions(
            .maximumDimensions, prefix: "requested.maximumDimensions", in: container
        ) else { throw MetadataCodecFailure.nullField("requested.maximumDimensions") }
        maximumDimensions = dimensions
        qualityPriority = try required(String.self, .qualityPriority, "requested.qualityPriority", in: container)
        exposureCompensationEV = try required(
            Double.self, .exposureCompensationEV, "requested.exposureCompensationEV", in: container
        )
        orientation = try required(String.self, .orientation, "requested.orientation", in: container)
        focusState = try required(String.self, .focusState, "requested.focusState", in: container)
        input = try required(String.self, .input, "requested.input", in: container)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawPixelFormat, forKey: .rawPixelFormat)
        try container.encode(maximumDimensions, forKey: .maximumDimensions)
        try container.encode(qualityPriority, forKey: .qualityPriority)
        try container.encode(exposureCompensationEV, forKey: .exposureCompensationEV)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(focusState, forKey: .focusState)
        try container.encode(input, forKey: .input)
    }
}

/// Wire form of the `delivered` object. Each measurement is null when the
/// platform did not report it; the object itself is never null.
private struct DeliveredWire: Equatable, Sendable {
    var dimensions: DimensionsWire?
    var orientationEXIF: Int?
    var exposureTimeSeconds: Double?
    var sensitivityISO: Double?
    var apertureFNumber: Double?
    var focalLengthMillimeters: Double?
}

extension DeliveredWire: Codable {
    private enum CodingKeys: String, CodingKey {
        case dimensions, orientationEXIF, exposureTimeSeconds
        case sensitivityISO, apertureFNumber, focalLengthMillimeters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dimensions = try decodeDimensions(
            .dimensions, prefix: "delivered.dimensions", in: container
        )
        orientationEXIF = try nullable(Int.self, .orientationEXIF, "delivered.orientationEXIF", in: container)
        exposureTimeSeconds = try nullable(
            Double.self, .exposureTimeSeconds, "delivered.exposureTimeSeconds", in: container
        )
        sensitivityISO = try nullable(Double.self, .sensitivityISO, "delivered.sensitivityISO", in: container)
        apertureFNumber = try nullable(Double.self, .apertureFNumber, "delivered.apertureFNumber", in: container)
        focalLengthMillimeters = try nullable(
            Double.self, .focalLengthMillimeters, "delivered.focalLengthMillimeters", in: container
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try encodeNullable(dimensions, .dimensions, in: &container)
        try encodeNullable(orientationEXIF, .orientationEXIF, in: &container)
        try encodeNullable(exposureTimeSeconds, .exposureTimeSeconds, in: &container)
        try encodeNullable(sensitivityISO, .sensitivityISO, in: &container)
        try encodeNullable(apertureFNumber, .apertureFNumber, in: &container)
        try encodeNullable(focalLengthMillimeters, .focalLengthMillimeters, in: &container)
    }
}

/// Wire form of one `timing` entry. Milliseconds are a monotonic duration.
private struct PhaseWire: Equatable, Sendable {
    var name: String
    var milliseconds: Double
}

extension PhaseWire: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, milliseconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try required(String.self, .name, "timing.name", in: container)
        milliseconds = try required(Double.self, .milliseconds, "timing.milliseconds", in: container)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(milliseconds, forKey: .milliseconds)
    }
}

/// Wire form of the `original` object. Byte count is bytes, never pixels.
private struct OriginalWire: Equatable, Sendable {
    var fileName: String
    var byteCount: UInt64
    var validation: String
}

extension OriginalWire: Codable {
    private enum CodingKeys: String, CodingKey {
        case fileName, byteCount, validation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileName = try required(String.self, .fileName, "original.fileName", in: container)
        byteCount = try required(UInt64.self, .byteCount, "original.byteCount", in: container)
        validation = try required(String.self, .validation, "original.validation", in: container)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(byteCount, forKey: .byteCount)
        try container.encode(validation, forKey: .validation)
    }
}

/// Wire form of the `recovery` object. `unavailableFields` names appendix keys.
private struct RecoveryWire: Equatable, Sendable {
    var wasRecovered: Bool
    var unavailableFields: [String]
}

extension RecoveryWire: Codable {
    private enum CodingKeys: String, CodingKey {
        case wasRecovered, unavailableFields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wasRecovered = try required(Bool.self, .wasRecovered, "recovery.wasRecovered", in: container)
        unavailableFields = try required(
            [String].self, .unavailableFields, "recovery.unavailableFields", in: container
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(wasRecovered, forKey: .wasRecovered)
        try container.encode(unavailableFields, forKey: .unavailableFields)
    }
}

/// Wire form of `capture.json` version 1. The identity and environment groups
/// of `CaptureMetadata` flatten into the top-level keys of this type. The
/// `requested`, `delivered`, `original`, and `recovery` groups stay objects.
private struct CaptureMetadataWire: Equatable, Sendable {
    var schemaVersion: Int
    var captureId: UUID
    var sessionId: UUID
    var requestOrdinal: UInt64
    var libraryOrder: UInt64
    var requestedAtUTC: Date?
    var committedAtUTC: Date?
    var appBuild: String?
    var osBuild: String?
    var deviceModel: String?
    var cameraDeviceType: String?
    var cameraPosition: String?
    var zoomFactor: Double?
    var requested: RequestedWire?
    var delivered: DeliveredWire
    var timing: [PhaseWire]
    var original: OriginalWire
    var recovery: RecoveryWire
}

extension CaptureMetadataWire: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, captureId, sessionId, requestOrdinal, libraryOrder
        case requestedAtUTC, committedAtUTC
        case appBuild, osBuild, deviceModel, cameraDeviceType, cameraPosition, zoomFactor
        case requested, delivered, timing, original, recovery
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try required(Int.self, .schemaVersion, "schemaVersion", in: container)
        guard version == CaptureMetadataSchema.version1 else {
            throw MetadataCodecFailure.unsupportedVersion(found: version)
        }
        schemaVersion = version
        captureId = try required(UUID.self, .captureId, "captureId", in: container)
        sessionId = try required(UUID.self, .sessionId, "sessionId", in: container)
        requestOrdinal = try required(UInt64.self, .requestOrdinal, "requestOrdinal", in: container)
        libraryOrder = try required(UInt64.self, .libraryOrder, "libraryOrder", in: container)
        requestedAtUTC = try nullable(Date.self, .requestedAtUTC, "requestedAtUTC", in: container)
        committedAtUTC = try nullable(Date.self, .committedAtUTC, "committedAtUTC", in: container)
        appBuild = try nullable(String.self, .appBuild, "appBuild", in: container)
        osBuild = try nullable(String.self, .osBuild, "osBuild", in: container)
        deviceModel = try nullable(String.self, .deviceModel, "deviceModel", in: container)
        cameraDeviceType = try nullable(String.self, .cameraDeviceType, "cameraDeviceType", in: container)
        cameraPosition = try nullable(String.self, .cameraPosition, "cameraPosition", in: container)
        zoomFactor = try nullable(Double.self, .zoomFactor, "zoomFactor", in: container)
        requested = try nullable(RequestedWire.self, .requested, "requested", in: container)
        delivered = try required(DeliveredWire.self, .delivered, "delivered", in: container)
        timing = try required([PhaseWire].self, .timing, "timing", in: container)
        original = try required(OriginalWire.self, .original, "original", in: container)
        recovery = try required(RecoveryWire.self, .recovery, "recovery", in: container)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(captureId, forKey: .captureId)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(requestOrdinal, forKey: .requestOrdinal)
        try container.encode(libraryOrder, forKey: .libraryOrder)
        try encodeNullable(requestedAtUTC, .requestedAtUTC, in: &container)
        try encodeNullable(committedAtUTC, .committedAtUTC, in: &container)
        try encodeNullable(appBuild, .appBuild, in: &container)
        try encodeNullable(osBuild, .osBuild, in: &container)
        try encodeNullable(deviceModel, .deviceModel, in: &container)
        try encodeNullable(cameraDeviceType, .cameraDeviceType, in: &container)
        try encodeNullable(cameraPosition, .cameraPosition, in: &container)
        try encodeNullable(zoomFactor, .zoomFactor, in: &container)
        try encodeNullable(requested, .requested, in: &container)
        try container.encode(delivered, forKey: .delivered)
        try container.encode(timing, forKey: .timing)
        try container.encode(original, forKey: .original)
        try container.encode(recovery, forKey: .recovery)
    }
}

/// Encodes and decodes `capture.json` version 1 without file operations.
/// The codec accepts unknown keys on decode and never writes them on encode.
/// Timestamps are ISO 8601 UTC strings; durations are milliseconds.
public enum CaptureMetadataCodec {
    /// Serialize one metadata value. Rejects any schema version other than 1
    /// and any `recovery.unavailableFields` entry outside the appendix keys.
    public static func encode(_ metadata: CaptureMetadata) throws -> Data {
        guard metadata.schemaVersion == CaptureMetadataSchema.version1 else {
            throw MetadataCodecFailure.unsupportedVersion(found: metadata.schemaVersion)
        }
        for field in metadata.recovery.unavailableFields
        where !CaptureMetadataKeys.appendixKeys.contains(field) {
            throw MetadataCodecFailure.invalidValue(field: "recovery.unavailableFields", found: field)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(CaptureMetadataWire(metadata: metadata))
    }

    /// Parse one stored file. Unknown keys are ignored; their values cannot
    /// change how a known key is read. Every appendix key must be present.
    public static func decode(_ data: Data) throws -> CaptureMetadata {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let wire: CaptureMetadataWire
        do {
            wire = try decoder.decode(CaptureMetadataWire.self, from: data)
        } catch let error as MetadataCodecFailure {
            throw error
        } catch let error as DecodingError {
            throw MetadataCodecFailure.decoding(error, field: "capture.json")
        }
        return try wire.toMetadata()
    }
}

extension CaptureMetadataWire {
    /// Map a stored value onto the shared value contracts.
    init(metadata: CaptureMetadata) {
        self.init(
            schemaVersion: metadata.schemaVersion,
            captureId: metadata.identity.captureId,
            sessionId: metadata.identity.sessionId,
            requestOrdinal: metadata.identity.requestOrdinal,
            libraryOrder: metadata.identity.libraryOrder.value,
            requestedAtUTC: metadata.requestedAtUTC,
            committedAtUTC: metadata.committedAtUTC,
            appBuild: metadata.environment?.appBuild,
            osBuild: metadata.environment?.osBuild,
            deviceModel: metadata.environment?.deviceModel,
            cameraDeviceType: metadata.environment?.cameraDeviceType,
            cameraPosition: metadata.environment?.cameraPosition,
            zoomFactor: metadata.environment?.zoomFactor,
            requested: metadata.requested.map(RequestedWire.init),
            delivered: DeliveredWire(metadata.delivered),
            timing: metadata.timing.map(PhaseWire.init),
            original: OriginalWire(metadata.original),
            recovery: RecoveryWire(metadata.recovery)
        )
    }

    /// Build the shared value contracts from a decoded file.
    func toMetadata() throws -> CaptureMetadata {
        let identity = CaptureIdentity(
            captureId: captureId,
            sessionId: sessionId,
            requestOrdinal: requestOrdinal,
            libraryOrder: LibraryOrder(libraryOrder)
        )
        return CaptureMetadata(
            schemaVersion: schemaVersion,
            identity: identity,
            requestedAtUTC: requestedAtUTC,
            committedAtUTC: committedAtUTC,
            environment: try environmentGroup(),
            requested: try requestedGroup(),
            delivered: delivered.toDelivered(),
            timing: timing.map { PhaseDuration(name: $0.name, milliseconds: $0.milliseconds) },
            original: try original.toDescriptor(),
            recovery: try recovery.toRecoveryMetadata()
        )
    }

    /// The flattened environment group is all null or all present.
    private func environmentGroup() throws -> CaptureEnvironment? {
        var nullKeys = ["appBuild": appBuild, "osBuild": osBuild, "deviceModel": deviceModel,
                        "cameraDeviceType": cameraDeviceType, "cameraPosition": cameraPosition]
            .filter { $0.value == nil }
            .map(\.key)
        if zoomFactor == nil { nullKeys.append("zoomFactor") }
        nullKeys.sort()
        if nullKeys.count == 6 { return nil }
        if nullKeys.isEmpty,
           let appBuild, let osBuild, let deviceModel,
           let cameraDeviceType, let cameraPosition, let zoomFactor {
            return CaptureEnvironment(
                appBuild: appBuild,
                osBuild: osBuild,
                deviceModel: deviceModel,
                cameraDeviceType: cameraDeviceType,
                cameraPosition: cameraPosition,
                zoomFactor: zoomFactor
            )
        }
        throw MetadataCodecFailure.partiallyNullGroup(field: "environment", nullKeys: nullKeys)
    }

    private func requestedGroup() throws -> RequestedCapture? {
        guard let requested else { return nil }
        guard let quality = PhotoQuality(rawValue: requested.qualityPriority) else {
            throw MetadataCodecFailure.invalidValue(
                field: "requested.qualityPriority", found: requested.qualityPriority
            )
        }
        guard let orientation = CaptureOrientation(rawValue: requested.orientation) else {
            throw MetadataCodecFailure.invalidValue(
                field: "requested.orientation", found: requested.orientation
            )
        }
        guard let focusState = RequestedFocus(rawValue: requested.focusState) else {
            throw MetadataCodecFailure.invalidValue(
                field: "requested.focusState", found: requested.focusState
            )
        }
        guard let input = CaptureInput(rawValue: requested.input) else {
            throw MetadataCodecFailure.invalidValue(
                field: "requested.input", found: requested.input
            )
        }
        return RequestedCapture(
            rawPixelFormat: requested.rawPixelFormat,
            maximumDimensions: PixelDimensions(
                width: requested.maximumDimensions.width,
                height: requested.maximumDimensions.height
            ),
            qualityPriority: quality,
            exposureCompensationEV: requested.exposureCompensationEV,
            orientation: orientation,
            focusState: focusState,
            input: input
        )
    }
}

extension DeliveredWire {
    init(_ delivered: DeliveredCapture) {
        self.init(
            dimensions: delivered.dimensions.map { DimensionsWire(width: $0.width, height: $0.height) },
            orientationEXIF: delivered.orientationEXIF,
            exposureTimeSeconds: delivered.exposureTimeSeconds,
            sensitivityISO: delivered.sensitivityISO,
            apertureFNumber: delivered.apertureFNumber,
            focalLengthMillimeters: delivered.focalLengthMillimeters
        )
    }

    func toDelivered() -> DeliveredCapture {
        DeliveredCapture(
            dimensions: dimensions.map { PixelDimensions(width: $0.width, height: $0.height) },
            orientationEXIF: orientationEXIF,
            exposureTimeSeconds: exposureTimeSeconds,
            sensitivityISO: sensitivityISO,
            apertureFNumber: apertureFNumber,
            focalLengthMillimeters: focalLengthMillimeters
        )
    }
}

extension RequestedWire {
    init(_ requested: RequestedCapture) {
        self.init(
            rawPixelFormat: requested.rawPixelFormat,
            maximumDimensions: DimensionsWire(
                width: requested.maximumDimensions.width,
                height: requested.maximumDimensions.height
            ),
            qualityPriority: requested.qualityPriority.rawValue,
            exposureCompensationEV: requested.exposureCompensationEV,
            orientation: requested.orientation.rawValue,
            focusState: requested.focusState.rawValue,
            input: requested.input.rawValue
        )
    }
}

extension PhaseWire {
    init(_ phase: PhaseDuration) {
        self.init(name: phase.name, milliseconds: phase.milliseconds)
    }
}

extension OriginalWire {
    init(_ original: OriginalDescriptor) {
        self.init(
            fileName: original.fileName,
            byteCount: original.byteCount,
            validation: original.validation.rawValue
        )
    }

    func toDescriptor() throws -> OriginalDescriptor {
        guard let validation = OriginalValidation(rawValue: validation) else {
            throw MetadataCodecFailure.invalidValue(field: "original.validation", found: validation)
        }
        return OriginalDescriptor(fileName: fileName, byteCount: byteCount, validation: validation)
    }
}

extension RecoveryWire {
    init(_ recovery: RecoveryMetadata) {
        self.init(wasRecovered: recovery.wasRecovered, unavailableFields: recovery.unavailableFields)
    }

    func toRecoveryMetadata() throws -> RecoveryMetadata {
        for field in unavailableFields where !CaptureMetadataKeys.appendixKeys.contains(field) {
            throw MetadataCodecFailure.invalidValue(field: "recovery.unavailableFields", found: field)
        }
        return RecoveryMetadata(wasRecovered: wasRecovered, unavailableFields: unavailableFields)
    }
}
