import Foundation

/// Audio media types accepted by `POST /api/ai/audio/transcriptions`.
public enum AudioMediaType: String, Sendable {
    case webM = "audio/webm"
    case ogg = "audio/ogg"
    case mp4 = "audio/mp4"
    case mpeg = "audio/mpeg"
    case wav = "audio/wav"
    case xWav = "audio/x-wav"
    case flac = "audio/flac"
    case xFlac = "audio/x-flac"
}

struct AudioTranscriptionResponse: Codable, Equatable, Sendable {
    let text: String
}

struct OrganizeVoiceInboxRequest: Codable, Equatable, Sendable {
    let text: String
}

/// Organized content returned by `POST /api/ai/voice-inbox/organize`.
public struct VoiceInbox: Codable, Equatable, Sendable {
    public let title: String
    public let summary: String
    public let tasks: [String]

    public init(title: String, summary: String, tasks: [String]) {
        self.title = title
        self.summary = summary
        self.tasks = tasks
    }
}
