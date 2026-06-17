import ContextCore
import Foundation

/// Shared persona-authoring helpers for normalization, validation, and serialization.
public struct WorkspacePersonaDraftBuilder: Sendable {
  public init() {}

  /// Returns the default empty persona draft.
  public func defaultDraft() -> WorkspacePersonaDraft {
    .empty
  }

  /// Suggests an id from a human-readable persona name.
  public func suggestedID(from name: String) -> String {
    WorkspaceEntityIDSuggester.suggestedID(from: name)
  }

  /// Returns a normalized draft suitable for deterministic serialization.
  public func normalizedDraft(_ draft: WorkspacePersonaDraft) -> WorkspacePersonaDraft {
    WorkspacePersonaDraft(
      id: WorkspaceEntityIDPolicy.normalized(draft.id),
      name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
      summary: draft.summary.trimmingCharacters(in: .whitespacesAndNewlines),
      responsibilities: normalizedTextItems(draft.responsibilities),
      values: normalizedTextItems(draft.values),
      nonGoals: normalizedTextItems(draft.nonGoals),
      defaultKitIds: normalizedIDItems(draft.defaultKitIds),
      allowedSkillIds: normalizedIDItems(draft.allowedSkillIds),
      forbiddenSkillIds: normalizedIDItems(draft.forbiddenSkillIds),
      forbiddenCapabilities: Array(Set(normalizedTextItems(draft.forbiddenCapabilities))).sorted()
    )
  }

  /// Validates a persona draft and returns blocking errors and non-blocking warnings.
  public func validate(
    draft: WorkspacePersonaDraft,
    existingPersonaIDs: Set<String> = [],
    knownKitIDs: Set<String> = [],
    knownSkillIDs: Set<String> = []
  ) -> WorkspacePersonaDraftValidation {
    let normalized = normalizedDraft(draft)
    var errors: [String] = []
    var warnings: [String] = []

    if normalized.id.isEmpty {
      errors.append("Persona id is required.")
    } else if !WorkspaceEntityIDPolicy.isValid(normalized.id) {
      errors.append(
        "Persona id \"\(normalized.id)\" is not valid. Use letters, numbers, hyphen, underscore, or period."
      )
    }

    if !normalized.id.isEmpty, existingPersonaIDs.contains(normalized.id) {
      errors.append("Persona id \"\(normalized.id)\" already exists.")
    }

    if normalized.name.isEmpty {
      errors.append("Persona name is required.")
    }

    if normalized.summary.isEmpty {
      errors.append("Persona summary is required.")
    }

    let skillOverlap = Set(normalized.allowedSkillIds).intersection(normalized.forbiddenSkillIds).sorted()

    if !skillOverlap.isEmpty {
      errors.append(
        "Allowed and forbidden skills cannot overlap: \(skillOverlap.joined(separator: ", "))."
      )
    }

    let unknownKitIDs = normalized.defaultKitIds.filter { !knownKitIDs.contains($0) }

    if !unknownKitIDs.isEmpty {
      warnings.append("Unknown kit ids: \(unknownKitIDs.joined(separator: ", ")).")
    }

    let unknownAllowedSkillIDs = normalized.allowedSkillIds.filter { !knownSkillIDs.contains($0) }

    if !unknownAllowedSkillIDs.isEmpty {
      warnings.append("Unknown allowed skill ids: \(unknownAllowedSkillIDs.joined(separator: ", ")).")
    }

    let unknownForbiddenSkillIDs = normalized.forbiddenSkillIds.filter { !knownSkillIDs.contains($0) }

    if !unknownForbiddenSkillIDs.isEmpty {
      warnings.append(
        "Unknown forbidden skill ids: \(unknownForbiddenSkillIDs.joined(separator: ", "))."
      )
    }

    let unknownCapabilities = normalized.forbiddenCapabilities.filter { !SkillCapability.isKnown($0) }

    if !unknownCapabilities.isEmpty {
      errors.append(
        "Unknown forbidden capabilities: \(unknownCapabilities.joined(separator: ", ")). "
          + "Allowed: \(SkillCapability.vocabulary.joined(separator: ", "))."
      )
    }

    return WorkspacePersonaDraftValidation(
      errors: errors,
      warnings: warnings
    )
  }

  /// Serializes a validated persona draft into deterministic pretty-printed JSON.
  public func buildRawJSON(
    draft: WorkspacePersonaDraft,
    existingPersonaIDs: Set<String> = [],
    knownKitIDs: Set<String> = [],
    knownSkillIDs: Set<String> = []
  ) throws -> String {
    let validation = validate(
      draft: draft,
      existingPersonaIDs: existingPersonaIDs,
      knownKitIDs: knownKitIDs,
      knownSkillIDs: knownSkillIDs
    )

    guard validation.errors.isEmpty else {
      throw WorkspaceSnapshotBuildError(
        message: validation.errors.joined(separator: " ")
      )
    }

    let normalized = normalizedDraft(draft)
    let document = Persona(
      id: normalized.id,
      version: "1.0",
      name: normalized.name,
      summary: normalized.summary,
      responsibilities: normalized.responsibilities,
      values: normalized.values,
      nonGoals: normalized.nonGoals,
      defaultKitIds: normalized.defaultKitIds,
      allowedSkillIds: normalized.allowedSkillIds,
      forbiddenSkillIds: normalized.forbiddenSkillIds,
      forbiddenCapabilities: normalized.forbiddenCapabilities.isEmpty
        ? nil : normalized.forbiddenCapabilities
    )

    return try WorkspaceAuthoringJSON.encode(document)
  }

  private func normalizedTextItems(_ values: [String]) -> [String] {
    values.map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    .filter { !$0.isEmpty }
  }

  private func normalizedIDItems(_ values: [String]) -> [String] {
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
}
