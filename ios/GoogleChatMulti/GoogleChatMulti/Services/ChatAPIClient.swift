import Foundation
import GoogleChatCore

/// Thin REST client for Google Chat API (URLSession + async/await).
public final class ChatAPIClient: Sendable {
  private let baseURL = URL(string: "https://chat.googleapis.com/v1")!
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func listSpaces(accessToken: String, pageToken: String? = nil) async throws -> ([ChatSpace], String?) {
    var components = URLComponents(url: baseURL.appendingPathComponent("spaces"), resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "pageSize", value: "100"),
      URLQueryItem(name: "filter", value: "spaceType = \"SPACE\" OR spaceType = \"DIRECT_MESSAGE\""),
    ]
    if let pageToken {
      components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
    }

    let request = try authorizedRequest(url: components.url!, accessToken: accessToken)
    let (data, response) = try await session.data(for: request)
    try validate(response: response)

    let decoded = try JSONDecoder().decode(ListSpacesResponse.self, from: data)
    let spaces = decoded.spaces?.map {
      ChatSpace(
        name: $0.name,
        displayName: $0.displayName ?? $0.name,
        type: $0.spaceType == "DIRECT_MESSAGE" ? .directMessage : .space
      )
    } ?? []
    return (spaces, decoded.nextPageToken)
  }

  public func listMessages(
    accessToken: String,
    spaceName: String,
    pageToken: String? = nil
  ) async throws -> MessagePage {
    var components = URLComponents(
      url: baseURL.appendingPathComponent("\(spaceName)/messages"),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = [URLQueryItem(name: "pageSize", value: "50")]
    if let pageToken {
      components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
    }

    let request = try authorizedRequest(url: components.url!, accessToken: accessToken)
    let (data, response) = try await session.data(for: request)
    try validate(response: response)

    let decoded = try JSONDecoder().decode(ListMessagesResponse.self, from: data)
    let messages = decoded.messages?.compactMap { $0.toModel(spaceName: spaceName) } ?? []
    return MessagePage(messages: messages, nextPageToken: decoded.nextPageToken)
  }

  public func createMessage(accessToken: String, spaceName: String, text: String) async throws -> ChatMessage {
    let url = baseURL.appendingPathComponent("\(spaceName)/messages")
    var request = try authorizedRequest(url: url, accessToken: accessToken, method: "POST")
    let body = CreateMessageRequest(text: text)
    request.httpBody = try JSONEncoder().encode(body)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await session.data(for: request)
    try validate(response: response)
    let decoded = try JSONDecoder().decode(MessageDTO.self, from: data)
    return decoded.toModel(spaceName: spaceName) ?? ChatMessage(
      name: decoded.name ?? UUID().uuidString,
      spaceName: spaceName,
      text: text,
      senderDisplayName: "You",
      createTime: Date()
    )
  }

  private func authorizedRequest(url: URL, accessToken: String, method: String = "GET") throws -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    return request
  }

  private func validate(response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      let code = (response as? HTTPURLResponse)?.statusCode ?? -1
      throw ChatAPIError.httpError(code)
    }
  }
}

public enum ChatAPIError: Error {
  case httpError(Int)
}

// MARK: - DTOs

private struct ListSpacesResponse: Decodable {
  let spaces: [SpaceDTO]?
  let nextPageToken: String?
}

private struct SpaceDTO: Decodable {
  let name: String
  let displayName: String?
  let spaceType: String?
}

private struct ListMessagesResponse: Decodable {
  let messages: [MessageDTO]?
  let nextPageToken: String?
}

private struct MessageDTO: Decodable {
  let name: String?
  let text: String?
  let sender: SenderDTO?
  let createTime: String?

  func toModel(spaceName: String) -> ChatMessage? {
    guard let name, let text else { return nil }
    let date = ISO8601DateFormatter().date(from: createTime ?? "") ?? Date()
    return ChatMessage(
      name: name,
      spaceName: spaceName,
      text: text,
      senderDisplayName: sender?.displayName ?? "Unknown",
      createTime: date
    )
  }
}

private struct SenderDTO: Decodable {
  let displayName: String?
}

private struct CreateMessageRequest: Encodable {
  let text: String
}
