public struct TranslateRecipeRequest: Codable, Equatable, Sendable {
    public let targetLanguage: LanguageCode
    public let recipe: Recipe

    public init(targetLanguage: LanguageCode, recipe: Recipe) {
        self.targetLanguage = targetLanguage
        self.recipe = recipe
    }
}

public struct TranslateRecipeResponse: Codable, Equatable, Sendable {
    public let recipe: Recipe

    public init(recipe: Recipe) {
        self.recipe = recipe
    }
}

public struct ExtractRecipeFromTextRequest: Codable, Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct ExtractRecipeFromURLRequest: Codable, Equatable, Sendable {
    public let url: String

    public init(url: String) {
        self.url = url
    }
}

struct RecipeExtractionDomainsResponse: Codable, Equatable, Sendable {
    let domains: [String]
}

public enum WebRecipeContentType: String, Codable, Sendable {
    case text = "TEXT"
    case jsonLD = "JSON_LD"
}

public struct WebRecipeContentRequest: Codable, Equatable, Sendable {
    public let url: String
    public let contentType: WebRecipeContentType
    public let content: String

    public init(url: String, contentType: WebRecipeContentType, content: String) {
        self.url = url
        self.contentType = contentType
        self.content = content
    }
}

public struct ExtractRecipeProductsRequest: Codable, Equatable, Sendable {
    public let ingredients: [String]

    public init(ingredients: [String]) {
        self.ingredients = ingredients
    }
}

public struct IngredientProducts: Codable, Equatable, Sendable {
    public let ingredient: String
    public let products: [String]

    public init(ingredient: String, products: [String]) {
        self.ingredient = ingredient
        self.products = products
    }
}

public struct ExtractRecipeProductsResponse: Codable, Equatable, Sendable {
    public let ingredients: [IngredientProducts]

    public init(ingredients: [IngredientProducts]) {
        self.ingredients = ingredients
    }
}

public enum RecipeImageMediaType: String, Sendable {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case webP = "image/webp"
}
