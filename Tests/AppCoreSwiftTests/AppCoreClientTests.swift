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

    func testBricksetSetReadsRawJSONByCompleteNumberAndBarcode() async throws {
        var requestedURLs: [String] = []
        URLProtocolStub.requestHandler = { request in
            requestedURLs.append(try XCTUnwrap(request.url?.absoluteString))
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"status":"success","sets":[{"number":"75313","futureBricksetField":{"foo":"bar"}}]}"#
            )
        }

        let byNumber = try await makeClient().bricksetSet("75313-1")
        let byBarcode = try await makeClient().bricksetSet(barcode: "5702016913866")

        XCTAssertEqual(requestedURLs, [
            "https://appcore.example/api/lego/brickset/sets/75313-1",
            "https://appcore.example/api/lego/brickset/barcodes/5702016913866",
        ])
        let expected: BricksetJSON = [
            "status": "success",
            "sets": [[
                "number": "75313",
                "futureBricksetField": ["foo": "bar"],
            ]],
        ]
        XCTAssertEqual(byNumber, expected)
        XCTAssertEqual(byBarcode, expected)
    }

    func testCacheBricksetSetPutsCompleteRawJSON() async throws {
        let response: BricksetJSON = [
            "status": "success",
            "matches": 1,
            "sets": [[
                "setID": 31235,
                "number": "75313",
                "numberVariant": 1,
                "futureBricksetField": ["foo": "bar"],
            ]],
        ]
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/lego/brickset/sets")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try XCTUnwrap(Self.bodyData(from: request))
            XCTAssertEqual(try JSONDecoder().decode(BricksetJSON.self, from: body), response)
            return Self.response(for: request, statusCode: 204, body: "")
        }

        try await makeClient().cacheBricksetSet(response)
    }

    func testBricksetAdditionalImagesReadsAndWritesRawJSON() async throws {
        let response: BricksetJSON = [
            "status": "success",
            "matches": 1,
            "additionalImages": [[
                "thumbnailURL": "https://images.example/thumbnail.jpg",
                "imageURL": "https://images.example/image.jpg",
                "futureImageField": true,
            ]],
        ]
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://appcore.example/api/lego/brickset/sets/75313-1/images"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            if request.httpMethod == "GET" {
                return Self.response(
                    for: request,
                    statusCode: 200,
                    body: String(decoding: try JSONEncoder().encode(response), as: UTF8.self)
                )
            }
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try XCTUnwrap(Self.bodyData(from: request))
            XCTAssertEqual(try JSONDecoder().decode(BricksetJSON.self, from: body), response)
            return Self.response(for: request, statusCode: 204, body: "")
        }

        let cached = try await makeClient().bricksetAdditionalImages(for: "75313-1")
        try await makeClient().cacheBricksetAdditionalImages(response, for: "75313-1")

        XCTAssertEqual(cached, response)
        XCTAssertEqual(requestCount, 2)
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

    func testTranscribeAudioBuildsAuthenticatedMultipartFileRequest() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/audio/transcriptions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let bodyText = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(bodyText.contains("name=\"file\"; filename=\"voice.webm\""))
            XCTAssertTrue(bodyText.contains("Content-Type: audio/webm"))
            XCTAssertFalse(bodyText.contains("name=\"image\""))

            return Self.response(for: request, statusCode: 200, body: #"{"text":"Appeler Marc demain."}"#)
        }

        let text = try await makeClient().transcribeAudio(
            Data([0x1A, 0x45, 0xDF, 0xA3]),
            fileName: "voice.webm",
            mediaType: .webM
        )

        XCTAssertEqual(text, "Appeler Marc demain.")
    }

    func testOrganizeVoiceInboxSendsTextAndDecodesResponse() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/voice-inbox/organize")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["text"] as? String, "Demain appeler Marc et finir AWS.")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"title":"Tâches pour demain","summary":"Deux tâches.","tasks":["Appeler Marc","Terminer AWS"]}"#
            )
        }

        let inbox = try await makeClient().organizeVoiceInbox("Demain appeler Marc et finir AWS.")

        XCTAssertEqual(inbox.title, "Tâches pour demain")
        XCTAssertEqual(inbox.summary, "Deux tâches.")
        XCTAssertEqual(inbox.tasks, ["Appeler Marc", "Terminer AWS"])
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

    func testCorrectTextUsesExpectedBodyAndReturnsText() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/texts/correct")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["text"] as? String, "Je sui disponible.")
            XCTAssertEqual(object["context"] as? String, "Professional email")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"text":"Je suis disponible."}"#
            )
        }

        let correctedText = try await makeClient().correct(
            "Je sui disponible.",
            context: "Professional email"
        )

        XCTAssertEqual(correctedText, "Je suis disponible.")
    }

    func testCorrectTextOmitsContextWhenAbsent() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertNil(object["context"])

            return Self.response(for: request, statusCode: 200, body: #"{"text":"Corrected"}"#)
        }

        let correctedText = try await makeClient().correct("Corected")

        XCTAssertEqual(correctedText, "Corrected")
    }

    func testComposeTextUsesExpectedTypedBodyAndReturnsText() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/texts/compose")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["type"] as? String, "EMAIL")
            XCTAssertEqual(object["brief"] as? String, "Ask Marie for a meeting Tuesday")
            XCTAssertEqual(object["targetLanguage"] as? String, "fr")
            XCTAssertEqual(object["context"] as? String, "Friendly professional relationship")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"text":"Bonjour Marie, serais-tu disponible mardi?"}"#
            )
        }

        let composedText = try await makeClient().compose(
            "Ask Marie for a meeting Tuesday",
            as: .email,
            in: LanguageCode("FR")!,
            context: "Friendly professional relationship"
        )

        XCTAssertEqual(composedText, "Bonjour Marie, serais-tu disponible mardi?")
    }

    func testComposeTextPropagatesStructuredServerError() async throws {
        URLProtocolStub.requestHandler = { request in
            Self.response(
                for: request,
                statusCode: 400,
                body: #"{"timestamp":"2026-08-09T00:00:00Z","status":400,"error":"VALIDATION_ERROR","message":"The request contains invalid data","path":"/api/ai/texts/compose","details":["Brief is required"]}"#
            )
        }

        do {
            _ = try await makeClient().compose(
                "",
                as: .message,
                in: LanguageCode("en")!
            )
            XCTFail("Expected a server error")
        } catch let AppCoreClientError.server(statusCode, response) {
            XCTAssertEqual(statusCode, 400)
            XCTAssertEqual(response?.error, "VALIDATION_ERROR")
            XCTAssertEqual(response?.details, ["Brief is required"])
        }
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

    func testSuggestTagsSendsExistingTagsAndReturnsTypedItems() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://appcore.example/api/ai/tasks/tags"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["task"] as? String, "Ship the release")
            XCTAssertEqual(object["existingTags"] as? [String], ["#Work", "#Personal"])
            XCTAssertEqual(object["language"] as? String, "en")

            return Self.response(
                for: request,
                statusCode: 200,
                body: "{\"items\":[\"#Work\",\"#Release\",\"#Testing\",\"#Documentation\",\"#Planning\"]}"
            )
        }

        let tags = try await makeClient().suggestTags(
            for: "Ship the release",
            existingTags: ["#Work", "#Personal"],
            in: LanguageCode("en")!
        )

        XCTAssertEqual(tags, ["#Work", "#Release", "#Testing", "#Documentation", "#Planning"])
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

    func testDiscoverRecipesUsesAuthenticatedJSONEndpoint() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString,
                           "https://appcore.example/api/ai/recipes/discover-from-inventory")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["locale"] as? String, "fr-CA")
            XCTAssertEqual(object["priorityProductIds"] as? [String], ["product-1"])
            XCTAssertEqual((object["inventory"] as? [[String: Any]])?.first?["name"] as? String, "Poulet")
            return Self.response(for: request, statusCode: 200, body: Self.recipeDiscoveryJSON)
        }

        let result = try await makeClient().discoverRecipes(Self.recipeDiscoveryRequest)

        XCTAssertEqual(result.recipes.first?.title, "Pâtes au poulet")
        XCTAssertEqual(result.recipes.first?.sourceURL.host, "recipes.example")
        XCTAssertEqual(result.recipes.first?.imageURL.host, "images.example")
    }

    func testStreamRecipeDiscoveryYieldsTypedSSEEvents() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString,
                           "https://appcore.example/api/ai/recipes/discover-from-inventory/stream")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
            return Self.response(for: request, statusCode: 200, body: """
                event: progress\r
                data: {"state":"SELECTING_PRODUCTS"}\r
                \r
                event: progress
                data: {"state":"SEARCHING_WEB"}

                event: progress
                data: {"state":"GENERATING_RESULTS"}

                event: progress
                data: {"state":"RESOLVING_IMAGES"}

                event: result
                data: \(Self.recipeDiscoveryJSON)

                """)
        }

        var events: [RecipeDiscoveryStreamEvent] = []
        for try await event in makeClient().streamRecipeDiscovery(Self.recipeDiscoveryRequest) {
            events.append(event)
        }

        XCTAssertEqual(events[0], .progress(.selectingProducts))
        XCTAssertEqual(events[1], .progress(.searchingWeb))
        XCTAssertEqual(events[2], .progress(.generatingResults))
        XCTAssertEqual(events[3], .progress(.resolvingImages))
        guard case let .result(result) = events[4] else {
            return XCTFail("Expected a recipe discovery result")
        }
        XCTAssertEqual(result.recipes.first?.matchedProducts, ["Poulet", "Pâtes"])
    }

    func testStreamRecipeDiscoveryAcceptsCurrentProgressStates() async throws {
        URLProtocolStub.requestHandler = { request in
            Self.response(for: request, statusCode: 200, body: """
                event: progress
                data: {"state":"ANALYZING_INVENTORY"}

                event: progress
                data: {"state":"SEARCHING_WEB"}

                event: progress
                data: {"state":"RANKING_RECIPES"}

                event: result
                data: \(Self.recipeDiscoveryJSON)

                """)
        }

        var events: [RecipeDiscoveryStreamEvent] = []
        for try await event in makeClient().streamRecipeDiscovery(Self.recipeDiscoveryRequest) {
            events.append(event)
        }

        XCTAssertEqual(events[0], .progress(.analyzingInventory))
        XCTAssertEqual(events[1], .progress(.searchingWeb))
        XCTAssertEqual(events[2], .progress(.rankingRecipes))
        guard case .result = events[3] else {
            return XCTFail("Expected a recipe discovery result")
        }
    }

    func testStreamRecipeDiscoveryYieldsTypedFailure() async throws {
        URLProtocolStub.requestHandler = { request in
            Self.response(for: request, statusCode: 200, body: """
                event: error
                data: {"code":"RECIPE_DISCOVERY_FAILED","message":"Unable to discover recipes."}

                """)
        }

        var events: [RecipeDiscoveryStreamEvent] = []
        for try await event in makeClient().streamRecipeDiscovery(Self.recipeDiscoveryRequest) {
            events.append(event)
        }

        XCTAssertEqual(events, [.failure(RecipeDiscoveryFailure(
            code: "RECIPE_DISCOVERY_FAILED",
            message: "Unable to discover recipes."
        ))])
    }

    func testRecreateDishBuildsMultipartRequestAndYieldsTypedSSEEvents() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://appcore.example/api/ai/recipes/recreate-dish/stream")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
            XCTAssertTrue(try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
                .hasPrefix("multipart/form-data; boundary="))

            let body = String(decoding: try XCTUnwrap(Self.bodyData(from: request)), as: UTF8.self)
            XCTAssertTrue(body.contains("name=\"dishName\"\r\n\r\nPoulet à l’origan"))
            XCTAssertTrue(body.contains("name=\"restaurantName\"\r\n\r\nAu Vieux Duluth"))
            XCTAssertTrue(body.contains("name=\"restaurantLocation\"\r\n\r\nMontréal"))
            XCTAssertTrue(body.contains("name=\"description\"\r\n\r\nServi avec riz et salade"))
            XCTAssertTrue(body.contains("name=\"servings\"\r\n\r\n4"))
            XCTAssertTrue(body.contains("name=\"language\"\r\n\r\nfr"))
            XCTAssertTrue(body.contains("name=\"dishImage\"; filename=\"dish.jpg\""))
            XCTAssertTrue(body.contains("name=\"menuImage\"; filename=\"menu.png\""))
            XCTAssertTrue(body.contains("Content-Type: image/jpeg"))
            XCTAssertTrue(body.contains("Content-Type: image/png"))

            return Self.response(
                for: request,
                statusCode: 200,
                body: """
                event: progress
                data: {"state":"ANALYZING_IMAGE"}

                event: progress
                data: {"state":"SEARCHING_WEB"}

                event: result
                data: {"name":"Repas complet","recipes":[{"type":"MAIN","recipe":\(Self.recipeJSON)}]}

                """
            )
        }

        let input = DishRecreationRequest(
            dishName: "Poulet à l’origan",
            restaurantName: "Au Vieux Duluth",
            restaurantLocation: "Montréal",
            description: "Servi avec riz et salade",
            servings: 4,
            language: LanguageCode("fr"),
            dishImage: DishRecreationImage(
                data: Data([0xFF, 0xD8, 0xFF]), fileName: "dish.jpg", mediaType: .jpeg
            ),
            menuImage: DishRecreationImage(
                data: Data([0x89, 0x50, 0x4E, 0x47]), fileName: "menu.png", mediaType: .png
            )
        )

        var events: [DishRecreationStreamEvent] = []
        for try await event in makeClient().recreateDish(input) {
            events.append(event)
        }

        XCTAssertEqual(events[0], .progress(.analyzingImage))
        XCTAssertEqual(events[1], .progress(.searchingWeb))
        guard case let .result(result) = events[2] else {
            return XCTFail("Expected a dish recreation result")
        }
        XCTAssertEqual(result.name, "Repas complet")
        XCTAssertEqual(result.recipes.first?.type, .main)
        XCTAssertEqual(result.recipes.first?.recipe.name, "Toast")
    }

    func testRecreateDishYieldsTypedSSEFailure() async throws {
        URLProtocolStub.requestHandler = { request in
            Self.response(
                for: request,
                statusCode: 200,
                body: """
                event: error
                data: {"code":"DISH_RECREATION_FAILED","message":"Unable to recreate the dish."}

                """
            )
        }

        var events: [DishRecreationStreamEvent] = []
        for try await event in makeClient().recreateDish(
            DishRecreationRequest(dishName: "Poke", description: "Salmon")
        ) {
            events.append(event)
        }

        XCTAssertEqual(events, [
            .failure(DishRecreationFailure(
                code: "DISH_RECREATION_FAILED",
                message: "Unable to recreate the dish."
            ))
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

    func testRecipeExtractionDomainsUsesAuthenticatedGetAndReturnsDomains() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://appcore.example/api/ai/recipes/extraction-domains"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "ac_test_secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            return Self.response(
                for: request,
                statusCode: 200,
                body: #"{"domains":["5ingredients15minutes.com","recettes.qc.ca","zeste.ca"]}"#
            )
        }

        let domains = try await makeClient().recipeExtractionDomains()

        XCTAssertEqual(
            domains,
            ["5ingredients15minutes.com", "recettes.qc.ca", "zeste.ca"]
        )
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

    private static let recipeDiscoveryJSON = #"{"recipes":[{"id":"recipe-1","title":"Pâtes au poulet","sourceName":"Cuisine","sourceUrl":"https://recipes.example/pasta","imageUrl":"https://images.example/pasta.jpg","language":"fr","matchedProducts":["Poulet","Pâtes"]}]}"#

    private static let recipeDiscoveryRequest = RecipeDiscoveryRequest(
        locale: "fr-CA",
        priorityProductIds: ["product-1"],
        comment: "Rapide",
        inventory: [
            InventoryRecipeProduct(id: "product-1", name: "Poulet", quantity: 2, unit: "unité"),
            InventoryRecipeProduct(id: "product-2", name: "Pâtes", quantity: 500, unit: "g"),
        ]
    )

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
