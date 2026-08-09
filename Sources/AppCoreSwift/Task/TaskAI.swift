/// Body accepted by the Task AI endpoints.
public struct TaskAIRequest: Codable, Equatable, Sendable {
    public let task: String
    public let language: LanguageCode?

    public init(task: String, language: LanguageCode? = nil) {
        self.task = task
        self.language = language
    }
}

/// Response returned by Task AI list-generation endpoints.
public struct TaskItemsResponse: Codable, Equatable, Sendable {
    public let items: [String]

    public init(items: [String]) {
        self.items = items
    }
}

/// Improved task returned by `POST /api/ai/tasks/improve`.
public struct ImprovedTask: Codable, Equatable, Sendable {
    public let original: String
    public let improved: String

    public init(original: String, improved: String) {
        self.original = original
        self.improved = improved
    }
}

/// Combined response returned by `POST /api/ai/tasks/analyze`.
public struct TaskAnalysis: Codable, Equatable, Sendable {
    public let subtasks: [String]
    public let risks: [String]
    public let suggestedQuestions: [String]

    public init(
        subtasks: [String],
        risks: [String],
        suggestedQuestions: [String]
    ) {
        self.subtasks = subtasks
        self.risks = risks
        self.suggestedQuestions = suggestedQuestions
    }
}
