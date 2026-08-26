public struct ClassifyRecipeMealTypesRequest: Codable, Equatable, Sendable {
    public let recipe: Recipe
    public let locale: String
    public let mealTypes: [String]

    public init(recipe: Recipe, locale: String, mealTypes: [String]) {
        self.recipe = recipe
        self.locale = locale
        self.mealTypes = mealTypes
    }
}

public struct MealTypeClassificationResponse: Codable, Equatable, Sendable {
    public let mealTypes: [String]

    public init(mealTypes: [String]) {
        self.mealTypes = mealTypes
    }
}

public struct ClassifyRecipeTagsRequest: Codable, Equatable, Sendable {
    public let recipe: Recipe
    public let locale: String
    public let tags: [String]

    public init(recipe: Recipe, locale: String, tags: [String]) {
        self.recipe = recipe
        self.locale = locale
        self.tags = tags
    }
}

public struct RecipeTagClassificationResponse: Codable, Equatable, Sendable {
    public let matchingTags: [String]
    public let suggestedTags: [String]

    public init(matchingTags: [String], suggestedTags: [String]) {
        self.matchingTags = matchingTags
        self.suggestedTags = suggestedTags
    }
}
