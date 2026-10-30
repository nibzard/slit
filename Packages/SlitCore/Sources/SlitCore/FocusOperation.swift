import Foundation

/// Rejects completions from superseded focus operations and earlier sessions.
public struct FocusOperation: Sendable {
    public struct Token: Equatable, Sendable {
        public let session: UUID
        public let operation: UUID
    }

    public private(set) var session = UUID()
    public private(set) var pending: Token?
    public private(set) var isLocked = false

    public init() {}

    public mutating func begin() -> Token {
        let token = Token(session: session, operation: UUID())
        pending = token
        isLocked = false
        return token
    }

    /// The caller must verify the platform's lock completion before accepting it here.
    @discardableResult
    public mutating func confirmLock(_ token: Token) -> Bool {
        guard pending == token, token.session == session else { return false }
        pending = nil
        isLocked = true
        return true
    }

    public mutating func cancelPending() {
        pending = nil
    }

    public mutating func unlock() {
        pending = nil
        isLocked = false
    }

    public mutating func restartSession() {
        session = UUID()
        unlock()
    }
}
