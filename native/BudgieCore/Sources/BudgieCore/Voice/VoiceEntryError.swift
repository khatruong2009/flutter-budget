/// Why a voice entry stopped, with the message the recording sheet shows
/// (voice_recording_sheet.dart, voice_expense_service.dart). Thrown by
/// `OpenAIVoiceClient` and `VoiceDraftParser`; the sheet decides what
/// "Try again" re-runs from the stage that failed.
public enum VoiceEntryError: Error, Equatable, Sendable {
    /// Microphone permission is denied or restricted.
    case microphoneDenied
    /// No usable API key in the bundle (empty or the example placeholder).
    case notConfigured
    /// The transcription came back empty.
    case noSpeech
    /// The model output was not a JSON object.
    case unreadable(transcript: String)
    /// The model answered `{"error": ...}`.
    case notATransaction(transcript: String)
    /// OpenAI refused the key (HTTP 401 or 403). No retry loop.
    case unauthorized
    /// OpenAI rate limit or quota (HTTP 429). No retry loop.
    case rateLimited
    /// Anything else: offline, timeout, another status, a malformed body.
    case failed

    public var message: String {
        switch self {
        case .microphoneDenied: "Microphone access is off. Enable it in Settings > Budgie."
        case .notConfigured: "OpenAI is not configured. Add OPENAI_API_KEY to native/Config/Secrets.xcconfig."
        case .noSpeech: "Didn't catch anything — try again"
        case .unreadable: "Couldn't read that as a transaction — try again"
        case .notATransaction: "That didn't sound like a transaction — try again"
        // Flutter's generic copy: the owner decided (2026-09-30) that users
        // need not know which failure it was.
        case .unauthorized, .rateLimited, .failed: "Something went wrong. Try again."
        }
    }

    /// The transcript to quote under the message, when parsing failed.
    public var transcript: String? {
        switch self {
        case .unreadable(let transcript), .notATransaction(let transcript): transcript
        default: nil
        }
    }
}
