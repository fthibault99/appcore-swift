import Foundation

public struct DishRecreationImage: Equatable, Sendable {
    public let data: Data
    public let fileName: String
    public let mediaType: RecipeImageMediaType

    public init(data: Data, fileName: String, mediaType: RecipeImageMediaType) {
        self.data = data
        self.fileName = fileName
        self.mediaType = mediaType
    }
}

public struct DishRecreationRequest: Equatable, Sendable {
    public let dishName: String
    public let restaurantName: String?
    public let restaurantLocation: String?
    public let description: String?
    public let servings: Int?
    public let language: LanguageCode?
    public let dishImage: DishRecreationImage?
    public let menuImage: DishRecreationImage?

    public init(
        dishName: String,
        restaurantName: String? = nil,
        restaurantLocation: String? = nil,
        description: String? = nil,
        servings: Int? = nil,
        language: LanguageCode? = nil,
        dishImage: DishRecreationImage? = nil,
        menuImage: DishRecreationImage? = nil
    ) {
        self.dishName = dishName
        self.restaurantName = restaurantName
        self.restaurantLocation = restaurantLocation
        self.description = description
        self.servings = servings
        self.language = language
        self.dishImage = dishImage
        self.menuImage = menuImage
    }
}

public enum DishRecreationState: String, Codable, Equatable, Sendable {
    case analyzingImage = "ANALYZING_IMAGE"
    case searchingWeb = "SEARCHING_WEB"
    case generatingRecipe = "GENERATING_RECIPE"
}

public enum RecipeComponentType: String, Codable, Equatable, Sendable {
    case main = "MAIN"
    case side = "SIDE"
    case sauce = "SAUCE"
    case dessert = "DESSERT"
    case other = "OTHER"
}

public struct GeneratedRecipeComponent: Codable, Equatable, Sendable {
    public let type: RecipeComponentType
    public let recipe: Recipe

    public init(type: RecipeComponentType, recipe: Recipe) {
        self.type = type
        self.recipe = recipe
    }
}

public struct DishRecreationResult: Codable, Equatable, Sendable {
    public let name: String
    public let recipes: [GeneratedRecipeComponent]

    public init(name: String, recipes: [GeneratedRecipeComponent]) {
        self.name = name
        self.recipes = recipes
    }
}

public struct DishRecreationFailure: Codable, Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public enum DishRecreationStreamEvent: Equatable, Sendable {
    case progress(DishRecreationState)
    case result(DishRecreationResult)
    case failure(DishRecreationFailure)
}

struct DishRecreationProgress: Codable {
    let state: DishRecreationState
}
