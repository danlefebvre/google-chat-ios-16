import Foundation

public enum MessageComposerError: Error {
    case emptyMessage
}

public enum MessageComposer {
    public static func createTextMessageBody(text: String) throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MessageComposerError.emptyMessage
        }

        let payload = ["text": trimmed]
        return try JSONSerialization.data(withJSONObject: payload)
    }
}
