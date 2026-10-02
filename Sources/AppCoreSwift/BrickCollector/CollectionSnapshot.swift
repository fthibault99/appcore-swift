import Foundation

/// Metadata confirming storage of the complete Brick Collector collection snapshot.
public struct BrickCollectorCollectionSnapshotStoredResponse: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    /// Snapshot generation timestamp, kept as a server ISO-8601 string.
    public let generatedAt: String
    /// Server storage timestamp, preserving fractional seconds.
    public let storedAt: String

    public init(schemaVersion: Int, generatedAt: String, storedAt: String) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.storedAt = storedAt
    }
}
