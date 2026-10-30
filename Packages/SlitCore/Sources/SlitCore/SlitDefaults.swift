public enum SlitDefaults {
    public static let gridPreferenceKey = "slit.grid.enabled.v1"
    public static let gridInitiallyEnabled = false
    public static let maximumCaptureSlots = 2
    public static let focusTimeoutSeconds = 2.0
    public static let longPressSeconds = 0.5
    public static let previewCacheBytes = 64 * 1_024 * 1_024
    public static let diagnosticLimitBytes = 5 * 1_024 * 1_024
    public static let captureMetadataFileName = "capture.json"
    public static let orderHighWatermarkFileName = "order-high-watermark.json"
    public static let orderHighWatermarkSchemaVersion = 1
    public static let orderReservationBlockSize: UInt64 = 64
}
