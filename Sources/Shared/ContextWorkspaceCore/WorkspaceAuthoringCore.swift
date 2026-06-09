import ContextCore
import Foundation

/// Shared template presets used by CLI and Studio authoring flows.
public enum WorkspaceCreationTemplate: String, CaseIterable, Codable, Sendable {
  case starter
  case minimal
}

/// Stable outcome returned after a shared authoring operation completes.
public struct WorkspaceCreationResult: Codable, Equatable, Sendable {
  public let entityType: String
  public let entityID: String
  public let destinationPath: String
  public let warnings: [String]
  public let overwroteExisting: Bool
  public let dryRun: Bool

  public init(
    entityType: String,
    entityID: String,
    destinationPath: String,
    warnings: [String],
    overwroteExisting: Bool,
    dryRun: Bool
  ) {
    self.entityType = entityType
    self.entityID = entityID
    self.destinationPath = destinationPath
    self.warnings = warnings
    self.overwroteExisting = overwroteExisting
    self.dryRun = dryRun
  }
}

/// Shared root resolver for authoring commands that must target a single writable scope.
public struct WorkspaceWritableRootResolver: Sendable {
  private let scopeRootResolver: ScopeRootResolver
  private let fileExists: @Sendable (String, UnsafeMutablePointer<ObjCBool>?) -> Bool

  public init(
    scopeRootResolver: ScopeRootResolver = ScopeRootResolver(),
    fileExists: @escaping @Sendable (String, UnsafeMutablePointer<ObjCBool>?) -> Bool = { path, isDirectory in
      FileManager.default.fileExists(atPath: path, isDirectory: isDirectory)
    }
  ) {
    self.scopeRootResolver = scopeRootResolver
    self.fileExists = fileExists
  }

  public func resolveWritableRoot(
    explicitRootURL: URL?
  ) throws -> URL {
    if let explicitRootURL {
      return try validateWritableRoot(explicitRootURL)
    }

    guard let scopes = scopeRootResolver.locate() else {
      throw WorkspaceSnapshotBuildError(
        message:
          "No PersonaKit scope found. Provide --root <path> or create .personakit in this project or ~/.personakit."
      )
    }

    if let projectScopeURL = scopes.projectScopeURL {
      return try validateWritableRoot(projectScopeURL)
    }

    if let globalScopeURL = scopes.globalScopeURL {
      return try validateWritableRoot(globalScopeURL)
    }

    throw WorkspaceSnapshotBuildError(
      message:
        "No PersonaKit scope found. Provide --root <path> or create .personakit in this project or ~/.personakit."
    )
  }

  private func validateWritableRoot(_ rootURL: URL) throws -> URL {
    let standardizedRootURL = rootURL.standardizedFileURL
    var isDirectory: ObjCBool = false

    guard
      fileExists(standardizedRootURL.path, &isDirectory),
      isDirectory.boolValue
    else {
      throw WorkspaceSnapshotBuildError(
        message: "PersonaKit root does not exist or is not a directory: \(standardizedRootURL.path)"
      )
    }

    guard PersonaKitDirectory.hasPacks(root: standardizedRootURL) else {
      throw WorkspaceSnapshotBuildError(
        message: "PersonaKit root must contain Packs/: \(standardizedRootURL.path)"
      )
    }

    return standardizedRootURL
  }
}

/// Shared authoring helpers for deterministic JSON and markdown output.
public enum WorkspaceAuthoringJSON {
  public static func encode<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)

    guard var rawJSON = String(data: data, encoding: .utf8) else {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to encode JSON."
      )
    }

    if !rawJSON.hasSuffix("\n") {
      rawJSON.append("\n")
    }

    return rawJSON
  }
}

/// Shared suggester for normalized entity ids derived from user-facing names or titles.
public enum WorkspaceEntityIDSuggester {
  public static func suggestedID(from source: String) -> String {
    let trimmedName = source.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedName.isEmpty else {
      return ""
    }

    var scalars: [Unicode.Scalar] = []
    var previousWasSeparator = false

    for scalar in trimmedName.lowercased().unicodeScalars {
      if CharacterSet.alphanumerics.contains(scalar) {
        scalars.append(scalar)
        previousWasSeparator = false
        continue
      }

      if scalar == "-" || scalar == "_" || scalar == "." || CharacterSet.whitespacesAndNewlines.contains(scalar) {
        guard !scalars.isEmpty, !previousWasSeparator else {
          continue
        }

        scalars.append("-")
        previousWasSeparator = true
      }
    }

    let scalarString = String(String.UnicodeScalarView(scalars))
    let normalized = scalarString.trimmingCharacters(in: CharacterSet(charactersIn: "-_."))

    return WorkspaceEntityIDPolicy.normalized(normalized)
  }
}

/// Shared validation payload for create builders.
public struct WorkspaceCreateValidation: Equatable, Sendable {
  public let errors: [String]
  public let warnings: [String]

  public init(
    errors: [String],
    warnings: [String]
  ) {
    self.errors = errors
    self.warnings = warnings
  }

  public var isValid: Bool {
    errors.isEmpty
  }
}

public struct WorkspaceKitDraft: Equatable, Sendable {
  public var id: String
  public var name: String
  public var summary: String
  public var essentialIds: [String]
  public var skillIds: [String]

  public init(
    id: String,
    name: String,
    summary: String,
    essentialIds: [String],
    skillIds: [String]
  ) {
    self.id = id
    self.name = name
    self.summary = summary
    self.essentialIds = essentialIds
    self.skillIds = skillIds
  }
}

public struct WorkspaceDirectiveDraft: Sendable {
  public var id: String
  public var title: String
  public var goal: String
  public var steps: [Directive.Step]
  public var acceptanceCriteria: [String]
  public var verification: [Directive.VerificationItem]
  public var requiresIntentTemplateIds: [String]
  public var requiresSkillIds: [String]
  public var referenceIds: [String]

  public init(
    id: String,
    title: String,
    goal: String,
    steps: [Directive.Step],
    acceptanceCriteria: [String],
    verification: [Directive.VerificationItem],
    requiresIntentTemplateIds: [String],
    requiresSkillIds: [String],
    referenceIds: [String] = []
  ) {
    self.id = id
    self.title = title
    self.goal = goal
    self.steps = steps
    self.acceptanceCriteria = acceptanceCriteria
    self.verification = verification
    self.requiresIntentTemplateIds = requiresIntentTemplateIds
    self.requiresSkillIds = requiresSkillIds
    self.referenceIds = referenceIds
  }
}

public struct WorkspaceIntentDraft: Sendable {
  public var id: String
  public var name: String
  public var description: String
  public var parameters: [IntentTemplate.Parameter]
  public var includesEssentialIds: [String]
  public var requiresSkillIds: [String]
  public var riskLevel: String
  public var requiresHumanReview: Bool
  public var riskNotes: [String]

  public init(
    id: String,
    name: String,
    description: String,
    parameters: [IntentTemplate.Parameter],
    includesEssentialIds: [String],
    requiresSkillIds: [String],
    riskLevel: String,
    requiresHumanReview: Bool,
    riskNotes: [String]
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.parameters = parameters
    self.includesEssentialIds = includesEssentialIds
    self.requiresSkillIds = requiresSkillIds
    self.riskLevel = riskLevel
    self.requiresHumanReview = requiresHumanReview
    self.riskNotes = riskNotes
  }
}

public struct WorkspaceSkillDraft: Equatable, Sendable {
  public var id: String
  public var name: String
  public var description: String
  public var providedBy: [String]
  public var riskLevel: String
  public var requiresHumanReview: Bool
  public var riskNotes: [String]
  public var notes: [String]

  public init(
    id: String,
    name: String,
    description: String,
    providedBy: [String],
    riskLevel: String,
    requiresHumanReview: Bool,
    riskNotes: [String],
    notes: [String]
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.providedBy = providedBy
    self.riskLevel = riskLevel
    self.requiresHumanReview = requiresHumanReview
    self.riskNotes = riskNotes
    self.notes = notes
  }
}

public struct WorkspaceKitDraftBuilder: Sendable {
  public init() {}

  public func defaultDraft(template: WorkspaceCreationTemplate) -> WorkspaceKitDraft {
    WorkspaceKitDraft(
      id: "",
      name: "",
      summary: "",
      essentialIds: [],
      skillIds: []
    )
  }

  public func suggestedID(from name: String) -> String {
    WorkspaceEntityIDSuggester.suggestedID(from: name)
  }

  public func validate(
    draft: WorkspaceKitDraft,
    knownEssentialIDs: Set<String> = [],
    knownSkillIDs: Set<String> = []
  ) -> WorkspaceCreateValidation {
    let normalized = normalizedDraft(draft)
    var errors: [String] = []
    var warnings: [String] = []

    validateCoreFields(
      id: normalized.id,
      displayName: "Kit",
      name: normalized.name,
      summary: normalized.summary,
      errors: &errors
    )

    let unknownEssentialIDs = normalized.essentialIds.filter { !knownEssentialIDs.contains($0) }
    if !unknownEssentialIDs.isEmpty {
      warnings.append("Unknown essential ids: \(unknownEssentialIDs.joined(separator: ", ")).")
    }

    let unknownSkillIDs = normalized.skillIds.filter { !knownSkillIDs.contains($0) }
    if !unknownSkillIDs.isEmpty {
      warnings.append("Unknown skill ids: \(unknownSkillIDs.joined(separator: ", ")).")
    }

    return WorkspaceCreateValidation(errors: errors, warnings: warnings)
  }

  public func buildRawJSON(
    draft: WorkspaceKitDraft,
    knownEssentialIDs: Set<String> = [],
    knownSkillIDs: Set<String> = []
  ) throws -> String {
    let validation = validate(
      draft: draft,
      knownEssentialIDs: knownEssentialIDs,
      knownSkillIDs: knownSkillIDs
    )

    guard validation.errors.isEmpty else {
      throw WorkspaceSnapshotBuildError(message: validation.errors.joined(separator: " "))
    }

    let normalized = normalizedDraft(draft)
    let kit = Kit(
      id: normalized.id,
      version: "1.0",
      name: normalized.name,
      summary: normalized.summary,
      essentialIds: normalized.essentialIds,
      intentTemplateIds: nil,
      skillIds: normalized.skillIds.isEmpty ? nil : normalized.skillIds
    )

    return try WorkspaceAuthoringJSON.encode(kit)
  }

  private func normalizedDraft(_ draft: WorkspaceKitDraft) -> WorkspaceKitDraft {
    WorkspaceKitDraft(
      id: WorkspaceEntityIDPolicy.normalized(draft.id),
      name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
      summary: draft.summary.trimmingCharacters(in: .whitespacesAndNewlines),
      essentialIds: normalizedIDs(draft.essentialIds),
      skillIds: normalizedIDs(draft.skillIds)
    )
  }
}

public struct WorkspaceDirectiveDraftBuilder: Sendable {
  public init() {}

  public func defaultDraft(template: WorkspaceCreationTemplate) -> WorkspaceDirectiveDraft {
    let starter = template == .starter

    return WorkspaceDirectiveDraft(
      id: "",
      title: "",
      goal: "",
      steps: starter ? [Directive.Step(text: "TODO: add directive step.", requiresReview: nil)] : [],
      acceptanceCriteria: starter ? ["TODO: add acceptance criteria."] : [],
      verification: starter ? [Directive.VerificationItem(kind: "manual", text: "TODO: review directive output.")] : [],
      requiresIntentTemplateIds: [],
      requiresSkillIds: []
    )
  }

  public func suggestedID(from title: String) -> String {
    WorkspaceEntityIDSuggester.suggestedID(from: title)
  }

  public func validate(
    draft: WorkspaceDirectiveDraft,
    knownIntentIDs: Set<String> = [],
    knownSkillIDs: Set<String> = [],
    knownReferenceIDs: Set<String> = []
  ) -> WorkspaceCreateValidation {
    let normalized = normalizedDraft(draft)
    var errors: [String] = []
    var warnings: [String] = []

    validateCoreFields(
      id: normalized.id,
      displayName: "Directive",
      name: normalized.title,
      summary: normalized.goal,
      errors: &errors
    )

    let unknownIntentIDs = normalized.requiresIntentTemplateIds.filter { !knownIntentIDs.contains($0) }
    if !unknownIntentIDs.isEmpty {
      warnings.append("Unknown intent ids: \(unknownIntentIDs.joined(separator: ", ")).")
    }

    let unknownSkillIDs = normalized.requiresSkillIds.filter { !knownSkillIDs.contains($0) }
    if !unknownSkillIDs.isEmpty {
      warnings.append("Unknown skill ids: \(unknownSkillIDs.joined(separator: ", ")).")
    }

    let unknownReferenceIDs = normalized.referenceIds.filter { !knownReferenceIDs.contains($0) }
    if !unknownReferenceIDs.isEmpty {
      warnings.append("Unknown reference ids: \(unknownReferenceIDs.joined(separator: ", ")).")
    }

    return WorkspaceCreateValidation(errors: errors, warnings: warnings)
  }

  public func buildRawJSON(
    draft: WorkspaceDirectiveDraft,
    knownIntentIDs: Set<String> = [],
    knownSkillIDs: Set<String> = [],
    knownReferenceIDs: Set<String> = []
  ) throws -> String {
    let validation = validate(
      draft: draft,
      knownIntentIDs: knownIntentIDs,
      knownSkillIDs: knownSkillIDs,
      knownReferenceIDs: knownReferenceIDs
    )

    guard validation.errors.isEmpty else {
      throw WorkspaceSnapshotBuildError(message: validation.errors.joined(separator: " "))
    }

    let normalized = normalizedDraft(draft)
    let directive = Directive(
      id: normalized.id,
      version: "1.0",
      title: normalized.title,
      goal: normalized.goal,
      steps: normalized.steps,
      acceptanceCriteria: normalized.acceptanceCriteria,
      verification: normalized.verification,
      requiresIntentTemplateIds: normalized.requiresIntentTemplateIds,
      requiresSkillIds: normalized.requiresSkillIds,
      referenceIds: normalized.referenceIds.isEmpty ? nil : normalized.referenceIds
    )

    return try WorkspaceAuthoringJSON.encode(directive)
  }

  private func normalizedDraft(_ draft: WorkspaceDirectiveDraft) -> WorkspaceDirectiveDraft {
    WorkspaceDirectiveDraft(
      id: WorkspaceEntityIDPolicy.normalized(draft.id),
      title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
      goal: draft.goal.trimmingCharacters(in: .whitespacesAndNewlines),
      steps: draft.steps
        .map { step in
          Directive.Step(
            text: step.text.trimmingCharacters(in: .whitespacesAndNewlines),
            requiresReview: step.requiresReview
          )
        }
        .filter { !$0.text.isEmpty },
      acceptanceCriteria: normalizedTextItems(draft.acceptanceCriteria),
      verification: draft.verification
        .map { item in
          Directive.VerificationItem(
            kind: item.kind.trimmingCharacters(in: .whitespacesAndNewlines),
            text: item.text.trimmingCharacters(in: .whitespacesAndNewlines)
          )
        }
        .filter { !$0.kind.isEmpty && !$0.text.isEmpty },
      requiresIntentTemplateIds: normalizedIDs(draft.requiresIntentTemplateIds),
      requiresSkillIds: normalizedIDs(draft.requiresSkillIds),
      referenceIds: normalizedIDs(draft.referenceIds)
    )
  }
}

public struct WorkspaceIntentDraftBuilder: Sendable {
  public init() {}

  public func defaultDraft(template: WorkspaceCreationTemplate) -> WorkspaceIntentDraft {
    WorkspaceIntentDraft(
      id: "",
      name: "",
      description: "",
      parameters: [],
      includesEssentialIds: [],
      requiresSkillIds: [],
      riskLevel: "medium",
      requiresHumanReview: false,
      riskNotes: []
    )
  }

  public func suggestedID(from name: String) -> String {
    WorkspaceEntityIDSuggester.suggestedID(from: name)
  }

  public func validate(
    draft: WorkspaceIntentDraft,
    knownEssentialIDs: Set<String> = [],
    knownSkillIDs: Set<String> = []
  ) -> WorkspaceCreateValidation {
    let normalized = normalizedDraft(draft)
    var errors: [String] = []
    var warnings: [String] = []

    validateCoreFields(
      id: normalized.id,
      displayName: "Intent",
      name: normalized.name,
      summary: normalized.description,
      errors: &errors
    )

    let unknownEssentialIDs = normalized.includesEssentialIds.filter { !knownEssentialIDs.contains($0) }
    if !unknownEssentialIDs.isEmpty {
      warnings.append("Unknown essential ids: \(unknownEssentialIDs.joined(separator: ", ")).")
    }

    let unknownSkillIDs = normalized.requiresSkillIds.filter { !knownSkillIDs.contains($0) }
    if !unknownSkillIDs.isEmpty {
      warnings.append("Unknown skill ids: \(unknownSkillIDs.joined(separator: ", ")).")
    }

    return WorkspaceCreateValidation(errors: errors, warnings: warnings)
  }

  public func buildRawJSON(
    draft: WorkspaceIntentDraft,
    knownEssentialIDs: Set<String> = [],
    knownSkillIDs: Set<String> = []
  ) throws -> String {
    let validation = validate(
      draft: draft,
      knownEssentialIDs: knownEssentialIDs,
      knownSkillIDs: knownSkillIDs
    )

    guard validation.errors.isEmpty else {
      throw WorkspaceSnapshotBuildError(message: validation.errors.joined(separator: " "))
    }

    let normalized = normalizedDraft(draft)
    let intent = IntentTemplate(
      id: normalized.id,
      version: "1.0",
      name: normalized.name,
      description: normalized.description,
      parameters: normalized.parameters,
      includesEssentialIds: normalized.includesEssentialIds,
      requiresSkillIds: normalized.requiresSkillIds,
      risk: IntentTemplate.Risk(
        level: normalized.riskLevel,
        requiresHumanReview: normalized.requiresHumanReview,
        notes: normalized.riskNotes
      )
    )

    return try WorkspaceAuthoringJSON.encode(intent)
  }

  private func normalizedDraft(_ draft: WorkspaceIntentDraft) -> WorkspaceIntentDraft {
    WorkspaceIntentDraft(
      id: WorkspaceEntityIDPolicy.normalized(draft.id),
      name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
      description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
      parameters: draft.parameters
        .map { parameter in
          IntentTemplate.Parameter(
            name: parameter.name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: parameter.type.trimmingCharacters(in: .whitespacesAndNewlines),
            required: parameter.required
          )
        }
        .filter { !$0.name.isEmpty && !$0.type.isEmpty },
      includesEssentialIds: normalizedIDs(draft.includesEssentialIds),
      requiresSkillIds: normalizedIDs(draft.requiresSkillIds),
      riskLevel: draft.riskLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
      requiresHumanReview: draft.requiresHumanReview,
      riskNotes: normalizedTextItems(draft.riskNotes)
    )
  }
}

public struct WorkspaceSkillDraftBuilder: Sendable {
  public init() {}

  public func defaultDraft(template: WorkspaceCreationTemplate) -> WorkspaceSkillDraft {
    WorkspaceSkillDraft(
      id: "",
      name: "",
      description: "",
      providedBy: [],
      riskLevel: "medium",
      requiresHumanReview: false,
      riskNotes: [],
      notes: []
    )
  }

  public func suggestedID(from name: String) -> String {
    WorkspaceEntityIDSuggester.suggestedID(from: name)
  }

  public func validate(
    draft: WorkspaceSkillDraft
  ) -> WorkspaceCreateValidation {
    let normalized = normalizedDraft(draft)
    var errors: [String] = []

    validateCoreFields(
      id: normalized.id,
      displayName: "Skill",
      name: normalized.name,
      summary: normalized.description,
      errors: &errors
    )

    return WorkspaceCreateValidation(errors: errors, warnings: [])
  }

  public func buildRawJSON(
    draft: WorkspaceSkillDraft
  ) throws -> String {
    let validation = validate(draft: draft)

    guard validation.errors.isEmpty else {
      throw WorkspaceSnapshotBuildError(message: validation.errors.joined(separator: " "))
    }

    let normalized = normalizedDraft(draft)
    let skill = Skill(
      id: normalized.id,
      version: "1.0",
      name: normalized.name,
      description: normalized.description,
      providedBy: normalized.providedBy,
      risk: Skill.Risk(
        level: normalized.riskLevel,
        requiresHumanReview: normalized.requiresHumanReview,
        notes: normalized.riskNotes
      ),
      notes: normalized.notes
    )

    return try WorkspaceAuthoringJSON.encode(skill)
  }

  private func normalizedDraft(_ draft: WorkspaceSkillDraft) -> WorkspaceSkillDraft {
    WorkspaceSkillDraft(
      id: WorkspaceEntityIDPolicy.normalized(draft.id),
      name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
      description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
      providedBy: normalizedTextItems(draft.providedBy),
      riskLevel: draft.riskLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
      requiresHumanReview: draft.requiresHumanReview,
      riskNotes: normalizedTextItems(draft.riskNotes),
      notes: normalizedTextItems(draft.notes)
    )
  }
}

public struct WorkspaceReferenceDraft: Equatable, Sendable {
  public var id: String
  public var name: String
  public var summary: String
  public var pathGlobs: [String]
  public var referenceTags: [String]

  public init(
    id: String,
    name: String,
    summary: String,
    pathGlobs: [String],
    referenceTags: [String]
  ) {
    self.id = id
    self.name = name
    self.summary = summary
    self.pathGlobs = pathGlobs
    self.referenceTags = referenceTags
  }
}

public struct WorkspaceReferenceDraftBuilder: Sendable {
  public init() {}

  public func defaultDraft(template: WorkspaceCreationTemplate) -> WorkspaceReferenceDraft {
    WorkspaceReferenceDraft(id: "", name: "", summary: "", pathGlobs: [], referenceTags: [])
  }

  public func suggestedID(from name: String) -> String {
    WorkspaceEntityIDSuggester.suggestedID(from: name)
  }

  public func validate(
    draft: WorkspaceReferenceDraft
  ) -> WorkspaceCreateValidation {
    let normalized = normalizedDraft(draft)
    var errors: [String] = []

    validateCoreFields(
      id: normalized.id,
      displayName: "Reference",
      name: normalized.name,
      summary: normalized.summary,
      errors: &errors
    )

    // The entity validator rejects a reference with no trigger rules, so refuse
    // to build one here too — keep buildRawJSON from emitting JSON that
    // `personakit validate` would immediately fail.
    if normalized.pathGlobs.isEmpty, normalized.referenceTags.isEmpty {
      errors.append("Reference must declare at least one path glob or reference tag.")
    }

    return WorkspaceCreateValidation(errors: errors, warnings: [])
  }

  public func buildRawJSON(
    draft: WorkspaceReferenceDraft
  ) throws -> String {
    let validation = validate(draft: draft)

    guard validation.errors.isEmpty else {
      throw WorkspaceSnapshotBuildError(message: validation.errors.joined(separator: " "))
    }

    let normalized = normalizedDraft(draft)
    let triggerRules: [ReferenceTriggerRule]
    if normalized.pathGlobs.isEmpty, normalized.referenceTags.isEmpty {
      triggerRules = []
    } else {
      triggerRules = [
        ReferenceTriggerRule(
          pathGlobs: normalized.pathGlobs.isEmpty ? nil : normalized.pathGlobs,
          referenceTags: normalized.referenceTags.isEmpty ? nil : normalized.referenceTags
        )
      ]
    }
    let reference = Reference(
      id: normalized.id,
      version: "1.0",
      name: normalized.name,
      summary: normalized.summary,
      triggerRules: triggerRules
    )

    return try WorkspaceAuthoringJSON.encode(reference)
  }

  private func normalizedDraft(_ draft: WorkspaceReferenceDraft) -> WorkspaceReferenceDraft {
    WorkspaceReferenceDraft(
      id: WorkspaceEntityIDPolicy.normalized(draft.id),
      name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
      summary: draft.summary.trimmingCharacters(in: .whitespacesAndNewlines),
      pathGlobs: normalizedTextItems(draft.pathGlobs),
      referenceTags: normalizedTextItems(draft.referenceTags)
    )
  }
}

public enum WorkspaceEssentialDraftBuilder {
  public static func suggestedID(from title: String) -> String {
    WorkspaceEntityIDSuggester.suggestedID(from: title)
  }

  public static func buildMarkdown(
    title: String,
    body: String?,
    template: WorkspaceCreationTemplate
  ) -> String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)

    let defaultBody: String
    switch template {
    case .starter:
      defaultBody = "TODO: add essential guidance."
    case .minimal:
      defaultBody = ""
    }

    var sections = ["# \(trimmedTitle)"]

    let finalBody = trimmedBody ?? defaultBody
    if !finalBody.isEmpty {
      sections.append(finalBody)
    }

    return sections.joined(separator: "\n\n") + "\n"
  }
}

public enum WorkspaceSessionDraftBuilder {
  public static func defaultDraft(template: WorkspaceCreationTemplate) -> WorkspaceSessionDraft {
    WorkspaceSessionDraft(
      id: "",
      personaId: "",
      directiveId: "",
      kitOverrides: []
    )
  }

  public static func suggestedID(
    personaID: String,
    directiveID: String
  ) -> String {
    let persona = WorkspaceEntityIDPolicy.normalized(personaID)
    let directive = WorkspaceEntityIDPolicy.normalized(directiveID)

    guard !persona.isEmpty, !directive.isEmpty else {
      return ""
    }

    return "\(persona)_\(directive)"
  }

  public static func validate(
    draft: WorkspaceSessionDraft,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>,
    validKitIDs: Set<String>
  ) -> WorkspaceCreateValidation {
    let normalized = normalizedDraft(draft)
    var errors: [String] = []

    if normalized.id.isEmpty {
      errors.append("Session id is required.")
    } else if !WorkspaceEntityIDPolicy.isValid(normalized.id) {
      errors.append(
        "Session id \"\(normalized.id)\" is not valid. Use letters, numbers, hyphen, underscore, or period."
      )
    }

    if !validPersonaIDs.contains(normalized.personaId) {
      errors.append("Persona id \"\(normalized.personaId)\" is not valid.")
    }

    if !validDirectiveIDs.contains(normalized.directiveId) {
      errors.append("Directive id \"\(normalized.directiveId)\" is not valid.")
    }

    for kitID in normalized.kitOverrides {
      if !validKitIDs.contains(kitID) {
        errors.append("Kit id \"\(kitID)\" is not valid.")
      }
    }

    return WorkspaceCreateValidation(errors: errors, warnings: [])
  }

  public static func buildRawJSON(
    draft: WorkspaceSessionDraft,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>,
    validKitIDs: Set<String>
  ) throws -> String {
    let validation = validate(
      draft: draft,
      validPersonaIDs: validPersonaIDs,
      validDirectiveIDs: validDirectiveIDs,
      validKitIDs: validKitIDs
    )

    guard validation.errors.isEmpty else {
      throw WorkspaceSnapshotBuildError(message: validation.errors.joined(separator: " "))
    }

    let normalized = normalizedDraft(draft)
    let session = SessionFile(
      id: normalized.id,
      personaId: normalized.personaId,
      directiveId: normalized.directiveId,
      kitOverrides: normalized.kitOverrides.isEmpty ? nil : normalized.kitOverrides
    )

    return try WorkspaceAuthoringJSON.encode(session)
  }

  private static func normalizedDraft(
    _ draft: WorkspaceSessionDraft
  ) -> WorkspaceSessionDraft {
    WorkspaceSessionDraft(
      id: WorkspaceEntityIDPolicy.normalized(draft.id),
      personaId: WorkspaceEntityIDPolicy.normalized(draft.personaId),
      directiveId: WorkspaceEntityIDPolicy.normalized(draft.directiveId),
      kitOverrides: normalizedIDs(draft.kitOverrides)
    )
  }
}

private func validateCoreFields(
  id: String,
  displayName: String,
  name: String,
  summary: String,
  errors: inout [String]
) {
  if id.isEmpty {
    errors.append("\(displayName) id is required.")
  } else if !WorkspaceEntityIDPolicy.isValid(id) {
    errors.append(
      "\(displayName) id \"\(id)\" is not valid. Use letters, numbers, hyphen, underscore, or period."
    )
  }

  if name.isEmpty {
    errors.append("\(displayName) name is required.")
  }

  if summary.isEmpty {
    errors.append("\(displayName) summary is required.")
  }
}

private func normalizedIDs(_ values: [String]) -> [String] {
  Array(
    Set(
      values.map {
        WorkspaceEntityIDPolicy.normalized($0)
      }
      .filter { !$0.isEmpty }
    )
  )
  .sorted()
}

private func normalizedTextItems(_ values: [String]) -> [String] {
  values.map {
    $0.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  .filter { !$0.isEmpty }
}
