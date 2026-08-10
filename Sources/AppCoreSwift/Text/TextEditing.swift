/// Body accepted by `POST /api/ai/texts/correct`.
public struct CorrectTextRequest: Codable, Equatable, Sendable {
    public let text: String
    public let context: String?

    public init(text: String, context: String? = nil) {
        self.text = text
        self.context = context
    }
}

/// Response returned by text correction and composition endpoints.
public struct GeneratedTextResponse: Codable, Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

/// Text formats accepted by `POST /api/ai/texts/compose`.
public enum TextCompositionType: String, Codable, CaseIterable, Sendable {
    case email = "EMAIL"
    case message = "MESSAGE"
    case publication = "PUBLICATION"
    case letter = "LETTER"
}

/// Body accepted by `POST /api/ai/texts/compose`.
public struct ComposeTextRequest: Codable, Equatable, Sendable {
    public let type: TextCompositionType
    public let brief: String
    public let targetLanguage: LanguageCode
    public let context: String?

    public init(
        type: TextCompositionType,
        brief: String,
        targetLanguage: LanguageCode,
        context: String? = nil
    ) {
        self.type = type
        self.brief = brief
        self.targetLanguage = targetLanguage
        self.context = context
    }
}
