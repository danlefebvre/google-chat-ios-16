import Foundation

public enum MessagePreviewBuilder {
    public static func preview(for message: ChatMessage) -> String {
        if let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            let sender = message.sender?.displayName ?? "Someone"
            return "\(sender): \(text)"
        }

        if let attachment = message.attachment?.first {
            let name = attachment.contentName ?? attachment.name ?? "file"
            return "[attachment] \(name)"
        }

        return "New message"
    }
}

public struct MediaUploadRequest: Codable, Sendable {
    public let filename: String
    public let mimeType: String

    public init(filename: String, mimeType: String) {
        self.filename = filename
        self.mimeType = mimeType
    }
}

public extension ChatAPIClient {
    func downloadAttachment(accessToken: String, downloadUri: String) async throws -> Data {
        guard let url = URL(string: downloadUri) else {
            throw ChatAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    func addReaction(
        accessToken: String,
        messageName: String,
        emoji: String
    ) async throws {
        guard let url = URL(string: baseURL.absoluteString + "/\(messageName)/reactions") else {
            throw ChatAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["emoji": ["unicode": emoji]])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }
}
