import Foundation

/// Client for AppCore's authenticated public API.
public final class AppCoreClient: Sendable {
    public static let apiKeyHeader = "X-API-Key"

    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession

    /// Creates a client without persisting or logging the supplied API key.
    ///
    /// - Parameters:
    ///   - baseURL: AppCore server URL, for example `https://api.example.com`.
    ///   - apiKey: AppCore client key sent in the `X-API-Key` header.
    ///   - session: Injectable URL session, primarily useful for tests.
    public init(
        baseURL: URL,
        apiKey: String,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    /// Calls `GET /api/{domain}/barcodes/{barcode}`.
    public func barcode(
        _ barcode: String,
        domain: BarcodeDomain
    ) async throws -> BarcodeProduct {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent(domain.pathComponent)
            .appendingPathComponent("barcodes")
            .appendingPathComponent(barcode)

        return try await send(URLRequest(url: url))
    }

    /// Calls `POST /api/ai/products/translate`.
    public func translate(
        _ product: BarcodeProduct,
        to targetLanguage: LanguageCode
    ) async throws -> BarcodeProduct {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("ai")
            .appendingPathComponent("products")
            .appendingPathComponent("translate")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(
                TranslateBarcodeProductRequest(
                    targetLanguage: targetLanguage,
                    product: product
                )
            )
        } catch {
            throw AppCoreClientError.encoding(String(describing: error))
        }

        let response: TranslateBarcodeProductResponse = try await send(request)
        return response.product
    }

    /// Calls `POST /api/ai/brick-sets/describe`.
    public func describeBrickSet(
        code: String,
        name: String,
        in language: LanguageCode
    ) async throws -> String {
        let response: DescribeBrickSetResponse = try await postJSON(
            path: ["api", "ai", "brick-sets", "describe"],
            body: DescribeBrickSetRequest(
                setCode: code,
                setName: name,
                language: language
            )
        )
        return response.description
    }

    /// Calls `GET /api/lego/brickset/sets/{setNumber}`.
    ///
    /// Pass either a complete Brickset number such as `75313-1` or a set number
    /// such as `75313`, for which AppCore uses variant 1.
    public func bricksetSet(_ setNumber: String) async throws -> BricksetJSON {
        try await send(
            URLRequest(url: url(path: ["api", "lego", "brickset", "sets", setNumber]))
        )
    }

    /// Calls `PUT /api/lego/brickset/sets` with the complete `getSets` response.
    public func cacheBricksetSet(_ response: BricksetJSON) async throws {
        try await putJSON(
            path: ["api", "lego", "brickset", "sets"],
            body: response
        )
    }

    /// Calls `GET /api/lego/brickset/barcodes/{barcode}`.
    public func bricksetSet(barcode: String) async throws -> BricksetJSON {
        try await send(
            URLRequest(url: url(path: ["api", "lego", "brickset", "barcodes", barcode]))
        )
    }

    /// Calls `GET /api/lego/brickset/sets/{setNumber}/images`.
    public func bricksetAdditionalImages(for setNumber: String) async throws -> BricksetJSON {
        try await send(
            URLRequest(
                url: url(path: ["api", "lego", "brickset", "sets", setNumber, "images"])
            )
        )
    }

    /// Calls `PUT /api/lego/brickset/sets/{setNumber}/images` with the complete
    /// `getAdditionalImages` response.
    public func cacheBricksetAdditionalImages(
        _ response: BricksetJSON,
        for setNumber: String
    ) async throws {
        try await putJSON(
            path: ["api", "lego", "brickset", "sets", setNumber, "images"],
            body: response
        )
    }

    /// Calls `GET /api/lego/brickset/sets/{setNumber}/instructions`.
    public func bricksetInstructions(for setNumber: String) async throws -> BricksetJSON {
        try await send(
            URLRequest(
                url: url(path: ["api", "lego", "brickset", "sets", setNumber, "instructions"])
            )
        )
    }

    /// Calls `PUT /api/lego/brickset/sets/{setNumber}/instructions` with the
    /// complete `getInstructions2` response.
    public func cacheBricksetInstructions(
        _ response: BricksetJSON,
        for setNumber: String
    ) async throws {
        try await putJSON(
            path: ["api", "lego", "brickset", "sets", setNumber, "instructions"],
            body: response
        )
    }

    /// Calls `POST /api/ai/wines/describe`.
    public func describeWine(
        named name: String,
        in language: LanguageCode
    ) async throws -> WineProduct {
        try await postJSON(
            path: ["api", "ai", "wines", "describe"],
            body: DescribeWineRequest(name: name, language: language)
        )
    }

    /// Calls `POST /api/ai/wines/from-image` with multipart form data.
    public func describeWine(
        fromImage data: Data,
        fileName: String,
        mediaType: WineImageMediaType,
        in language: LanguageCode
    ) async throws -> WineProduct {
        let boundary = "AppCoreBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: url(path: ["api", "ai", "wines", "from-image"]))
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = multipartBody(
            data: data,
            fileName: fileName,
            mediaType: mediaType.rawValue,
            fields: ["language": language.rawValue],
            boundary: boundary
        )
        return try await send(request)
    }

    /// Calls `POST /api/ai/products/from-image` with multipart form data.
    public func describeProduct(
        fromImage data: Data,
        fileName: String,
        mediaType: ProductImageMediaType,
        in language: LanguageCode
    ) async throws -> ProductPicture {
        let boundary = "AppCoreBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: url(path: ["api", "ai", "products", "from-image"]))
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = multipartBody(
            data: data,
            fileName: fileName,
            mediaType: mediaType.rawValue,
            fields: ["language": language.rawValue],
            boundary: boundary
        )
        return try await send(request)
    }

    /// Calls `POST /api/ai/audio/transcriptions` with multipart form data.
    public func transcribeAudio(
        _ data: Data,
        fileName: String,
        mediaType: AudioMediaType
    ) async throws -> String {
        let boundary = "AppCoreBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: url(path: ["api", "ai", "audio", "transcriptions"]))
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = multipartBody(
            data: data,
            fieldName: "file",
            fileName: fileName,
            mediaType: mediaType.rawValue,
            fields: [:],
            boundary: boundary
        )
        let response: AudioTranscriptionResponse = try await send(request)
        return response.text
    }

    /// Calls `POST /api/ai/voice-inbox/organize`.
    public func organizeVoiceInbox(_ text: String) async throws -> VoiceInbox {
        try await postJSON(
            path: ["api", "ai", "voice-inbox", "organize"],
            body: OrganizeVoiceInboxRequest(text: text)
        )
    }

    /// Calls `POST /api/ai/texts/translate`.
    public func translate(
        _ text: String,
        to targetLanguage: LanguageCode,
        context: String? = nil
    ) async throws -> String {
        let response: TranslateTextResponse = try await postJSON(
            path: ["api", "ai", "texts", "translate"],
            body: TranslateTextRequest(
                text: text,
                targetLanguage: targetLanguage,
                context: context
            )
        )
        return response.text
    }

    /// Calls `POST /api/ai/texts/correct`.
    public func correct(
        _ text: String,
        context: String? = nil
    ) async throws -> String {
        let response: GeneratedTextResponse = try await postJSON(
            path: ["api", "ai", "texts", "correct"],
            body: CorrectTextRequest(text: text, context: context)
        )
        return response.text
    }

    /// Calls `POST /api/ai/texts/compose`.
    public func compose(
        _ brief: String,
        as type: TextCompositionType,
        in targetLanguage: LanguageCode,
        context: String? = nil
    ) async throws -> String {
        let response: GeneratedTextResponse = try await postJSON(
            path: ["api", "ai", "texts", "compose"],
            body: ComposeTextRequest(
                type: type,
                brief: brief,
                targetLanguage: targetLanguage,
                context: context
            )
        )
        return response.text
    }

    /// Calls `POST /api/ai/tasks/subtasks`.
    public func generateSubtasks(
        for task: String,
        in language: LanguageCode? = nil
    ) async throws -> [String] {
        try await taskItems(operation: "subtasks", task: task, language: language)
    }

    /// Calls `POST /api/ai/tasks/risks`.
    public func generateRisks(
        for task: String,
        in language: LanguageCode? = nil
    ) async throws -> [String] {
        try await taskItems(operation: "risks", task: task, language: language)
    }

    /// Calls `POST /api/ai/tasks/questions`.
    public func generateQuestions(
        for task: String,
        in language: LanguageCode? = nil
    ) async throws -> [String] {
        try await taskItems(operation: "questions", task: task, language: language)
    }

    /// Calls `POST /api/ai/tasks/tags`.
    public func suggestTags(
        for task: String,
        existingTags: [String],
        in language: LanguageCode? = nil
    ) async throws -> [String] {
        let response: TaskItemsResponse = try await postJSON(
            path: ["api", "ai", "tasks", "tags"],
            body: TaskTagSuggestionsRequest(
                task: task,
                existingTags: existingTags,
                language: language
            )
        )
        return response.items
    }

    /// Calls `POST /api/ai/tasks/improve`.
    public func improveTask(
        _ task: String,
        in language: LanguageCode? = nil
    ) async throws -> ImprovedTask {
        try await postJSON(
            path: ["api", "ai", "tasks", "improve"],
            body: TaskAIRequest(task: task, language: language)
        )
    }

    /// Calls `POST /api/ai/tasks/analyze`.
    public func analyzeTask(
        _ task: String,
        in language: LanguageCode? = nil
    ) async throws -> TaskAnalysis {
        try await postJSON(
            path: ["api", "ai", "tasks", "analyze"],
            body: TaskAIRequest(task: task, language: language)
        )
    }

    /// Streams `POST /api/ai/chat/stream` as server-sent events.
    public func streamChat(
        _ prompt: String,
        conversation: [ChatMessage] = []
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await consumeChatStream(
                        prompt: prompt,
                        conversation: conversation,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Calls `POST /api/ai/recipes/translate`.
    public func translate(
        _ recipe: Recipe,
        to targetLanguage: LanguageCode
    ) async throws -> Recipe {
        let response: TranslateRecipeResponse = try await postJSON(
            path: ["api", "ai", "recipes", "translate"],
            body: TranslateRecipeRequest(
                targetLanguage: targetLanguage,
                recipe: recipe
            )
        )
        return response.recipe
    }

    /// Calls `POST /api/ai/recipes/extract`.
    public func extractRecipe(fromText text: String) async throws -> Recipe {
        try await postJSON(
            path: ["api", "ai", "recipes", "extract"],
            body: ExtractRecipeFromTextRequest(text: text)
        )
    }

    /// Calls `GET /api/ai/recipes/extraction-domains`.
    ///
    /// The returned normalized domains identify recipe pages whose HTML should
    /// be downloaded by the client and submitted through `extractRecipe(fromWebContent:sourceURL:contentType:)`.
    public func recipeExtractionDomains() async throws -> [String] {
        let response: RecipeExtractionDomainsResponse = try await send(
            URLRequest(url: url(path: ["api", "ai", "recipes", "extraction-domains"]))
        )
        return response.domains
    }

    /// Calls `POST /api/ai/recipes/extract-from-url`.
    public func extractRecipe(fromURL url: URL) async throws -> Recipe {
        try await postJSON(
            path: ["api", "ai", "recipes", "extract-from-url"],
            body: ExtractRecipeFromURLRequest(url: url.absoluteString)
        )
    }

    /// Calls `POST /api/ai/recipes/from-web-content`.
    public func extractRecipe(
        fromWebContent content: String,
        sourceURL: URL,
        contentType: WebRecipeContentType
    ) async throws -> Recipe {
        try await postJSON(
            path: ["api", "ai", "recipes", "from-web-content"],
            body: WebRecipeContentRequest(
                url: sourceURL.absoluteString,
                contentType: contentType,
                content: content
            )
        )
    }

    /// Calls `POST /api/ai/recipes/products/extract`.
    public func extractRecipeProducts(
        from ingredients: [String]
    ) async throws -> [IngredientProducts] {
        let response: ExtractRecipeProductsResponse = try await postJSON(
            path: ["api", "ai", "recipes", "products", "extract"],
            body: ExtractRecipeProductsRequest(ingredients: ingredients)
        )
        return response.ingredients
    }

    /// Calls `POST /api/ai/recipes/classify-meal-types`.
    /// Every returned value is an exact member of `availableMealTypes`.
    public func classifyMealTypes(
        for recipe: Recipe,
        availableMealTypes: [String],
        locale: String
    ) async throws -> [String] {
        let response: MealTypeClassificationResponse = try await postJSON(
            path: ["api", "ai", "recipes", "classify-meal-types"],
            body: ClassifyRecipeMealTypesRequest(recipe: recipe, locale: locale, mealTypes: availableMealTypes)
        )
        return response.mealTypes
    }

    /// Calls `POST /api/ai/recipes/classify-tags`.
    /// `suggestedTags` contains at most three optional new tags proposed by AppCore.
    public func classifyTags(
        for recipe: Recipe,
        existingTags: [String],
        locale: String
    ) async throws -> RecipeTagClassificationResponse {
        try await postJSON(
            path: ["api", "ai", "recipes", "classify-tags"],
            body: ClassifyRecipeTagsRequest(recipe: recipe, locale: locale, tags: existingTags)
        )
    }

    /// Calls `POST /api/ai/recipes/discover-from-inventory`.
    public func discoverRecipes(
        _ request: RecipeDiscoveryRequest
    ) async throws -> RecipeDiscoveryResult {
        try await postJSON(
            path: ["api", "ai", "recipes", "discover-from-inventory"],
            body: request
        )
    }

    /// Streams `POST /api/ai/recipes/discover-from-inventory/stream` as server-sent events.
    public func streamRecipeDiscovery(
        _ request: RecipeDiscoveryRequest
    ) -> AsyncThrowingStream<RecipeDiscoveryStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await consumeRecipeDiscoveryStream(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Calls `POST /api/ai/recipes/from-image` with multipart form data.
    public func extractRecipe(
        fromImage data: Data,
        fileName: String,
        mediaType: RecipeImageMediaType
    ) async throws -> Recipe {
        let boundary = "AppCoreBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: url(path: ["api", "ai", "recipes", "from-image"]))
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = multipartBody(
            data: data,
            fileName: fileName,
            mediaType: mediaType.rawValue,
            fields: [:],
            boundary: boundary
        )
        return try await send(request)
    }

    /// Streams `POST /api/ai/recipes/recreate-dish/stream` as server-sent events.
    public func recreateDish(
        _ input: DishRecreationRequest
    ) -> AsyncThrowingStream<DishRecreationStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await consumeDishRecreationStream(input, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Calls `POST /api/v1/analytics/events` and expects `202 Accepted`.
    public func trackAnalyticsEvent(_ event: AnalyticsEvent) async throws {
        var request = URLRequest(url: url(path: ["api", "v1", "analytics", "events"]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(event)
        } catch {
            throw AppCoreClientError.encoding(String(describing: error))
        }

        _ = try await perform(request)
    }

    private func postJSON<Body: Encodable, Response: Decodable>(
        path: [String],
        body: Body
    ) async throws -> Response {
        var request = URLRequest(url: url(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AppCoreClientError.encoding(String(describing: error))
        }

        return try await send(request)
    }

    private func putJSON<Body: Encodable>(
        path: [String],
        body: Body
    ) async throws {
        var request = URLRequest(url: url(path: path))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AppCoreClientError.encoding(String(describing: error))
        }

        _ = try await perform(request)
    }

    private func taskItems(
        operation: String,
        task: String,
        language: LanguageCode?
    ) async throws -> [String] {
        let response: TaskItemsResponse = try await postJSON(
            path: ["api", "ai", "tasks", operation],
            body: TaskAIRequest(task: task, language: language)
        )
        return response.items
    }

    private func consumeChatStream(
        prompt: String,
        conversation: [ChatMessage],
        continuation: AsyncThrowingStream<ChatStreamEvent, Error>.Continuation
    ) async throws {
        var request = URLRequest(url: url(path: ["api", "ai", "chat", "stream"]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: Self.apiKeyHeader)
        do {
            request.httpBody = try JSONEncoder().encode(
                ChatRequest(prompt: prompt, conversation: conversation)
            )
        } catch {
            throw AppCoreClientError.encoding(String(describing: error))
        }

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let error as URLError {
            throw AppCoreClientError.transport(error.code)
        } catch {
            throw AppCoreClientError.transport(.unknown)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppCoreClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            throw AppCoreClientError.server(
                statusCode: httpResponse.statusCode,
                response: try? JSONDecoder().decode(AppCoreAPIErrorResponse.self, from: body)
            )
        }

        var frameBytes: [UInt8] = []
        var completed = false
        for try await byte in bytes {
            frameBytes.append(byte)
            let delimiterLength: Int?
            if frameBytes.suffix(4).elementsEqual([13, 10, 13, 10]) {
                delimiterLength = 4
            } else if frameBytes.suffix(2).elementsEqual([10, 10]) {
                delimiterLength = 2
            } else {
                delimiterLength = nil
            }
            if let delimiterLength {
                let frame = String(decoding: frameBytes.dropLast(delimiterLength), as: UTF8.self)
                if let event = try decodeChatStreamFrame(frame) {
                    continuation.yield(event)
                    if case .completed = event { completed = true }
                }
                frameBytes.removeAll(keepingCapacity: true)
            }
        }
        if !frameBytes.isEmpty,
           let event = try decodeChatStreamFrame(String(decoding: frameBytes, as: UTF8.self)) {
            continuation.yield(event)
            if case .completed = event { completed = true }
        }
        if !completed {
            throw AppCoreClientError.decoding("Chat stream ended before the completed event")
        }
    }

    private func consumeDishRecreationStream(
        _ input: DishRecreationRequest,
        continuation: AsyncThrowingStream<DishRecreationStreamEvent, Error>.Continuation
    ) async throws {
        let boundary = "AppCoreBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: url(path: ["api", "ai", "recipes", "recreate-dish", "stream"]))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: Self.apiKeyHeader)

        var fields = ["dishName": input.dishName]
        if let value = input.restaurantName { fields["restaurantName"] = value }
        if let value = input.restaurantLocation { fields["restaurantLocation"] = value }
        if let value = input.description { fields["description"] = value }
        if let value = input.servings { fields["servings"] = String(value) }
        if let value = input.language { fields["language"] = value.rawValue }
        var files: [MultipartFilePart] = []
        if let image = input.dishImage {
            files.append(MultipartFilePart(
                fieldName: "dishImage", data: image.data, fileName: image.fileName,
                mediaType: image.mediaType.rawValue
            ))
        }
        if let image = input.menuImage {
            files.append(MultipartFilePart(
                fieldName: "menuImage", data: image.data, fileName: image.fileName,
                mediaType: image.mediaType.rawValue
            ))
        }
        request.httpBody = multipartBody(fields: fields, files: files, boundary: boundary)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let error as URLError {
            throw AppCoreClientError.transport(error.code)
        } catch {
            throw AppCoreClientError.transport(.unknown)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppCoreClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            throw AppCoreClientError.server(
                statusCode: httpResponse.statusCode,
                response: try? JSONDecoder().decode(AppCoreAPIErrorResponse.self, from: body)
            )
        }

        var frameBytes: [UInt8] = []
        var terminalEventReceived = false
        for try await byte in bytes {
            frameBytes.append(byte)
            let delimiterLength: Int?
            if frameBytes.suffix(4).elementsEqual([13, 10, 13, 10]) {
                delimiterLength = 4
            } else if frameBytes.suffix(2).elementsEqual([10, 10]) {
                delimiterLength = 2
            } else {
                delimiterLength = nil
            }
            if let delimiterLength {
                let frame = String(decoding: frameBytes.dropLast(delimiterLength), as: UTF8.self)
                if let event = try decodeDishRecreationStreamFrame(frame) {
                    continuation.yield(event)
                    if case .result = event { terminalEventReceived = true }
                    if case .failure = event { terminalEventReceived = true }
                }
                frameBytes.removeAll(keepingCapacity: true)
            }
        }
        if !frameBytes.isEmpty,
           let event = try decodeDishRecreationStreamFrame(String(decoding: frameBytes, as: UTF8.self)) {
            continuation.yield(event)
            if case .result = event { terminalEventReceived = true }
            if case .failure = event { terminalEventReceived = true }
        }
        if !terminalEventReceived {
            throw AppCoreClientError.decoding("Dish recreation stream ended before a result or error event")
        }
    }

    private func consumeRecipeDiscoveryStream(
        _ input: RecipeDiscoveryRequest,
        continuation: AsyncThrowingStream<RecipeDiscoveryStreamEvent, Error>.Continuation
    ) async throws {
        var request = URLRequest(url: url(path: [
            "api", "ai", "recipes", "discover-from-inventory", "stream"
        ]))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: Self.apiKeyHeader)
        do {
            request.httpBody = try JSONEncoder().encode(input)
        } catch {
            throw AppCoreClientError.encoding(String(describing: error))
        }

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let error as URLError {
            throw AppCoreClientError.transport(error.code)
        } catch {
            throw AppCoreClientError.transport(.unknown)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppCoreClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            throw AppCoreClientError.server(
                statusCode: httpResponse.statusCode,
                response: try? JSONDecoder().decode(AppCoreAPIErrorResponse.self, from: body)
            )
        }

        var frameBytes: [UInt8] = []
        var terminalEventReceived = false
        for try await byte in bytes {
            frameBytes.append(byte)
            let delimiterLength: Int?
            if frameBytes.suffix(4).elementsEqual([13, 10, 13, 10]) {
                delimiterLength = 4
            } else if frameBytes.suffix(2).elementsEqual([10, 10]) {
                delimiterLength = 2
            } else {
                delimiterLength = nil
            }
            if let delimiterLength {
                let frame = String(decoding: frameBytes.dropLast(delimiterLength), as: UTF8.self)
                if let event = try decodeRecipeDiscoveryStreamFrame(frame) {
                    continuation.yield(event)
                    if case .result = event { terminalEventReceived = true }
                    if case .failure = event { terminalEventReceived = true }
                }
                frameBytes.removeAll(keepingCapacity: true)
            }
        }
        if !frameBytes.isEmpty,
           let event = try decodeRecipeDiscoveryStreamFrame(String(decoding: frameBytes, as: UTF8.self)) {
            continuation.yield(event)
            if case .result = event { terminalEventReceived = true }
            if case .failure = event { terminalEventReceived = true }
        }
        if !terminalEventReceived {
            throw AppCoreClientError.decoding(
                "Recipe discovery stream ended before a result or error event"
            )
        }
    }

    private func decodeRecipeDiscoveryStreamFrame(
        _ frame: String
    ) throws -> RecipeDiscoveryStreamEvent? {
        let lines = frame.split(whereSeparator: { $0.isNewline })
        let name = lines.first(where: { $0.hasPrefix("event:") })
            .map { String($0.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
        let dataLines = lines.filter { $0.hasPrefix("data:") }
            .map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        guard let name, !dataLines.isEmpty else { return nil }
        let data = Data(dataLines.joined(separator: "\n").utf8)
        do {
            switch name {
            case "progress":
                return .progress(try JSONDecoder().decode(
                    RecipeDiscoveryProgress.self, from: data
                ).state)
            case "result":
                return .result(try JSONDecoder().decode(RecipeDiscoveryResult.self, from: data))
            case "error":
                return .failure(try JSONDecoder().decode(RecipeDiscoveryFailure.self, from: data))
            default:
                return nil
            }
        } catch {
            throw AppCoreClientError.decoding(String(describing: error))
        }
    }

    private func decodeDishRecreationStreamFrame(_ frame: String) throws -> DishRecreationStreamEvent? {
        let lines = frame.split(whereSeparator: { $0.isNewline })
        let name = lines.first(where: { $0.hasPrefix("event:") })
            .map { String($0.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
        let dataLines = lines.filter { $0.hasPrefix("data:") }
            .map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        guard let name, !dataLines.isEmpty else { return nil }
        let data = Data(dataLines.joined(separator: "\n").utf8)
        do {
            switch name {
            case "progress":
                return .progress(try JSONDecoder().decode(DishRecreationProgress.self, from: data).state)
            case "result":
                return .result(try JSONDecoder().decode(DishRecreationResult.self, from: data))
            case "error":
                return .failure(try JSONDecoder().decode(DishRecreationFailure.self, from: data))
            default:
                return nil
            }
        } catch {
            throw AppCoreClientError.decoding(String(describing: error))
        }
    }

    private func decodeChatStreamFrame(_ frame: String) throws -> ChatStreamEvent? {
        let lines = frame.split(whereSeparator: { $0.isNewline })
        let name = lines.first(where: { $0.hasPrefix("event:") })
            .map { String($0.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
        let dataLines = lines.filter { $0.hasPrefix("data:") }
            .map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        guard let name, !dataLines.isEmpty else { return nil }
        let data = Data(dataLines.joined(separator: "\n").utf8)
        do {
            switch name {
            case "delta":
                return .delta(try JSONDecoder().decode(ChatStreamDelta.self, from: data).text)
            case "completed":
                return .completed(try JSONDecoder().decode(ChatResponse.self, from: data))
            default:
                return nil
            }
        } catch {
            throw AppCoreClientError.decoding(String(describing: error))
        }
    }

    private func url(path: [String]) -> URL {
        path.reduce(baseURL) { url, component in
            url.appendingPathComponent(component)
        }
    }

    private func multipartBody(
        data: Data,
        fieldName: String = "image",
        fileName: String,
        mediaType: String,
        fields: [String: String],
        boundary: String
    ) -> Data {
        var body = Data()
        for field in fields.sorted(by: { $0.key < $1.key }) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(field.key)\"\r\n\r\n".utf8))
            body.append(Data("\(field.value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mediaType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

    private func multipartBody(
        fields: [String: String],
        files: [MultipartFilePart],
        boundary: String
    ) -> Data {
        var body = Data()
        for field in fields.sorted(by: { $0.key < $1.key }) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(field.key)\"\r\n\r\n".utf8))
            body.append(Data("\(field.value)\r\n".utf8))
        }
        for file in files {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n".utf8))
            body.append(Data("Content-Type: \(file.mediaType)\r\n\r\n".utf8))
            body.append(file.data)
            body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))
        return body
    }

    private func send<Response: Decodable>(
        _ request: URLRequest
    ) async throws -> Response {
        let data = try await perform(request)

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AppCoreClientError.decoding(String(describing: error))
        }
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        var authenticatedRequest = request
        authenticatedRequest.setValue(apiKey, forHTTPHeaderField: Self.apiKeyHeader)
        authenticatedRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: authenticatedRequest)
        } catch let error as URLError {
            throw AppCoreClientError.transport(error.code)
        } catch {
            throw AppCoreClientError.transport(.unknown)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppCoreClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(AppCoreAPIErrorResponse.self, from: data)
            throw AppCoreClientError.server(
                statusCode: httpResponse.statusCode,
                response: apiError
            )
        }

        return data
    }
}

private struct MultipartFilePart {
    let fieldName: String
    let data: Data
    let fileName: String
    let mediaType: String
}
