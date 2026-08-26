# AppCore Swift Client

A Swift 6 client package for the authenticated AppCore Spring Boot API.

The package currently supports:

- barcode product lookup and translation;
- short LEGO set description generation;
- raw Brickset set, additional-image, and instruction caching;
- localized wine and spirits description;
- plain-text translation;
- recipe extraction and translation;
- recipe product extraction;
- analytics event collection;
- AppCore API error decoding.

## Requirements

- Swift 6.3 or later
- iOS 15 or later
- macOS 12 or later

## Installation

In Xcode, select **File > Add Package Dependencies > Add Local**, then select the `appcore-swift` directory. Add the `AppCoreSwift` library product to your application target.

For another local Swift package, add this dependency to `Package.swift`:

```swift
dependencies: [
    .package(path: "../appcore-swift")
]
```

Then add the product to the appropriate target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "AppCoreSwift", package: "appcore-swift")
    ]
)
```

Import the generated Swift module with:

```swift
import AppCoreSwift
```

## Client configuration

Create one client and reuse it throughout the application:

```swift
import Foundation
import AppCoreSwift

let client = AppCoreClient(
    baseURL: URL(string: "https://api.example.com")!,
    apiKey: apiKey
)
```

The client sends the key in the `X-API-Key` header. Do not hardcode a production key in source code or commit it to the repository. Load it from the application's secure configuration.

## Barcode lookup

```swift
let product = try await client.barcode(
    "0057000613280",
    domain: .lego
)

print(product.barcode)
print(product.productName ?? "Unknown product")
print(product.brand ?? "Unknown brand")
print(product.description ?? "No description")
print(product.imageUrl ?? "No image")
```

Supported barcode domains are:

```swift
.food
.lego
.wine
```

### Translate a barcode product

```swift
guard let french = LanguageCode("fr") else {
    fatalError("Invalid language code")
}

let translatedProduct = try await client.translate(
    product,
    to: french
)
```

## LEGO set descriptions

Generate a short description from a set code and name in the requested language:

```swift
guard let french = LanguageCode("fr") else {
    fatalError("Invalid language code")
}

let description = try await client.describeBrickSet(
    code: "10307",
    name: "Eiffel Tower",
    in: french
)
```

AppCore owns the OpenAI prompt, model, output limits, and API key. The Swift client sends only the set code, set name, requested language, and its AppCore API key.

## Brickset cache

Read the raw `getSets` response cached by AppCore using either a complete set number or a barcode:

```swift
let cachedSet = try await client.bricksetSet("75313-1")
let cachedByBarcode = try await client.bricksetSet(barcode: "5702016913866")
```

On a cache miss, call Brickset in the application and use its response immediately, then asynchronously send the
complete response to AppCore without rebuilding or filtering its JSON:

```swift
try await client.cacheBricksetSet(bricksetGetSetsResponse)
```

Additional images use a separate raw JSON document:

```swift
let images = try await client.bricksetAdditionalImages(for: "75313-1")
try await client.cacheBricksetAdditionalImages(
    bricksetAdditionalImagesResponse,
    for: "75313-1"
)
```

Building instructions use the complete raw `getInstructions2` response in another separate document:

```swift
let instructions = try await client.bricksetInstructions(for: "10276-1")
try await client.cacheBricksetInstructions(
    bricksetInstructionsResponse,
    for: "10276-1"
)
```

`BricksetJSON` is an alias of `JSONValue`, preserving unknown fields, nested objects, arrays, strings, numbers,
booleans, and null values. These methods call only the public API-key-protected `/api/lego/brickset/**` routes;
the Swift package exposes no `/api/admin/brickset/**` operation.

## Wine and spirits descriptions

Describe the product returned by a wine barcode lookup:

```swift
guard let french = LanguageCode("fr") else {
    fatalError("Invalid language code")
}

let barcodeProduct = try await client.barcode(
    "1234567890123",
    domain: .wine
)

guard let productName = barcodeProduct.productName else {
    fatalError("Wine barcode response has no product name")
}

let wine = try await client.describeWine(
    named: productName,
    in: french
)

if let error = wine.error {
    print(error)
} else {
    print(wine.description ?? "No description")
    print(wine.type ?? "other")
}
```

The response is compatible with the existing `WineProduct` contract, including `pays_d'Oc`, `regulated_designation`, `alcohol_content`, and `sugar_content`. AppCore owns the OpenAI model, prompt, output limit, strict response schema, and allowed beverage types.

### Describe a beverage from an image

Resize and encode the image in the application, then send the JPEG data directly. Do not convert it to a Base64 string in the client:

```swift
guard let imageData = resizedImage.jpegData(compressionQuality: 1) else {
    fatalError("Could not encode wine image")
}

let wine = try await client.describeWine(
    fromImage: imageData,
    fileName: "wine.jpg",
    mediaType: .jpeg,
    in: french
)
```

The request uses authenticated multipart form data and sends the language as a separate field. AppCore validates the image and owns the OpenAI vision request, prompt, model, and structured response schema.

### Describe a product from an image

Resize the image in the application and send its JPEG data directly; the client does not need to build a prompt or convert the image to Base64:

```swift
guard let imageData = resizedImage.jpegData(compressionQuality: 1) else {
    fatalError("Could not encode product image")
}

let product = try await client.describeProduct(
    fromImage: imageData,
    fileName: "product.jpg",
    mediaType: .jpeg,
    in: french
)

if let name = product.name, let description = product.description {
    print("\(name): \(description)")
} else {
    print("No single product could be identified")
}
```

AppCore returns both fields as `null` when it cannot identify one product with reasonable confidence or when the image contains multiple distinct products.

## Text translation

Translate plain text into a target language:

```swift
guard let english = LanguageCode("en") else {
    fatalError("Invalid language code")
}

let translatedText = try await client.translate(
    "Rare Sets",
    to: english,
    context: "Title of a collection of rare LEGO sets."
)

print(translatedText)
```

The request is sent to `POST /api/ai/texts/translate`. Text is limited to 20,000 characters by the AppCore server. The optional context is limited to 500 characters and helps resolve terminology, tone, or intended use. It is not translated or returned. Calls that do not need context can omit the argument.

## Text correction and composition

Correct a text while preserving its language, meaning, tone, and formatting:

```swift
let correctedText = try await client.correct(
    "Je sui disponible mardi.",
    context: "Professional email"
)
```

Compose one email, message, publication, or letter from a business brief:

```swift
let email = try await client.compose(
    "Ask Marie whether she is available for a project meeting on Tuesday afternoon.",
    as: .email,
    in: LanguageCode("fr")!,
    context: "Friendly professional relationship."
)
```

Composition types are `.email`, `.message`, `.publication`, and `.letter`. The server validates text lengths and owns the writing instructions, model, and provider configuration.

## Task AI

Generate subtasks, risks, and assistant-ready questions for a task:

```swift
let french = LanguageCode("fr")!
let task = "Ajouter le streaming au chat macOS"

let subtasks = try await client.generateSubtasks(for: task, in: french)
let risks = try await client.generateRisks(for: task, in: french)
let questions = try await client.generateQuestions(for: task, in: french)
let tags = try await client.suggestTags(
    for: task,
    existingTags: ["#Travail", "#Personnel"],
    in: french
)

let analysis = try await client.analyzeTask(task, in: french)
print(analysis.subtasks)
print(analysis.risks)
print(analysis.suggestedQuestions)
```

Tag suggestions are sent to `POST /api/ai/tasks/tags`. AppCore receives the existing tag names so it can reuse an exact relevant tag instead of suggesting a duplicate with different case, spacing, or a missing `#`. The server returns exactly five canonical `#`-prefixed suggestions and owns all OpenAI instructions and model settings.

Improve a task while retaining both versions:

```swift
let result = try await client.improveTask(
    "faire endpoint pour stream chat mac",
    in: french
)

print(result.original)
print(result.improved)
```

Omit the language argument to let AppCore detect the task language. The three generation methods each return exactly five strings, as guaranteed and validated by the server. `analyzeTask` returns all three collections in one request.

## Streaming chat

Stream chat deltas while sending prior user and assistant messages as structured history:

```swift
let conversation = [
    ChatMessage(role: .user, content: "I want to add streaming to my macOS app."),
    ChatMessage(role: .assistant, content: "Start with an SSE endpoint on the backend.")
]

for try await event in client.streamChat(
    "How should I test this approach?",
    conversation: conversation
) {
    switch event {
    case .delta(let text):
        print(text, terminator: "")
    case .completed(let response):
        print("\nModel: \(response.model), tokens: \(response.usage.totalTokens ?? 0)")
    }
}
```

Only `.user` and `.assistant` roles are available to clients. AppCore owns the privileged developer instructions and appends the current prompt as the final user message.

## Recipes

### Discover real web recipes from inventory

```swift
let request = RecipeDiscoveryRequest(
    locale: "fr-CA",
    priorityProductIds: ["chicken", "broccoli"],
    comment: "Des pâtes rapides pour quatre personnes",
    inventory: [
        InventoryRecipeProduct(id: "chicken", name: "Poitrine de poulet", quantity: 2, unit: "unité"),
        InventoryRecipeProduct(id: "broccoli", name: "Brocoli", quantity: 1, unit: "unité"),
        InventoryRecipeProduct(id: "pasta", name: "Pâtes", quantity: 500, unit: "g")
    ]
)

for try await event in client.streamRecipeDiscovery(request) {
    switch event {
    case .progress(let state):
        print(state.rawValue)
    case .result(let result):
        for recipe in result.recipes {
            print(recipe.title, recipe.sourceURL, recipe.imageURL)
        }
    case .failure(let failure):
        print(failure.message)
    }
}
```

Use `try await client.discoverRecipes(request)` when progress events are not needed. AppCore selects at most 40
inventory candidates locally, searches real recipe pages in the requested locale language, and returns at most five
results with required source and image URLs. Full recipe extraction remains a separate call to
`extractRecipe(fromURL:)` after the user selects a result.

### Extract a recipe from text

```swift
let recipe = try await client.extractRecipe(
    fromText: """
    Toast

    Ingredients:
    - 2 slices of bread

    Instructions:
    Toast the bread.
    """
)

print(recipe.name)
print(recipe.recipeIngredient)
print(recipe.recipeInstructions)
```

### Extract a recipe from a URL

Before choosing the URL extraction path, clients can retrieve AppCore's current client-download domains:

```swift
let extractionDomains = try await client.recipeExtractionDomains()
let host = recipeURL.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
let shouldDownloadOnDevice = host.map { host in
    extractionDomains.contains { domain in
        host == domain || host.hasSuffix(".\(domain)")
    }
} ?? false
```

The call uses `GET /api/ai/recipes/extraction-domains` with the configured API key. Returned domains are normalized
and sorted by AppCore. Clients should compare URL hosts, not use substring matching. When a domain matches, download
the page on-device and submit its content with `extractRecipe(fromWebContent:sourceURL:contentType:)`.

```swift
let recipeURL = URL(string: "https://example.com/recipe")!
let recipe = try await client.extractRecipe(fromURL: recipeURL)
```

AppCore performs the remote download and recipe extraction. The URL must satisfy the server's URL security rules.

### Extract a recipe from web content

```swift
let recipe = try await client.extractRecipe(
    fromWebContent: visibleText,
    sourceURL: URL(string: "https://example.com/recipe")!,
    contentType: .text
)
```

For Schema.org JSON-LD content, use:

```swift
let recipe = try await client.extractRecipe(
    fromWebContent: jsonLD,
    sourceURL: URL(string: "https://example.com/recipe")!,
    contentType: .jsonLD
)
```

### Extract a recipe from an image

```swift
let recipe = try await client.extractRecipe(
    fromImage: imageData,
    fileName: "recipe.jpg",
    mediaType: .jpeg
)
```

Supported image media types are `.jpeg`, `.png`, and `.webP`. AppCore applies its configured image size, format, and dimension limits.

### Recreate a restaurant dish

Dish recreation streams progress and returns a named collection of independently reusable recipe components:

```swift
let request = DishRecreationRequest(
    dishName: "Poulet à l’origan",
    restaurantName: "Au Vieux Duluth",
    restaurantLocation: "Montréal",
    description: "Servi avec pommes de terre, riz et salade",
    servings: 4,
    language: LanguageCode("fr"),
    dishImage: DishRecreationImage(
        data: dishImageData,
        fileName: "dish.jpg",
        mediaType: .jpeg
    )
)

for try await event in client.recreateDish(request) {
    switch event {
    case .progress(let state):
        print(state)
    case .result(let result):
        for component in result.recipes {
            print(component.type, component.recipe.name)
        }
    case .failure(let failure):
        print(failure.code, failure.message)
    }
}
```

The optional `dishImage` and `menuImage` use the backend multipart field names of the same name. Progress states mirror AppCore (`ANALYZING_IMAGE`, `SEARCHING_WEB`, and `GENERATING_RECIPE`). The terminal result groups `MAIN`, `SIDE`, `SAUCE`, `DESSERT`, or `OTHER` components under one reconstructed dish. AppCore owns web search, prompting, model selection, and recipe generation.

### Translate a recipe

```swift
guard let french = LanguageCode("fr") else {
    fatalError("Invalid language code")
}

let translatedRecipe = try await client.translate(
    recipe,
    to: french
)
```

`LanguageCode` accepts exactly two ASCII letters and normalizes them to lowercase. Examples include `en`, `fr`, `de`, and `it`.

## Voice Inbox

Transcribe browser or device audio, then organize the transcription with the server-owned Voice Inbox prompt and model:

```swift
let text = try await client.transcribeAudio(
    audioData,
    fileName: "voice.webm",
    mediaType: .webM
)

let inbox = try await client.organizeVoiceInbox(text)
print(inbox.title)
print(inbox.summary)
print(inbox.tasks)
```

The transcription request sends authenticated multipart form data using the backend field `file`. Supported `AudioMediaType` values mirror AppCore's accepted MIME types. The organization request sends only `{ "text": "..." }`; prompts, models, and provider parameters remain owned by AppCore.

### Extract grocery products from recipe ingredients

```swift
let ingredientProducts = try await client.extractRecipeProducts(
    from: recipe.recipeIngredient
)

for result in ingredientProducts {
    print(result.ingredient)
    print(result.products)
}
```

## Analytics events

AppCore derives the application client ID, API key ID, event ID, and receipt timestamp on the server. These fields cannot be supplied by the Swift client.

```swift
guard let eventType = AnalyticsEventType("recipe.imported") else {
    fatalError("Invalid analytics event type")
}

let event = AnalyticsEvent(
    eventType: eventType,
    anonymousUserId: anonymousUserId,
    sessionId: sessionId,
    platform: "IOS",
    appVersion: "1.0.0",
    language: LanguageCode("fr"),
    region: "CA",
    subscriptionStatus: "ACTIVE",
    purchased: true,
    properties: [
        "source": "URL",
        "host": "recettes.qc.ca",
        "success": true,
        "durationMs": 842
    ]
)

try await client.trackAnalyticsEvent(event)
```

Analytics event names use lowercase segments separated by `.` or `-`, for example:

```text
app.opened
recipe.imported
purchase.completed
```

Analytics properties use the type-safe `JSONValue` representation. Strings, integers, floating-point numbers, booleans, objects, arrays, and `null` are supported.

Do not send secrets or personal data in analytics properties. AppCore rejects sensitive property names such as `password`, `token`, `apiKey`, `email`, `phone`, `address`, `recipeText`, `prompt`, `message`, `content`, and `fullUrl`.

## Error handling

```swift
do {
    let product = try await client.barcode(
        "0057000613280",
        domain: .lego
    )
    print(product)
} catch let AppCoreClientError.server(statusCode, response) {
    print("AppCore error: \(statusCode)")
    print(response?.error ?? "UNKNOWN_ERROR")
    print(response?.message ?? "No error message")
    print(response?.details ?? [])
} catch let AppCoreClientError.transport(code) {
    print("Network error: \(code)")
} catch let AppCoreClientError.decoding(message) {
    print("Invalid AppCore response: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

Non-successful AppCore responses are decoded into `AppCoreAPIErrorResponse` whenever the response body matches the server's standard error contract.

## Testing

Run the package test suite with:

```shell
swift test
```

The tests use an injected `URLSession` and do not call a live AppCore server.
