import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

enum WorkspaceLibraryCreateSupport {
  static func starterRawJSON(
    entityType: WorkspaceLibraryEntityType
  ) throws -> String {
    switch entityType {
    case .persona:
      return try WorkspaceAuthoringJSON.encode(
        Persona(
          id: "",
          version: "1.0",
          name: "",
          summary: "",
          responsibilities: [],
          values: [],
          nonGoals: [],
          defaultKitIds: [],
          allowedSkillIds: [],
          forbiddenSkillIds: []
        )
      )
    case .directive:
      return try WorkspaceAuthoringJSON.encode(
        Directive(
          id: "",
          version: "1.0",
          title: "",
          goal: "",
          steps: [Directive.Step(text: "TODO: add directive step.", requiresReview: nil)],
          acceptanceCriteria: ["TODO: add acceptance criteria."],
          verification: [
            Directive.VerificationItem(kind: "manual", text: "TODO: review directive output.")
          ],
          requiresSkillIds: []
        )
      )
    case .kit:
      return try WorkspaceAuthoringJSON.encode(
        Kit(
          id: "",
          version: "1.0",
          name: "",
          summary: "",
          essentialIds: [],
          skillIds: nil
        )
      )
    case .reference:
      return try WorkspaceAuthoringJSON.encode(
        Reference(
          id: "",
          version: "1.0",
          name: "",
          summary: "",
          triggerRules: []
        )
      )
    case .skill:
      return try WorkspaceAuthoringJSON.encode(
        Skill(
          id: "",
          version: "1.0",
          name: "",
          description: "",
          providedBy: [],
          risk: Skill.Risk(
            level: "medium",
            requiresHumanReview: false,
            notes: []
          ),
          notes: []
        )
      )
    }
  }

  static func itemID(
    rawJSON: String
  ) throws -> String {
    let object = try jsonObject(rawJSON: rawJSON)

    guard let itemID = object["id"] as? String else {
      throw WorkspaceSnapshotBuildError(
        message: "JSON id field is required."
      )
    }

    return WorkspaceEntityIDPolicy.normalized(itemID)
  }

  static func validateNewLibraryItem(
    rawJSON: String,
    entityType: WorkspaceLibraryEntityType
  ) throws -> String {
    let object = try jsonObject(rawJSON: rawJSON)
    let itemID = try itemID(rawJSON: rawJSON)

    guard !itemID.isEmpty else {
      throw WorkspaceSnapshotBuildError(
        message: "\(entityType.displayName) id is required before saving."
      )
    }

    switch entityType {
    case .reference:
      try requireStringField(
        "name",
        label: "Reference name",
        in: object
      )
      try requireStringField(
        "summary",
        label: "Reference summary",
        in: object
      )
    default:
      let descriptor = WorkspaceLibraryEntityFormAdapter(entityType: entityType).descriptor
      try requireStringField(
        descriptor.primaryFieldKey,
        label: "\(entityType.displayName) \(descriptor.primaryFieldLabel.lowercased())",
        in: object
      )
      try requireStringField(
        descriptor.secondaryFieldKey,
        label: "\(entityType.displayName) \(descriptor.secondaryFieldLabel.lowercased())",
        in: object
      )
    }

    return itemID
  }

  static func essentialItemID(
    markdown: String
  ) -> String {
    for line in markdown.split(whereSeparator: \.isNewline) {
      let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

      guard trimmedLine.hasPrefix("#") else {
        continue
      }

      let title =
        trimmedLine
        .drop(while: { $0 == "#" })
        .trimmingCharacters(in: .whitespacesAndNewlines)

      return WorkspaceEssentialDraftBuilder.suggestedID(from: title)
    }

    return ""
  }

  static func placeholderLibraryFileURL(
    workspaceURL: URL,
    entityType: WorkspaceLibraryEntityType
  ) -> URL {
    workspaceURL
      .appendingPathComponent("__new__\(entityType.fileSuffix)")
      .standardizedFileURL
  }

  static func placeholderEssentialFileURL(
    workspaceURL: URL
  ) -> URL {
    workspaceURL
      .appendingPathComponent("__new__")
      .appendingPathExtension("md")
      .standardizedFileURL
  }

  private static func jsonObject(
    rawJSON: String
  ) throws -> [String: Any] {
    let data = Data(rawJSON.utf8)
    let jsonObject: Any

    do {
      jsonObject = try JSONSerialization.jsonObject(with: data)
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Invalid JSON: \(error.localizedDescription)"
      )
    }

    guard let object = jsonObject as? [String: Any] else {
      throw WorkspaceSnapshotBuildError(
        message: "JSON root must be an object."
      )
    }

    return object
  }

  private static func requireStringField(
    _ key: String,
    label: String,
    in object: [String: Any]
  ) throws {
    let value = (object[key] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard value?.isEmpty == false else {
      throw WorkspaceSnapshotBuildError(
        message: "\(label) is required before saving."
      )
    }
  }
}
