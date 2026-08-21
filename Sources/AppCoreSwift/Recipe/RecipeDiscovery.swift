import Foundation

public struct InventoryRecipeProduct: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let quantity: Decimal?
    public let unit: String?
    public let storageSpace: String?
    public let storeDepartment: String?

    public init(
        id: String,
        name: String,
        quantity: Decimal? = nil,
        unit: String? = nil,
        storageSpace: String? = nil,
        storeDepartment: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.storageSpace = storageSpace
        self.storeDepartment = storeDepartment
    }
}

public struct RecipeDiscoveryRequest: Codable, Equatable, Sendable {
    public let locale: String
    public let priorityProductIds: [String]
    public let comment: String?
    public let inventory: [InventoryRecipeProduct]

    public init(
        locale: String,
        priorityProductIds: [String] = [],
        comment: String? = nil,
        inventory: [InventoryRecipeProduct]
    ) {
        self.locale = locale
        self.priorityProductIds = priorityProductIds
        self.comment = comment
        self.inventory = inventory
    }
}

public struct DiscoveredRecipe: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let sourceName: String
    public let sourceURL: URL
    public let imageURL: URL
    public let language: String
    public let matchedProducts: [String]

    public init(
        id: String,
        title: String,
        sourceName: String,
        sourceURL: URL,
        imageURL: URL,
        language: String,
        matchedProducts: [String]
    ) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.imageURL = imageURL
        self.language = language
        self.matchedProducts = matchedProducts
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, sourceName, language, matchedProducts
        case sourceURL = "sourceUrl"
        case imageURL = "imageUrl"
    }
}

public struct RecipeDiscoveryResult: Codable, Equatable, Sendable {
    public let recipes: [DiscoveredRecipe]

    public init(recipes: [DiscoveredRecipe]) {
        self.recipes = recipes
    }
}

public enum RecipeDiscoveryState: String, Codable, Equatable, Sendable {
    case analyzingInventory = "ANALYZING_INVENTORY"
    case rankingRecipes = "RANKING_RECIPES"
    case selectingProducts = "SELECTING_PRODUCTS"
    case searchingWeb = "SEARCHING_WEB"
    case generatingResults = "GENERATING_RESULTS"
    case resolvingImages = "RESOLVING_IMAGES"
}

public struct RecipeDiscoveryFailure: Codable, Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public enum RecipeDiscoveryStreamEvent: Equatable, Sendable {
    case progress(RecipeDiscoveryState)
    case result(RecipeDiscoveryResult)
    case failure(RecipeDiscoveryFailure)
}

struct RecipeDiscoveryProgress: Codable {
    let state: RecipeDiscoveryState
}
