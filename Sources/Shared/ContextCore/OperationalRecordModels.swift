import Foundation

public struct PartnerContextEvent: Codable, Equatable, Sendable {
  public let entryId: String
  public let date: String
  public let sessionId: String
  public let summary: String
  public let implications: String
  public let affectedIds: [String]
  public let nextAction: String
  public let verification: String
  public let details: [String: String]?
}

public struct PartnerHandoffEvent: Codable, Equatable, Sendable {
  public let entryId: String
  public let handoffId: String
  public let date: String
  public let sessionId: String
  public let title: String
  public let ownerRef: String
  public let writeScope: String
  public let acceptanceCriteria: String
  public let risks: String
  public let status: String
  public let eventType: String
  public let details: [String: String]?
}

public struct GitHistoryProposalEvent: Codable, Equatable, Sendable {
  public let entryId: String
  public let proposalId: String
  public let date: String
  public let sessionId: String
  public let analysisPassId: String
  public let candidateCommit: String
  public let proposedAction: String
  public let rationale: String
  public let risk: String
  public let commandPlan: String
  public let approvalStatus: String
  public let eventType: String
  public let details: [String: String]?
}
