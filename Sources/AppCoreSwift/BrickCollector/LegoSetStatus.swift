/// LEGO set numbers currently listed in the official Coming Soon and Last Chance categories.
public struct LegoSetStatus: Codable, Equatable, Sendable {
    public let comingSoon: [String]
    public let lastChance: [String]

    public init(comingSoon: [String], lastChance: [String]) {
        self.comingSoon = comingSoon
        self.lastChance = lastChance
    }
}
