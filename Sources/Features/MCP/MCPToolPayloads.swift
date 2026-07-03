import ContextCore

enum MCPToolPayloads {
  struct ValidationToolOutput: Codable, Equatable {
    struct Counts: Codable, Equatable {
      let personas: Int
      let kits: Int
      let directives: Int
      let skills: Int
    }

    let ok: Bool
    let counts: Counts
    let errors: [String]

    init(result: ValidationResult) {
      self.ok = result.errors.isEmpty
      self.counts = Counts(
        personas: result.counts.personas,
        kits: result.counts.kits,
        directives: result.counts.directives,
        skills: result.counts.skills
      )
      self.errors = result.errors.map { $0.lineDescription() }
    }
  }

  struct ExplainPayload<DataPayload: Encodable>: Encodable {
    let schemaVersion: Int = 1
    let entityType: String
    let id: String
    let data: DataPayload
  }

  struct PersonaExplainData: Encodable {
    let name: String
    let summary: String
    let defaultKitIds: [String]
    let allowedSkillIds: [String]
    let forbiddenSkillIds: [String]
    let responsibilitiesCount: Int
    let valuesCount: Int
    let nonGoalsCount: Int
  }

  struct DirectiveExplainData: Encodable {
    let title: String
    let goal: String
    let parameters: [String]
    let requiredSkillIds: [String]
    let stepsCount: Int
    let reviewStepCount: Int
    let riskLevel: String?
    let requiresHumanReview: Bool?
    let workstream: DirectiveExplainWorkstreamData?
  }

  struct DirectiveExplainWorkstreamData: Encodable {
    let id: String
    let phase: String
    let entrySessionId: String
    let requiredCloseoutSessionId: String?
    let nodeCount: Int
    let edgeCount: Int
  }

  struct KitExplainData: Encodable {
    let name: String
    let summary: String
    let skillIds: [String]
  }

  struct SkillExplainData: Encodable {
    let name: String
    let description: String
    let providedBy: [String]
    let capabilities: [String]
    let triggerSummaries: [String]
    let riskLevel: String
    let requiresHumanReview: Bool
    let notesCount: Int
  }

  struct SessionExplainData: Encodable {
    let personaId: String
    let directiveId: String
    let kitOverrides: [String]
    let personaExists: Bool
    let directiveExists: Bool
    let missingKitOverrides: [String]
  }

  struct EntityComparableSnapshot {
    let scalars: [String: String]
    let lists: [String: [String]]
  }

  struct ComparePayload: Encodable {
    let schemaVersion: Int = 1
    let entityType: String
    let leftId: String
    let rightId: String
    let scalarMatches: [String]
    let scalarDifferences: [CompareScalarDifference]
    let listMatches: [String]
    let listDifferences: [CompareListDifference]
  }

  struct CompareScalarDifference: Encodable {
    let field: String
    let left: String
    let right: String
  }

  struct CompareListDifference: Encodable {
    let field: String
    let shared: [String]
    let onlyLeft: [String]
    let onlyRight: [String]
  }

  struct SessionRecommendationPolicy: Encodable {
    let scoringVersion: Int = 1
    let weights: [String: Int] = [
      "personaTermMatch": 3,
      "directiveTermMatch": 2,
      "sessionIdTermMatch": 1,
    ]
    let tieBreakers: [String] = [
      "higherScoreFirst",
      "sessionIdAscending",
    ]
  }

  struct SessionRecommendationTermMatches: Encodable {
    let persona: [String]
    let directive: [String]
    let session: [String]
  }

  struct SessionRecommendation: Encodable {
    let sessionId: String
    let personaId: String
    let directiveId: String
    let kitOverrides: [String]
    let score: Int
    let matchedGoalTerms: [String]
    let termMatches: SessionRecommendationTermMatches
  }

  struct SessionRecommendationPayload: Encodable {
    let schemaVersion: Int = 1
    let goal: String
    let goalTerms: [String]
    let consideredSessions: [String]
    let policy: SessionRecommendationPolicy
    let recommendations: [SessionRecommendation]
  }

  struct SessionReferenceResolutionPayload: Encodable {
    let schemaVersion: Int = 1
    let inputRef: String
    let sourceRefType: String
    let normalizedSessionId: String
    let resolvedPath: String
    let scopeRootPath: String
    let personaId: String
    let directiveId: String
    let kitOverrides: [String]
  }

  struct SessionTracePayload: Encodable {
    let schemaVersion: Int = 1
    let session: SessionTraceSession
    let resolved: SessionTraceResolved
    let edges: SessionTraceEdges
    let workstream: SessionTraceWorkstream?
  }

  struct SessionTraceSession: Encodable {
    let id: String
    let personaId: String
    let directiveId: String
    let kitOverrides: [String]
  }

  struct SessionTraceResolved: Encodable {
    let personaId: String
    let directiveId: String
    let kitIds: [String]
    let availableGroundingSkillIds: [String]
    let skillIds: [String]
    let skillAuthorization: SessionTraceSkillAuthorization
  }

  struct SessionTraceSkillAuthorization: Encodable {
    let allowedSkillIds: [String]
    let forbiddenSkillIds: [String]
    let authorizedSkillIds: [String]
    let requiredSkillIds: [String]
    let unauthorizedRequiredSkillIds: [String]
    let isAuthorized: Bool
  }

  struct SessionTraceEdges: Encodable {
    let personaDefaultKitIds: [String]
    let sessionKitOverrideIds: [String]
    let directiveSkillIds: [String]
    let kitToSkills: [SessionTraceEdgeMap]
  }

  struct SessionTraceEdgeMap: Encodable {
    let sourceId: String
    let targetIds: [String]
  }

  struct SessionTraceWorkstream: Encodable {
    let id: String
    let phase: String
    let currentSessionId: String?
    let entrySessionId: String
    let requiredCloseoutSessionId: String?
    let nextSessionIds: [String]
    let nodes: [SessionTraceWorkstreamNode]
    let edges: [SessionTraceWorkstreamEdge]
  }

  struct SessionTraceWorkstreamNode: Encodable {
    let sessionId: String
    let phase: String
  }

  struct SessionTraceWorkstreamEdge: Encodable {
    let fromSessionId: String
    let toSessionId: String
    let kind: String
  }
}
