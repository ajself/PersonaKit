import Foundation

public enum SessionRecommendationSupport {
  public struct InvalidSession: Equatable, Sendable {
    public let sessionId: String
    public let field: String
    public let missingId: String
    public let message: String

    public init(
      sessionId: String,
      field: String,
      missingId: String,
      message: String
    ) {
      self.sessionId = sessionId
      self.field = field
      self.missingId = missingId
      self.message = message
    }
  }

  public struct TermMatches: Codable, Equatable, Sendable {
    public let persona: [String]
    public let directive: [String]
    public let session: [String]

    public init(
      persona: [String],
      directive: [String],
      session: [String]
    ) {
      self.persona = persona
      self.directive = directive
      self.session = session
    }
  }

  public struct Recommendation: Codable, Equatable, Sendable {
    public let sessionId: String
    public let personaId: String
    public let directiveId: String
    public let kitOverrides: [String]
    public let score: Int
    public let matchedGoalTerms: [String]
    public let termMatches: TermMatches

    public init(
      sessionId: String,
      personaId: String,
      directiveId: String,
      kitOverrides: [String],
      score: Int,
      matchedGoalTerms: [String],
      termMatches: TermMatches
    ) {
      self.sessionId = sessionId
      self.personaId = personaId
      self.directiveId = directiveId
      self.kitOverrides = kitOverrides
      self.score = score
      self.matchedGoalTerms = matchedGoalTerms
      self.termMatches = termMatches
    }
  }

  public struct Result: Equatable, Sendable {
    public let goal: String
    public let goalTerms: [String]
    public let consideredSessionIds: [String]
    public let invalidSessions: [InvalidSession]
    public let recommendations: [Recommendation]

    public init(
      goal: String,
      goalTerms: [String],
      consideredSessionIds: [String],
      invalidSessions: [InvalidSession],
      recommendations: [Recommendation]
    ) {
      self.goal = goal
      self.goalTerms = goalTerms
      self.consideredSessionIds = consideredSessionIds
      self.invalidSessions = invalidSessions
      self.recommendations = recommendations
    }
  }

  public static func recommend(
    goal: String,
    sessions: [SessionFile],
    registry: Registry
  ) -> Result {
    let goalTerms = tokenSet(goal)
    let reviewIntentTerms = goalTerms.filter { reviewIntentVocabulary.contains($0) }
    var invalidSessions: [InvalidSession] = []
    let recommendations = sessions.compactMap { session -> Recommendation? in
      guard let persona = registry.personasById[session.personaId] else {
        invalidSessions.append(
          InvalidSession(
            sessionId: session.id,
            field: "personaId",
            missingId: session.personaId,
            message: "Missing persona id."
          )
        )
        return nil
      }

      guard let directive = registry.directivesById[session.directiveId] else {
        invalidSessions.append(
          InvalidSession(
            sessionId: session.id,
            field: "directiveId",
            missingId: session.directiveId,
            message: "Missing directive id."
          )
        )
        return nil
      }

      let combinedText = [
        persona.id,
        persona.name,
        persona.summary,
        persona.responsibilities.joined(separator: " "),
        persona.values.joined(separator: " "),
        directive.id,
        directive.title,
        directive.goal,
        directive.acceptanceCriteria.joined(separator: " "),
        directive.steps.map(\.text).joined(separator: " "),
      ].joined(separator: " ")
      let personaTerms = matchedTerms(
        goalTerms: goalTerms,
        text: [
          persona.id,
          persona.name,
          persona.summary,
          persona.responsibilities.joined(separator: " "),
          persona.values.joined(separator: " "),
        ].joined(separator: " ")
      )

      let directiveTerms = matchedTerms(
        goalTerms: goalTerms,
        text: [
          directive.id,
          directive.title,
          directive.goal,
          directive.acceptanceCriteria.joined(separator: " "),
          directive.steps.map(\.text).joined(separator: " "),
        ].joined(separator: " ")
      )

      let sessionTerms = matchedTerms(
        goalTerms: goalTerms,
        text: session.id
      )

      let reviewSignalTerms = matchedTerms(
        goalTerms: reviewIntentTerms,
        text: combinedText
      )
      let reviewBonus = reviewSignalTerms.count * 5

      let score = personaTerms.count * 3 + directiveTerms.count * 2 + sessionTerms.count + reviewBonus

      return Recommendation(
        sessionId: session.id,
        personaId: session.personaId,
        directiveId: session.directiveId,
        kitOverrides: uniqueSorted(session.kitOverrides ?? []),
        score: score,
        matchedGoalTerms: uniqueSorted(personaTerms + directiveTerms + sessionTerms),
        termMatches: TermMatches(
          persona: personaTerms,
          directive: directiveTerms,
          session: sessionTerms
        )
      )
    }
    .sorted {
      if $0.score != $1.score {
        return $0.score > $1.score
      }

      return $0.sessionId < $1.sessionId
    }

    let sortedInvalidSessions = invalidSessions.sorted { lhs, rhs in
      if lhs.sessionId != rhs.sessionId {
        return lhs.sessionId < rhs.sessionId
      }

      if lhs.field != rhs.field {
        return lhs.field < rhs.field
      }

      if lhs.missingId != rhs.missingId {
        return lhs.missingId < rhs.missingId
      }

      return lhs.message < rhs.message
    }

    return Result(
      goal: goal,
      goalTerms: goalTerms,
      consideredSessionIds: sessions.map(\.id).sorted(),
      invalidSessions: sortedInvalidSessions,
      recommendations: recommendations
    )
  }

  public static func formatInvalidSessions(_ invalidSessions: [InvalidSession]) -> String {
    guard !invalidSessions.isEmpty else {
      return ""
    }

    let lines = invalidSessions.map { issue in
      "session \(issue.sessionId) \(issue.field): \(issue.message) missingId=\(issue.missingId)"
    }

    return (["Invalid session definitions found."] + lines).joined(separator: "\n")
  }

  private static func uniqueSorted(_ ids: [String]) -> [String] {
    Set(ids).sorted()
  }

  private static func tokenSet(_ text: String) -> [String] {
    let stopWords: Set<String> = [
      "a", "an", "and", "as", "at", "be", "by", "for", "from", "in", "into", "is", "it", "of",
      "on", "or", "that", "the", "to", "with", "without", "you", "your",
    ]

    let normalized = text.lowercased()
    let parts =
      normalized
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { $0.count >= 3 }
      .filter { !stopWords.contains($0) }

    return uniqueSorted(parts)
  }

  private static func matchedTerms(goalTerms: [String], text: String) -> [String] {
    let haystack = text.lowercased()
    return goalTerms.filter { haystack.contains($0) }
  }
}

private let reviewIntentVocabulary: Set<String> = [
  "architecture",
  "audit",
  "boundaries",
  "concurrency",
  "invariant",
  "invariants",
  "review",
  "safety",
]
