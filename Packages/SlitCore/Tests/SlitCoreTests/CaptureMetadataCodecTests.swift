import Foundation
import Testing
@testable import SlitCore

/// Synthetic fixtures for the capture.json version 1 codec. No device data.
struct CaptureMetadataCodecTests {
    private static let captureId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let sessionId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let requestedAt = Date(timeIntervalSince1970: 1_761_840_000)
    private static let committedAt = Date(timeIntervalSince1970: 1_761_840_002)

    private static let fullRequested = RequestedCapture(
        rawPixelFormat: 1_752_928_688,
        maximumDimensions: PixelDimensions(width: 4080, height: 3060),
        qualityPriority: .speed,
        exposureCompensationEV: -0.333,
        orientation: .landscapeRight,
        focusState: .verifiedLocked,
        input: .hardwarePrimary
    )

    private static let fullDelivered = DeliveredCapture(
        dimensions: PixelDimensions(width: 4080, height: 3060),
        orientationEXIF: 6,
        exposureTimeSeconds: 0.008,
        sensitivityISO: 64,
        apertureFNumber: 1.78,
        focalLengthMillimeters: 24.0
    )

    private static let fullEnvironment = CaptureEnvironment(
        appBuild: "1", osBuild: "23B5067a", deviceModel: "iPhone17,4",
        cameraDeviceType: "builtInWideAngleCamera", cameraPosition: "back", zoomFactor: 1.0
    )

    /// Build one synthetic metadata value. Override a parameter to build a
    /// partial value for a negative case.
    private static func metadata(
        schemaVersion: Int = 1,
        requested: RequestedCapture? = fullRequested,
        delivered: DeliveredCapture = fullDelivered,
        environment: CaptureEnvironment? = fullEnvironment,
        requestedAtUTC: Date? = requestedAt,
        committedAtUTC: Date? = committedAt,
        recovery: RecoveryMetadata = RecoveryMetadata(wasRecovered: false, unavailableFields: [])
    ) -> CaptureMetadata {
        CaptureMetadata(
            schemaVersion: schemaVersion,
            identity: CaptureIdentity(
                captureId: captureId, sessionId: sessionId,
                requestOrdinal: 3, libraryOrder: LibraryOrder(77)
            ),
            requestedAtUTC: requestedAtUTC,
            committedAtUTC: committedAtUTC,
            environment: environment,
            requested: requested,
            delivered: delivered,
            timing: [PhaseDuration(name: "requestOverhead", milliseconds: 12.5)],
            original: OriginalDescriptor(fileName: "original.dng", byteCount: 40_960, validation: .readableContainer),
            recovery: recovery
        )
    }

    /// Encode one value and return the compact JSON string.
    private static func encodedString(_ metadata: CaptureMetadata) throws -> String {
        String(data: try CaptureMetadataCodec.encode(metadata), encoding: .utf8)!
    }

    /// Decode one JSON string into metadata.
    private static func decode(_ json: String) throws -> CaptureMetadata {
        try CaptureMetadataCodec.decode(Data(json.utf8))
    }

    /// Parse encoded output into a JSON object for key-level assertions.
    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// A compact single-line file with every optional value unavailable.
    /// Negative cases mutate this string by exact fragment replacement.
    private static let minimalJSON = """
    {"schemaVersion":1,"captureId":"11111111-1111-1111-1111-111111111111","sessionId":"22222222-2222-2222-2222-222222222222","requestOrdinal":3,"libraryOrder":77,"requestedAtUTC":null,"committedAtUTC":null,"appBuild":null,"osBuild":null,"deviceModel":null,"cameraDeviceType":null,"cameraPosition":null,"zoomFactor":null,"requested":null,"delivered":{"dimensions":null,"orientationEXIF":null,"exposureTimeSeconds":null,"sensitivityISO":null,"apertureFNumber":null,"focalLengthMillimeters":null},"timing":[],"original":{"fileName":"original.dng","byteCount":1,"validation":"readableContainer"},"recovery":{"wasRecovered":true,"unavailableFields":["requested","committedAtUTC","delivered.exposureTimeSeconds"]}}
    """

    @Test func roundTripPreservesEveryField() throws {
        let original = Self.metadata()
        let decoded = try CaptureMetadataCodec.decode(try CaptureMetadataCodec.encode(original))
        #expect(decoded == original)
    }

    /// Unavailable measurements, groups, and timestamps encode as explicit
    /// JSON null values, not fabricated zeros and not omitted keys.
    @Test func unavailableValuesEncodeAsExplicitNulls() throws {
        let emptyDelivered = DeliveredCapture(
            dimensions: nil, orientationEXIF: nil, exposureTimeSeconds: nil,
            sensitivityISO: nil, apertureFNumber: nil, focalLengthMillimeters: nil
        )
        let original = Self.metadata(
            requested: nil, delivered: emptyDelivered, environment: nil,
            requestedAtUTC: nil, committedAtUTC: nil
        )
        let object = try Self.jsonObject(try CaptureMetadataCodec.encode(original))
        #expect(object["requested"] is NSNull)
        #expect(object["requestedAtUTC"] is NSNull)
        #expect(object["committedAtUTC"] is NSNull)
        for key in ["appBuild", "osBuild", "deviceModel", "cameraDeviceType", "cameraPosition", "zoomFactor"] {
            #expect(object[key] is NSNull)
        }
        let delivered = try #require(object["delivered"] as? [String: Any])
        for key in ["dimensions", "orientationEXIF", "exposureTimeSeconds", "sensitivityISO",
                    "apertureFNumber", "focalLengthMillimeters"] {
            #expect(delivered[key] is NSNull)
        }
    }

    @Test func unknownKeysAreIgnoredOnDecodeAndNeverWrittenOnEncode() throws {
        var json = try Self.encodedString(Self.metadata())
        json = json.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"futureTop\":{\"a\":1}")
        json = json.replacingOccurrences(of: "\"delivered\":{", with: "\"delivered\":{\"futureDelivered\":true,")
        let decoded = try Self.decode(json)
        #expect(decoded == Self.metadata())

        let rewritten = try Self.jsonObject(try CaptureMetadataCodec.encode(decoded))
        #expect(rewritten["futureTop"] == nil)
        let delivered = try #require(rewritten["delivered"] as? [String: Any])
        #expect(delivered["futureDelivered"] == nil)
    }

    @Test func missingAppendixKeyFailsExplicitly() throws {
        var json = try Self.encodedString(Self.metadata())
        json = json.replacingOccurrences(of: "\"libraryOrder\":77,", with: "")
        #expect(throws: MetadataCodecFailure.missingField("libraryOrder")) {
            try Self.decode(json)
        }
    }

    /// Unavailability must be written as an explicit null. An absent nullable
    /// key is a missing field under the appendix, not a third encoding.
    @Test func missingNullableKeyFailsExplicitly() throws {
        var json = try Self.encodedString(Self.metadata(requestedAtUTC: nil))
        json = json.replacingOccurrences(of: "\"requestedAtUTC\":null,", with: "")
        #expect(throws: MetadataCodecFailure.missingField("requestedAtUTC")) {
            try Self.decode(json)
        }
    }

    @Test func missingNestedKeyFailsExplicitly() throws {
        var json = try Self.encodedString(Self.metadata())
        json = json.replacingOccurrences(of: ",\"validation\":\"readableContainer\"", with: "")
        #expect(throws: MetadataCodecFailure.missingField("original.validation")) {
            try Self.decode(json)
        }
    }

    /// A decode failure inside a delivered measurement names the delivered
    /// path, never the requested path.
    @Test func deliveredDimensionFailuresNameTheDeliveredPath() throws {
        let encoded = try Self.encodedString(Self.metadata())
        let missingWidth = encoded.replacingOccurrences(
            of: "\"apertureFNumber\":1.78,\"dimensions\":{\"height\":3060,\"width\":4080}",
            with: "\"apertureFNumber\":1.78,\"dimensions\":{\"height\":3060}"
        )
        #expect(missingWidth != encoded)
        #expect(throws: MetadataCodecFailure.missingField("delivered.dimensions.width")) {
            try Self.decode(missingWidth)
        }

        let missingHeight = encoded.replacingOccurrences(
            of: "\"apertureFNumber\":1.78,\"dimensions\":{\"height\":3060,\"width\":4080}",
            with: "\"apertureFNumber\":1.78,\"dimensions\":{\"width\":4080}"
        )
        #expect(missingHeight != encoded)
        #expect(throws: MetadataCodecFailure.missingField("delivered.dimensions.height")) {
            try Self.decode(missingHeight)
        }
    }

    @Test func nullForANeverNullKeyFailsExplicitly() {
        let deliveredNull = Self.minimalJSON.replacingOccurrences(
            of: "\"delivered\":{\"dimensions\":null,\"orientationEXIF\":null,\"exposureTimeSeconds\":null,\"sensitivityISO\":null,\"apertureFNumber\":null,\"focalLengthMillimeters\":null}",
            with: "\"delivered\":null"
        )
        #expect(deliveredNull != Self.minimalJSON)
        #expect(throws: MetadataCodecFailure.nullField("delivered")) {
            try Self.decode(deliveredNull)
        }

        let timingNull = Self.minimalJSON.replacingOccurrences(of: "\"timing\":[]", with: "\"timing\":null")
        #expect(timingNull != Self.minimalJSON)
        #expect(throws: MetadataCodecFailure.nullField("timing")) {
            try Self.decode(timingNull)
        }
    }

    @Test func unsupportedVersionFailsExplicitlyOnDecode() throws {
        var json = try Self.encodedString(Self.metadata())
        json = json.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2")
        #expect(throws: MetadataCodecFailure.unsupportedVersion(found: 2)) {
            try Self.decode(json)
        }
    }

    @Test func unsupportedVersionFailsExplicitlyOnEncode() {
        #expect(throws: MetadataCodecFailure.unsupportedVersion(found: 9)) {
            try CaptureMetadataCodec.encode(Self.metadata(schemaVersion: 9))
        }
    }

    /// The closed value lists are complete for version 1. A value outside a
    /// list fails validation explicitly.
    @Test func closedValueListsRejectValuesOutsideTheList() throws {
        let substitutions: [(fragment: String, replacement: String, field: String, found: String)] = [
            ("\"orientation\":\"landscapeRight\"", "\"orientation\":\"upsideDown\"", "requested.orientation", "upsideDown"),
            ("\"qualityPriority\":\"speed\"", "\"qualityPriority\":\"balanced\"", "requested.qualityPriority", "balanced"),
            ("\"focusState\":\"verifiedLocked\"", "\"focusState\":\"manual\"", "requested.focusState", "manual"),
            ("\"input\":\"hardwarePrimary\"", "\"input\":\"volumeButton\"", "requested.input", "volumeButton"),
            ("\"validation\":\"readableContainer\"", "\"validation\":\"checksummed\"", "original.validation", "checksummed")
        ]
        for case let (fragment, replacement, field, found) in substitutions {
            var json = try Self.encodedString(Self.metadata())
            json = json.replacingOccurrences(of: fragment, with: replacement)
            #expect(throws: MetadataCodecFailure.invalidValue(field: field, found: found)) {
                try Self.decode(json)
            }
        }
    }

    @Test func environmentGroupMustBeAllNullOrAllPresent() throws {
        var json = try Self.encodedString(Self.metadata())
        json = json.replacingOccurrences(of: "\"appBuild\":\"1\"", with: "\"appBuild\":null")
        #expect(throws: MetadataCodecFailure.partiallyNullGroup(
            field: "environment", nullKeys: ["appBuild"]
        )) {
            try Self.decode(json)
        }
    }

    @Test func unavailableFieldsMustNameAppendixKeysOnEncode() {
        let invalid = RecoveryMetadata(
            wasRecovered: true, unavailableFields: ["delivered.exposureTimeSeconds", "inventedKey"]
        )
        #expect(throws: MetadataCodecFailure.invalidValue(
            field: "recovery.unavailableFields", found: "inventedKey"
        )) {
            try CaptureMetadataCodec.encode(Self.metadata(recovery: invalid))
        }
    }

    @Test func unavailableFieldsMustNameAppendixKeysOnDecode() {
        let invalid = Self.minimalJSON.replacingOccurrences(
            of: "\"unavailableFields\":[\"requested\",\"committedAtUTC\",\"delivered.exposureTimeSeconds\"]",
            with: "\"unavailableFields\":[\"inventedKey\"]"
        )
        #expect(invalid != Self.minimalJSON)
        #expect(throws: MetadataCodecFailure.invalidValue(
            field: "recovery.unavailableFields", found: "inventedKey"
        )) {
            try Self.decode(invalid)
        }
    }

    /// A minimal file: no environment, no requested snapshot, no delivered
    /// measurement, no timing. Every unavailable value is an explicit null.
    @Test func minimalFileWithUnavailableGroupsDecodes() throws {
        let decoded = try Self.decode(Self.minimalJSON)
        #expect(decoded.environment == nil)
        #expect(decoded.requested == nil)
        #expect(decoded.requestedAtUTC == nil)
        #expect(decoded.committedAtUTC == nil)
        #expect(decoded.timing.isEmpty)
        #expect(decoded.recovery.wasRecovered)
        #expect(decoded.recovery.unavailableFields == ["requested", "committedAtUTC", "delivered.exposureTimeSeconds"])
        #expect(decoded.delivered == DeliveredCapture(
            dimensions: nil, orientationEXIF: nil, exposureTimeSeconds: nil,
            sensitivityISO: nil, apertureFNumber: nil, focalLengthMillimeters: nil
        ))
        #expect(decoded.original == OriginalDescriptor(
            fileName: "original.dng", byteCount: 1, validation: .readableContainer
        ))
        #expect(decoded.identity.requestOrdinal == 3)
        #expect(decoded.identity.libraryOrder == LibraryOrder(77))
    }
}
