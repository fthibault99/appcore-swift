import Foundation

/// A LEGO set reference stored in a shared Brick Collector album.
public struct SharedAlbumItem: Codable, Equatable, Sendable {
    public let setNumber: String
    public let sortOrder: Int

    public init(setNumber: String, sortOrder: Int) {
        self.setNumber = setNumber
        self.sortOrder = sortOrder
    }
}

/// Owner-only response returned when a shared album is created.
public struct CreateSharedAlbumResponse: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let readToken: UUID
    public let manageToken: UUID
    public let updatedAt: String

    public init(
        id: UUID,
        name: String,
        readToken: UUID,
        manageToken: UUID,
        updatedAt: String
    ) {
        self.id = id
        self.name = name
        self.readToken = readToken
        self.manageToken = manageToken
        self.updatedAt = updatedAt
    }
}

/// Read-safe shared album representation. It deliberately contains no token or internal ID.
public struct SharedAlbum: Codable, Equatable, Sendable {
    public let name: String
    public let updatedAt: String
    public let items: [SharedAlbumItem]

    public init(name: String, updatedAt: String, items: [SharedAlbumItem]) {
        self.name = name
        self.updatedAt = updatedAt
        self.items = items
    }
}

struct SharedAlbumRequest: Encodable {
    let name: String
    let items: [SharedAlbumItem]
}
