import ContextWorkspaceCore
import Foundation

struct StudioLibraryPreviewState: Equatable, Sendable {
  let sectionTitle: String
  let id: String
  let displayName: String
  let scope: String
  let relativePath: String
  let workstreamLine: String?

  init(
    selection: SidebarItem,
    item: WorkspaceListItem,
    workspaceURL: URL?
  ) {
    sectionTitle = selection.singularTitle
    id = item.id
    displayName = item.displayName
    scope = item.sourceScope.displayName
    relativePath = Self.relativePath(
      fileURL: item.fileURL,
      workspaceURL: workspaceURL
    )

    if let workstreamId = item.workstreamId,
      let workstreamPhase = item.workstreamPhase
    {
      workstreamLine = "workstream: \(workstreamId) · phase: \(workstreamPhase)"
    } else {
      workstreamLine = nil
    }
  }

  var accessibilitySummary: String {
    var parts = [
      "\(sectionTitle) Preview",
      "id \(id)",
      "scope \(scope)",
      "path \(relativePath)",
    ]

    if displayName != id {
      parts.insert(displayName, at: 2)
    }

    if let workstreamLine {
      parts.append(workstreamLine)
    }

    return parts.joined(separator: ", ")
  }

  private static func relativePath(
    fileURL: URL,
    workspaceURL: URL?
  ) -> String {
    let filePath = fileURL.standardizedFileURL.path()

    guard let workspaceURL else {
      return filePath
    }

    let workspacePath = normalizedDirectoryPath(
      workspaceURL.standardizedFileURL.path()
    )
    let projectScopePath: String

    if workspaceURL.lastPathComponent == ".personakit" {
      projectScopePath = workspacePath
    } else {
      let scopedURL =
        workspaceURL
        .appendingPathComponent(".personakit")
        .standardizedFileURL

      projectScopePath = normalizedDirectoryPath(scopedURL.path())
    }

    if filePath == workspacePath {
      return "."
    }

    if filePath.hasPrefix(workspacePath + "/") {
      return String(filePath.dropFirst(workspacePath.count + 1))
    }

    if filePath.hasPrefix(projectScopePath + "/") {
      return ".personakit/" + String(filePath.dropFirst(projectScopePath.count + 1))
    }

    return filePath
  }

  private static func normalizedDirectoryPath(_ path: String) -> String {
    guard path.count > 1,
      path.hasSuffix("/")
    else {
      return path
    }

    return String(path.dropLast())
  }
}

extension SidebarItem {
  var singularTitle: String {
    switch self {
    case .sessions:
      return "Session"
    case .personas:
      return "Persona"
    case .directives:
      return "Directive"
    case .kits:
      return "Kit"
    case .essentials:
      return "Essential"
    case .references:
      return "Reference"
    case .skills:
      return "Skill"
    case .intents:
      return "Intent"
    case .relationshipMap:
      return "Relationship Map"
    case .validationResults:
      return "Validation Result"
    }
  }
}
