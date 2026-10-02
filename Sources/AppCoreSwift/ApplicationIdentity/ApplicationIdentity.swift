import Foundation

/// Identity created by AppCore for the application associated with the API key.
/// Store the ID and credential securely for subsequent pairing requests.
public struct CreateApplicationIdentityResponse: Codable, Equatable, Sendable {
    public let id: UUID
    public let credential: String
    public let createdAt: String

    public init(id: UUID, credential: String, createdAt: String) {
        self.id = id
        self.credential = credential
        self.createdAt = createdAt
    }
}

/// Temporary pairing code and its server-provided ISO-8601 expiration timestamp.
public struct CreateApplicationPairingCodeResponse: Codable, Equatable, Sendable {
    /// Kept as a string to preserve leading zeros.
    public let code: String
    public let expiresAt: String

    public init(code: String, expiresAt: String) {
        self.code = code
        self.expiresAt = expiresAt
    }
}

/// Whether the identity has a non-revoked, currently allowed OAuth connection.
/// This does not prove that a remote client or its tokens are currently usable.
public struct ApplicationConnectionStatus: Codable, Equatable, Sendable {
    public let connected: Bool

    public init(connected: Bool) {
        self.connected = connected
    }
}
