import Foundation

/// A value type owned by the camera's serial executor. It is not a camera or a queue.
public struct CaptureAdmission: Sendable {
    public enum Phase: String, Codable, Sendable {
        case requested, delivered, saving, saveFailed
    }

    public enum Rejection: Error, Equatable, Sendable {
        case inactive, screenHidden, outputUnavailable, storageBlocked, capacityReached
        case duplicateIdentifier, unknownIdentifier, invalidTransition
    }

    public struct Context: Sendable {
        public var isActive: Bool
        public var isCaptureVisible: Bool
        public var isOutputReady: Bool
        public var isStorageWritable: Bool

        public init(isActive: Bool, isCaptureVisible: Bool, isOutputReady: Bool, isStorageWritable: Bool) {
            self.isActive = isActive
            self.isCaptureVisible = isCaptureVisible
            self.isOutputReady = isOutputReady
            self.isStorageWritable = isStorageWritable
        }
    }

    public private(set) var capacity: Int
    public private(set) var slots: [UUID: Phase] = [:]

    public init(capacity: Int = 2) {
        precondition((1...2).contains(capacity), "The MVP supports one or two slots")
        self.capacity = capacity
    }

    public mutating func setCapacity(_ value: Int) {
        precondition((1...2).contains(value))
        // Existing work is retained when pressure reduces the admission limit.
        capacity = value
    }

    public mutating func reserve(id: UUID, context: Context) throws {
        guard context.isActive else { throw Rejection.inactive }
        guard context.isCaptureVisible else { throw Rejection.screenHidden }
        guard context.isOutputReady else { throw Rejection.outputUnavailable }
        guard context.isStorageWritable else { throw Rejection.storageBlocked }
        guard slots[id] == nil else { throw Rejection.duplicateIdentifier }
        guard slots.count < capacity else { throw Rejection.capacityReached }
        slots[id] = .requested
    }

    public mutating func transition(id: UUID, to next: Phase) throws {
        guard let current = slots[id] else { throw Rejection.unknownIdentifier }
        switch (current, next) {
        case (.requested, .delivered), (.delivered, .saving), (.saving, .saveFailed), (.saveFailed, .saving):
            slots[id] = next
        default:
            throw Rejection.invalidTransition
        }
    }

    public mutating func didCommit(id: UUID) throws {
        guard slots[id] != nil else { throw Rejection.unknownIdentifier }
        guard slots[id] == .saving else { throw Rejection.invalidTransition }
        slots.removeValue(forKey: id)
    }

    /// Call only after no bytes remain to save, or after explicit unsaved-data discard.
    /// The caller owns data and must release it before calling this method.
    public mutating func releaseFailedRequest(id: UUID) throws {
        guard slots.removeValue(forKey: id) != nil else { throw Rejection.unknownIdentifier }
    }
}
