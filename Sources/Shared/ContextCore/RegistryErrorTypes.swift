import Foundation

/// Entity categories loaded into the in-memory registry.
public enum RegistryEntityType: String, Sendable {
  case packsRoot = "packs"
  case persona
  case kit
  case directive
  case intentTemplate
  case skill

  /// Stable sort priority used for deterministic error output.
  public var sortOrder: Int {
    switch self {
    case .packsRoot:
      return 0
    case .persona:
      return 1
    case .kit:
      return 2
    case .directive:
      return 3
    case .intentTemplate:
      return 4
    case .skill:
      return 5
    }
  }
}

/// Structured error produced while loading registry entities from disk.
public struct RegistryError: Error, Equatable, Sendable {
  public let relativePath: String?
  public let entityType: RegistryEntityType
  public let id: String?
  public let message: String

  public init(
    relativePath: String?,
    entityType: RegistryEntityType,
    id: String?,
    message: String
  ) {
    self.relativePath = relativePath
    self.entityType = entityType
    self.id = id
    self.message = message
  }
}

/// Aggregate registry loading error with deterministic ordering.
public struct RegistryLoadError: Error, Equatable, Sendable {
  public let errors: [RegistryError]

  /// Creates a load error and sorts contained errors for stable output.
  public init(errors: [RegistryError]) {
    self.errors = RegistryLoadError.sort(errors: errors)
  }

  private static func sort(errors: [RegistryError]) -> [RegistryError] {
    return errors.sorted { lhs, rhs in
      if lhs.entityType.sortOrder != rhs.entityType.sortOrder {
        return lhs.entityType.sortOrder < rhs.entityType.sortOrder
      }

      let lhsId = lhs.id ?? ""
      let rhsId = rhs.id ?? ""

      if lhsId != rhsId {
        return lhsId < rhsId
      }

      let lhsPath = lhs.relativePath ?? ""
      let rhsPath = rhs.relativePath ?? ""

      if lhsPath != rhsPath {
        return lhsPath < rhsPath
      }

      return lhs.message < rhs.message
    }
  }
}
