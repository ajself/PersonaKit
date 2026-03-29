import ContextCore
import ContextWorkspaceCore
import Foundation

/// Minimal two-array form metadata for a PersonaKit library entity type.
public struct WorkspaceLibraryEntityFormDescriptor: Sendable {
  public let primaryFieldKey: String
  public let primaryFieldLabel: String
  public let firstArrayKey: String
  public let firstArrayLabel: String
  public let secondArrayKey: String
  public let secondArrayLabel: String

  public init(
    primaryFieldKey: String,
    primaryFieldLabel: String,
    firstArrayKey: String,
    firstArrayLabel: String,
    secondArrayKey: String,
    secondArrayLabel: String
  ) {
    self.primaryFieldKey = primaryFieldKey
    self.primaryFieldLabel = primaryFieldLabel
    self.firstArrayKey = firstArrayKey
    self.firstArrayLabel = firstArrayLabel
    self.secondArrayKey = secondArrayKey
    self.secondArrayLabel = secondArrayLabel
  }
}

extension WorkspaceLibraryEntityType {
  public var supportsMinimalForm: Bool {
    self != .reference
  }

  var minimalFormDescriptor: WorkspaceLibraryEntityFormDescriptor {
    switch self {
    case .persona:
      return WorkspaceLibraryEntityFormDescriptor(
        primaryFieldKey: "name",
        primaryFieldLabel: "Name",
        firstArrayKey: "defaultKitIds",
        firstArrayLabel: "Default Kit IDs",
        secondArrayKey: "allowedSkillIds",
        secondArrayLabel: "Allowed Skill IDs"
      )
    case .directive:
      return WorkspaceLibraryEntityFormDescriptor(
        primaryFieldKey: "title",
        primaryFieldLabel: "Title",
        firstArrayKey: "requiresIntentTemplateIds",
        firstArrayLabel: "Required Intent Template IDs",
        secondArrayKey: "requiresSkillIds",
        secondArrayLabel: "Required Skill IDs"
      )
    case .kit:
      return WorkspaceLibraryEntityFormDescriptor(
        primaryFieldKey: "name",
        primaryFieldLabel: "Name",
        firstArrayKey: "essentialIds",
        firstArrayLabel: "Essential IDs",
        secondArrayKey: "skillIds",
        secondArrayLabel: "Skill IDs"
      )
    case .intent:
      return WorkspaceLibraryEntityFormDescriptor(
        primaryFieldKey: "name",
        primaryFieldLabel: "Name",
        firstArrayKey: "includesEssentialIds",
        firstArrayLabel: "Included Essential IDs",
        secondArrayKey: "requiresSkillIds",
        secondArrayLabel: "Required Skill IDs"
      )
    case .reference:
      preconditionFailure("Reference entities use raw JSON editing only.")
    case .skill:
      return WorkspaceLibraryEntityFormDescriptor(
        primaryFieldKey: "name",
        primaryFieldLabel: "Name",
        firstArrayKey: "providedBy",
        firstArrayLabel: "Provided By",
        secondArrayKey: "notes",
        secondArrayLabel: "Notes"
      )
    }
  }
}

/// Editable minimal form values for supported PersonaKit library entities.
public struct WorkspaceLibraryEntityFormState: Equatable, Sendable {
  public var id: String
  public var primaryText: String
  public var firstArrayLines: String
  public var secondArrayLines: String

  public init(
    id: String,
    primaryText: String,
    firstArrayLines: String,
    secondArrayLines: String
  ) {
    self.id = id
    self.primaryText = primaryText
    self.firstArrayLines = firstArrayLines
    self.secondArrayLines = secondArrayLines
  }

  public static let empty = WorkspaceLibraryEntityFormState(
    id: "",
    primaryText: "",
    firstArrayLines: "",
    secondArrayLines: ""
  )
}

/// Errors emitted when synchronizing between minimal form and raw JSON.
public enum WorkspaceLibraryEntityFormAdapterError: LocalizedError {
  case invalidJSON(String)
  case rootObjectRequired
  case jsonEncodingFailed

  public var errorDescription: String? {
    switch self {
    case .invalidJSON(let description):
      return "Form editing requires valid JSON: \(description)"
    case .rootObjectRequired:
      return "Form editing requires a JSON object at the root."
    case .jsonEncodingFailed:
      return "Failed to encode updated JSON."
    }
  }
}

/// Converts between raw JSON text and the Studio minimal library form.
public struct WorkspaceLibraryEntityFormAdapter: Sendable {
  public let descriptor: WorkspaceLibraryEntityFormDescriptor

  public init(entityType: WorkspaceLibraryEntityType) {
    descriptor = entityType.minimalFormDescriptor
  }

  public func parseFormState(from rawJSON: String) throws -> WorkspaceLibraryEntityFormState {
    let object = try parseJSONObject(rawJSON)

    return WorkspaceLibraryEntityFormState(
      id: stringValue(forKey: "id", in: object),
      primaryText: stringValue(forKey: descriptor.primaryFieldKey, in: object),
      firstArrayLines: stringArrayValue(forKey: descriptor.firstArrayKey, in: object).joined(
        separator: "\n"
      ),
      secondArrayLines: stringArrayValue(forKey: descriptor.secondArrayKey, in: object).joined(
        separator: "\n"
      )
    )
  }

  public func applyFormState(
    _ formState: WorkspaceLibraryEntityFormState,
    to rawJSON: String
  ) throws -> String {
    var object = try parseJSONObject(rawJSON)

    object["id"] = formState.id
    object[descriptor.primaryFieldKey] = formState.primaryText
    object[descriptor.firstArrayKey] = normalizedStringLines(formState.firstArrayLines)
    object[descriptor.secondArrayKey] = normalizedStringLines(formState.secondArrayLines)

    return try serializeJSONObject(object)
  }

  private func parseJSONObject(_ rawJSON: String) throws -> [String: Any] {
    let data = Data(rawJSON.utf8)

    do {
      let jsonObject = try JSONSerialization.jsonObject(with: data)

      guard let object = jsonObject as? [String: Any] else {
        throw WorkspaceLibraryEntityFormAdapterError.rootObjectRequired
      }

      return object
    } catch let error as WorkspaceLibraryEntityFormAdapterError {
      throw error
    } catch {
      throw WorkspaceLibraryEntityFormAdapterError.invalidJSON(error.localizedDescription)
    }
  }

  private func serializeJSONObject(_ object: [String: Any]) throws -> String {
    let data: Data

    do {
      data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys]
      )
    } catch {
      throw WorkspaceLibraryEntityFormAdapterError.invalidJSON(error.localizedDescription)
    }

    guard var serialized = String(data: data, encoding: .utf8) else {
      throw WorkspaceLibraryEntityFormAdapterError.jsonEncodingFailed
    }

    if !serialized.hasSuffix("\n") {
      serialized.append("\n")
    }

    return serialized
  }

  private func stringValue(
    forKey key: String,
    in object: [String: Any]
  ) -> String {
    object[key] as? String ?? ""
  }

  private func stringArrayValue(
    forKey key: String,
    in object: [String: Any]
  ) -> [String] {
    guard let values = object[key] as? [Any] else {
      return []
    }

    return values.compactMap { $0 as? String }
  }

  private func normalizedStringLines(_ input: String) -> [String] {
    input
      .split(whereSeparator: \.isNewline)
      .map { line in
        line.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      .filter { !$0.isEmpty }
  }
}
