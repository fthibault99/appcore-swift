public enum ChatRole: String, Codable, Equatable, Sendable {
    case user = "USER"
    case assistant = "ASSISTANT"
}

public struct ChatMessage: Codable, Equatable, Sendable {
    public let role: ChatRole
    public let content: String

    public init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatUsage: Codable, Equatable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?

    public init(inputTokens: Int?, outputTokens: Int?, totalTokens: Int?) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }
}

public struct ChatResponse: Codable, Equatable, Sendable {
    public let answer: String
    public let model: String
    public let usage: ChatUsage

    public init(answer: String, model: String, usage: ChatUsage) {
        self.answer = answer
        self.model = model
        self.usage = usage
    }
}

public enum ChatStreamEvent: Equatable, Sendable {
    case delta(String)
    case completed(ChatResponse)
}

struct ChatRequest: Codable, Sendable {
    let prompt: String
    let conversation: [ChatMessage]
}

struct ChatStreamDelta: Codable {
    let text: String
}
