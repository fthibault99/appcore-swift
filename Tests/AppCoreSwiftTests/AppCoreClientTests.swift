import Foundation
import XCTest
@testable import AppCoreSwift

final class AppCoreClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testBarcodeRequestUsesURLDomainAndAPIKeyHeader() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/LEGO/barcodes/0057000613280")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"barcode":"0057000613280","productName":"Classic Bricks","description":null,"brand":"LEGO","imageUrl":null}"#
            )
        }

        let product = try await makeClient().barcode("0057000613280", domain: .lego)

        XCTAssertEqual(product.barcode, "0057000613280")
        XCTAssertEqual(product.productName, "Classic Bricks")
    }

    func testTranslateRequestUsesExpectedBodyAndReturnsProduct() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/products/translate")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(object["targetLanguage"] as? String, "fr")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"product":{"barcode":"0057000613280","productName":"Briques classiques","description":null,"brand":"LEGO","imageUrl":null}}"#
            )
        }

        let translated = try await makeClient().translate(
            BarcodeProduct(barcode: "0057000613280", productName: "Classic Bricks"),
            to: LanguageCode("fr")!
        )

        XCTAssertEqual(translated.productName, "Briques classiques")
    }

    func testDescribeBrickSetUsesExpectedBodyAndReturnsDescription() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/brick-sets/describe")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(object["setCode"] as? String, "10307")
            XCTAssertEqual(object["setName"] as? String, "Eiffel Tower")
            XCTAssertEqual(object["language"] as? String, "fr")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"description":"Une imposante interprétation en briques de la tour Eiffel.","language":"fr"}"#
            )
        }

        let description = try await makeClient().describeBrickSet(
            code: "10307",
            name: "Eiffel Tower",
            in: LanguageCode("fr")!
        )

        XCTAssertEqual(
            description,
            "Une imposante interprétation en briques de la tour Eiffel."
        )
    }

    func testDescribeWineUsesExpectedBodyAndReturnsSwiftContract() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/wines/describe")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(object["name"] as? String, "Château Margaux 2015")
            XCTAssertEqual(object["language"] as? String, "fr")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"name":"Château Margaux 2015","description":"Un grand vin rouge de Bordeaux.","country":"France","region":"Bordeaux","pays_d'Oc":null,"regulated_designation":"Margaux","alcohol_content":null,"sugar_content":null,"color":"Rouge","format":null,"producer":"Château Margaux","type":"redWine"}"#
            )
        }

        let wine = try await makeClient().describeWine(
            named: "Château Margaux 2015",
            in: LanguageCode("FR")!
        )

        XCTAssertEqual(wine.name, "Château Margaux 2015")
        XCTAssertEqual(wine.description, "Un grand vin rouge de Bordeaux.")
        XCTAssertEqual(wine.regulatedDesignation, "Margaux")
        XCTAssertEqual(wine.type, "redWine")
        XCTAssertNil(wine.error)
    }

    func testDescribeWineDecodesLegacyNotAWineError() async throws {
        URLProtocolStub.requestHandler = { request in
            Self.response(
                for: request,
                statusCode: 200,
                body: #"{"error":"It's not a wine"}"#
            )
        }

        let result = try await makeClient().describeWine(
            named: "Apple juice",
            in: LanguageCode("en")!
        )

        XCTAssertEqual(result.error, "It's not a wine")
        XCTAssertNil(result.type)
        XCTAssertNil(result.description)
    }

    func testDescribeWineFromImageBuildsAuthenticatedMultipartRequest() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/wines/from-image")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let bodyText = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(bodyText.contains("name=\"language\"\r\n\r\nfr"))
            XCTAssertTrue(bodyText.contains("name=\"image\"; filename=\"wine.jpg\""))
            XCTAssertTrue(bodyText.contains("Content-Type: image/jpeg"))

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"name":"Château Margaux","description":"Un vin rouge.","type":"redWine"}"#
            )
        }

        let wine = try await makeClient().describeWine(
            fromImage: Data([0xFF, 0xD8, 0xFF]),
            fileName: "wine.jpg",
            mediaType: .jpeg,
            in: LanguageCode("FR")!
        )

        XCTAssertEqual(wine.name, "Château Margaux")
        XCTAssertEqual(wine.type, "redWine")
    }

    func testDescribeProductFromImageBuildsAuthenticatedMultipartRequest() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/products/from-image")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let bodyText = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(bodyText.contains("name=\"language\"\r\n\r\nfr"))
            XCTAssertTrue(bodyText.contains("name=\"image\"; filename=\"product.jpg\""))
            XCTAssertTrue(bodyText.contains("Content-Type: image/jpeg"))

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"name":"Nintendo Switch 2","description":"Une console de jeux vidéo portable."}"#
            )
        }

        let product = try await makeClient().describeProduct(
            fromImage: Data([0xFF, 0xD8, 0xFF]),
            fileName: "product.jpg",
            mediaType: .jpeg,
            in: LanguageCode("FR")!
        )

        XCTAssertEqual(product.name, "Nintendo Switch 2")
        XCTAssertEqual(product.description, "Une console de jeux vidéo portable.")
    }

    func testDescribeProductDecodesUnidentifiedProduct() async throws {
        URLProtocolStub.requestHandler = { request in
            Self.response(
                for: request,
                statusCode: 200,
                body: #"{"name":null,"description":null}"#
            )
        }

        let product = try await makeClient().describeProduct(
            fromImage: Data([0xFF, 0xD8, 0xFF]),
            fileName: "unknown.jpg",
            mediaType: .jpeg,
            in: LanguageCode("fr")!
        )

        XCTAssertNil(product.name)
        XCTAssertNil(product.description)
    }

    func testTranslateTextUsesExpectedBodyAndReturnsText() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/texts/translate")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(object["text"] as? String, "Bonjour le monde !")
            XCTAssertEqual(object["targetLanguage"] as? String, "en")
            XCTAssertEqual(
                object["context"] as? String,
                "Title of a collection of rare LEGO sets."
            )

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"text":"Hello, world!"}"#
            )
        }

        let translatedText = try await makeClient().translate(
            "Bonjour le monde !",
            to: LanguageCode("EN")!,
            context: "Title of a collection of rare LEGO sets."
        )

        XCTAssertEqual(translatedText, "Hello, world!")
    }

    func testTranslateTextOmitsContextWhenAbsent() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertNil(object["context"])

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"text":"Hello!"}"#
            )
        }

        let translatedText = try await makeClient().translate(
            "Bonjour !",
            to: LanguageCode("en")!
        )

        XCTAssertEqual(translatedText, "Hello!")
    }

    func testTaskListEndpointsUseAuthenticatedTypedRequests() async throws {
        let expectedPaths = ["subtasks", "risks", "questions"]
        var receivedPaths: [String] = []
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let operation = try XCTUnwrap(request.url?.lastPathComponent)
            receivedPaths.append(operation)
            XCTAssertTrue(expectedPaths.contains(operation))

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["task"] as? String, "Ajouter le streaming au chat macOS")
            XCTAssertEqual(object["language"] as? String, "fr")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"items":["One","Two","Three","Four","Five"]}"#
            )
        }

        let client = makeClient()
        let language = try XCTUnwrap(LanguageCode("fr"))
        let subtasks = try await client.generateSubtasks(
            for: "Ajouter le streaming au chat macOS",
            in: language
        )
        let risks = try await client.generateRisks(
            for: "Ajouter le streaming au chat macOS",
            in: language
        )
        let questions = try await client.generateQuestions(
            for: "Ajouter le streaming au chat macOS",
            in: language
        )

        XCTAssertEqual(receivedPaths, expectedPaths)
        XCTAssertEqual(subtasks, ["One", "Two", "Three", "Four", "Five"])
        XCTAssertEqual(risks, subtasks)
        XCTAssertEqual(questions, subtasks)
    }

    func testTaskRequestOmitsLanguageWhenAbsent() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://appcore.example/api/ai/tasks/subtasks"
            )
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["task"] as? String, "Ship the feature")
            XCTAssertNil(object["language"])
            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"items":["One","Two","Three","Four","Five"]}"#
            )
        }

        _ = try await makeClient().generateSubtasks(for: "Ship the feature")
    }

    func testImproveTaskReturnsOriginalAndImprovedText() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://appcore.example/api/ai/tasks/improve"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["task"] as? String, "faire endpoint pour stream chat mac")
            XCTAssertEqual(object["language"] as? String, "fr")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"original":"faire endpoint pour stream chat mac","improved":"Ajouter un endpoint de streaming pour le chat macOS"}"#
            )
        }

        let result = try await makeClient().improveTask(
            "faire endpoint pour stream chat mac",
            in: LanguageCode("fr")!
        )

        XCTAssertEqual(result.original, "faire endpoint pour stream chat mac")
        XCTAssertEqual(result.improved, "Ajouter un endpoint de streaming pour le chat macOS")
    }

    func testAnalyzeTaskReturnsCombinedAnalysis() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://appcore.example/api/ai/tasks/analyze"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["task"] as? String, "Ajouter le streaming au chat macOS")
            XCTAssertEqual(object["language"] as? String, "fr")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"subtasks":["S1","S2","S3","S4","S5"],"risks":["R1","R2","R3","R4","R5"],"suggestedQuestions":["Q1","Q2","Q3","Q4","Q5"]}"#
            )
        }

        let analysis = try await makeClient().analyzeTask(
            "Ajouter le streaming au chat macOS",
            in: LanguageCode("fr")!
        )

        XCTAssertEqual(analysis.subtasks, ["S1", "S2", "S3", "S4", "S5"])
        XCTAssertEqual(analysis.risks, ["R1", "R2", "R3", "R4", "R5"])
        XCTAssertEqual(analysis.suggestedQuestions, ["Q1", "Q2", "Q3", "Q4", "Q5"])
    }

    func testStreamChatSendsHistoryAndYieldsSSEEventsInOrder() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/chat/stream")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["prompt"] as? String, "How should I test it?")
            let conversation = try XCTUnwrap(object["conversation"] as? [[String: String]])
            XCTAssertEqual(conversation, [
                ["role": "USER", "content": "Add streaming"],
                ["role": "ASSISTANT", "content": "Expose an SSE endpoint"],
            ])

            return Self.response(
                for: request,
                statusCode: 200,
                body: """
                event: delta
                data: {"text":"Hello"}

                event: delta
                data: {"text":" world"}

                event: completed
                data: {"answer":"Hello world","model":"gpt-5.6","usage":{"inputTokens":4,"outputTokens":2,"totalTokens":6}}

                """
            )
        }

        var events: [ChatStreamEvent] = []
        for try await event in makeClient().streamChat(
            "How should I test it?",
            conversation: [
                ChatMessage(role: .user, content: "Add streaming"),
                ChatMessage(role: .assistant, content: "Expose an SSE endpoint"),
            ]
        ) {
            events.append(event)
        }

        XCTAssertEqual(events, [
            .delta("Hello"),
            .delta(" world"),
            .completed(ChatResponse(
                answer: "Hello world",
                model: "gpt-5.6",
                usage: ChatUsage(inputTokens: 4, outputTokens: 2, totalTokens: 6)
            )),
        ])
    }

    func testDecodesAppCoreErrorResponse() async throws {
        URLProtocolStub.requestHandler = { request in
            Self.response(
                for: request,
                statusCode: 401,
                body: #"{"timestamp":"2026-08-02T12:00:00Z","status":401,"error":"UNAUTHORIZED","message":"Authentication failed","path":"/api/FOOD/barcodes/123","details":[]}"#
            )
        }

        do {
            _ = try await makeClient().barcode("123", domain: .food)
            XCTFail("Expected the request to fail")
        } catch let AppCoreClientError.server(statusCode, response) {
            XCTAssertEqual(statusCode, 401)
            XCTAssertEqual(response?.error, "UNAUTHORIZED")
            XCTAssertEqual(response?.message, "Authentication failed")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExtractRecipeFromTextUsesAuthenticatedRecipeEndpoint() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/recipes/extract")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(object["text"] as? String, "Toast bread.")

            return Self.response(
                for: request,
                statusCode: 200,
                body: Self.recipeJSON
            )
        }

        let recipe = try await makeClient().extractRecipe(fromText: "Toast bread.")

        XCTAssertEqual(recipe.name, "Toast")
    }

    func testTranslateRecipeUsesLanguageCodeAndRecipeWrapper() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/recipes/translate")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(object["targetLanguage"] as? String, "fr")
            XCTAssertNotNil(object["recipe"] as? [String: Any])

            return Self.response(
                for: request,
                statusCode: 200,
                body: "{\"recipe\":\(Self.recipeJSON)}"
            )
        }

        let translated = try await makeClient().translate(
            Recipe(
                name: "Toast",
                recipeIngredient: ["bread"],
                recipeInstructions: ["Toast bread."]
            ),
            to: LanguageCode("fr")!
        )

        XCTAssertEqual(translated.name, "Toast")
    }

    func testExtractRecipeProductsUsesAuthenticatedEndpointAndReturnsGroupedProducts() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://appcore.example/api/ai/recipes/products/extract"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(
                object["ingredients"] as? [String],
                ["2 onions, finely chopped", "1 tablespoon olive oil"]
            )

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"ingredients":[{"ingredient":"2 onions, finely chopped","products":["onions"]},{"ingredient":"1 tablespoon olive oil","products":["olive oil"]}]}"#
            )
        }

        let results = try await makeClient().extractRecipeProducts(
            from: ["2 onions, finely chopped", "1 tablespoon olive oil"]
        )

        XCTAssertEqual(
            results,
            [
                IngredientProducts(
                    ingredient: "2 onions, finely chopped",
                    products: ["onions"]
                ),
                IngredientProducts(
                    ingredient: "1 tablespoon olive oil",
                    products: ["olive oil"]
                )
            ]
        )
    }

    func testExtractRecipeFromImageBuildsMultipartImagePart() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/recipes/from-image")
            let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let bodyText = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(bodyText.contains("name=\"image\"; filename=\"recipe.jpg\""))
            XCTAssertTrue(bodyText.contains("Content-Type: image/jpeg"))

            return Self.response(
                for: request,
                statusCode: 200,
                body: Self.recipeJSON
            )
        }

        let recipe = try await makeClient().extractRecipe(
            fromImage: Data([0xFF, 0xD8, 0xFF]),
            fileName: "recipe.jpg",
            mediaType: .jpeg
        )

        XCTAssertEqual(recipe.name, "Toast")
    }

    func testTracksAuthenticatedAnalyticsEventAndAcceptsEmpty202Response() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/v1/analytics/events")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(object["eventType"] as? String, "recipe.imported")
            XCTAssertEqual(object["occurredAt"] as? String, "2026-07-27T12:15:30Z")
            XCTAssertEqual(object["language"] as? String, "fr")
            XCTAssertNil(object["appClientId"])
            XCTAssertNil(object["apiKeyId"])
            XCTAssertNil(object["receivedAt"])

            let properties = try XCTUnwrap(object["properties"] as? [String: Any])
            XCTAssertEqual(properties["durationMs"] as? Int, 842)

            return Self.response(for: request, statusCode: 202, body: "")
        }

        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-07-27T12:15:30Z")
        )
        let event = AnalyticsEvent(
            eventType: AnalyticsEventType("recipe.imported")!,
            occurredAt: date,
            anonymousUserId: "anonymous-id",
            sessionId: "session-id",
            platform: "IOS",
            appVersion: "1.0.0",
            language: LanguageCode("fr"),
            region: "CA",
            subscriptionStatus: "ACTIVE",
            purchased: true,
            properties: ["source": "URL", "durationMs": 842]
        )

        try await makeClient().trackAnalyticsEvent(event)
    }

    private func makeClient() -> AppCoreClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return AppCoreClient(
            baseURL: URL(string: "https://appcore.example")!,
            apiKey: "ac_test_secret",
            session: URLSession(configuration: configuration)
        )
    }

    private static func response(
        for request: URLRequest,
        statusCode: Int,
        body: String
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    private static let recipeJSON = #"{"url":null,"name":"Toast","image":null,"author":null,"datePublished":null,"description":null,"prepTime":null,"cookTime":null,"totalTime":null,"keywords":null,"recipeIngredient":["bread"],"recipeInstructions":["Toast bread."],"recipeYield":null}"#

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }

        return data
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
