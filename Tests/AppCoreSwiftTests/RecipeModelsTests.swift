import Foundation
import XCTest
@testable import AppCoreSwift

final class RecipeModelsTests: XCTestCase {
    func testDecodesRecipeUsingAppCoreFieldNames() throws {
        let data = Data(
            #"{"url":"https://example.com/recipe","name":"Toast","image":["https://example.com/toast.jpg"],"author":null,"datePublished":null,"description":"Simple toast","prepTime":"PT2M","cookTime":"PT3M","totalTime":"PT5M","keywords":"breakfast","recipeIngredient":["2 slices bread"],"recipeInstructions":["Toast bread."],"recipeYield":"2 servings"}"#.utf8
        )

        let recipe = try JSONDecoder().decode(Recipe.self, from: data)

        XCTAssertEqual(recipe.name, "Toast")
        XCTAssertEqual(recipe.image, ["https://example.com/toast.jpg"])
        XCTAssertEqual(recipe.recipeIngredient, ["2 slices bread"])
        XCTAssertEqual(recipe.recipeInstructions, ["Toast bread."])
        XCTAssertEqual(recipe.totalTime, "PT5M")
    }

    func testTranslationRequestEncodesTwoLetterLanguageCode() throws {
        let request = TranslateRecipeRequest(
            targetLanguage: LanguageCode("FR")!,
            recipe: Recipe(
                name: "Toast",
                recipeIngredient: ["bread"],
                recipeInstructions: ["Toast it."]
            )
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )

        XCTAssertEqual(object["targetLanguage"] as? String, "fr")
        XCTAssertNotNil(object["recipe"] as? [String: Any])
    }

    func testWebContentTypeMatchesJavaEnumValues() {
        XCTAssertEqual(WebRecipeContentType.text.rawValue, "TEXT")
        XCTAssertEqual(WebRecipeContentType.jsonLD.rawValue, "JSON_LD")
    }

    func testDecodesRecipeTagClassificationResponse() throws {
        let data = Data(
            #"{"matchingTags":["Rapide","Familial"],"suggestedTags":["Tout-en-un"]}"#.utf8
        )

        let response = try JSONDecoder().decode(RecipeTagClassificationResponse.self, from: data)

        XCTAssertEqual(response.matchingTags, ["Rapide", "Familial"])
        XCTAssertEqual(response.suggestedTags, ["Tout-en-un"])
    }
}
