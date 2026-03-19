import Foundation

public struct OrbitPhase1ParticipantJoinedPayload: Codable, Equatable, Sendable {
  public let participantType: String
  public let participantID: String
  public let joinedAt: Date
  public let participationMode: String
}

public struct OrbitPhase1MessageCreatedPayload: Codable, Equatable, Sendable {
  public let messageID: UUID
  public let postID: UUID
  public let threadID: UUID
  public let authorType: String
  public let authorID: String
  public let body: String
  public let messageFormat: String
  public let state: String
  public let createdAt: Date
  public let updatedAt: Date
  public let replyToMessageID: UUID?
}

public struct OrbitPhase1ThreadActivityUpdatedPayload: Codable, Equatable, Sendable {
  public let threadID: UUID
  public let lastActivityAt: Date
}

public struct OrbitPhase1ActivationEventPayload: Codable, Equatable, Sendable {
  public let activationID: UUID?
  public let responseMode: String?
  public let reason: String?
}

public enum OrbitPhase1RealtimeEventPayloadCodec {
  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }()

  private static let decoder = JSONDecoder()

  public static func encode<T: Encodable & Sendable>(
    _ value: T
  ) throws -> String {
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
  }

  public static func decode<T: Decodable & Sendable>(
    _ type: T.Type,
    from payloadJSON: String
  ) throws -> T {
    try decoder.decode(T.self, from: Data(payloadJSON.utf8))
  }
}
