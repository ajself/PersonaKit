import ContextCore
import ContextWorkspaceCore
import Foundation

/// Package-scoped helpers for snapshot item lookup and diagnostics file resolution.
package enum WorkspaceSnapshotLookup {
  package static func essentialItem(
    snapshot: WorkspaceSnapshot,
    itemID: String
  ) -> WorkspaceListItem? {
    snapshot.essentials.first { item in
      item.id == itemID
    }
  }

  package static func projectEssentialItem(
    snapshot: WorkspaceSnapshot,
    itemID: String
  ) -> WorkspaceListItem? {
    snapshot.essentials.first { item in
      item.id == itemID && item.sourceScope == .project
    }
  }

  package static func libraryItem(
    snapshot: WorkspaceSnapshot,
    itemID: String,
    entityType: WorkspaceLibraryEntityType
  ) -> WorkspaceListItem? {
    libraryItems(snapshot: snapshot, entityType: entityType).first { item in
      item.id == itemID
    }
  }

  package static func projectLibraryItem(
    snapshot: WorkspaceSnapshot,
    itemID: String,
    entityType: WorkspaceLibraryEntityType
  ) -> WorkspaceListItem? {
    libraryItems(snapshot: snapshot, entityType: entityType).first { item in
      item.id == itemID && item.sourceScope == .project
    }
  }

  package static func libraryItems(
    snapshot: WorkspaceSnapshot,
    entityType: WorkspaceLibraryEntityType
  ) -> [WorkspaceListItem] {
    switch entityType {
    case .persona:
      return snapshot.personas
    case .directive:
      return snapshot.directives
    case .kit:
      return snapshot.kits
    case .skill:
      return snapshot.skills
    case .intent:
      return snapshot.intents
    }
  }

  package static func resolveValidationIssueFileURL(
    _ filePath: String,
    workspaceURL: URL?,
    snapshot: WorkspaceSnapshot
  ) -> URL? {
    let normalizedPath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalizedPath.isEmpty else {
      return nil
    }

    if normalizedPath.hasPrefix("/") {
      return URL(fileURLWithPath: normalizedPath).standardizedFileURL
    }

    let matchingSnapshotFileURLs = snapshotFileURLs(snapshot: snapshot).filter { fileURL in
      fileURL.path().hasSuffix("/\(normalizedPath)")
        || fileURL.path() == normalizedPath
    }

    if matchingSnapshotFileURLs.count == 1 {
      return matchingSnapshotFileURLs[0]
    }

    guard let workspaceURL else {
      return matchingSnapshotFileURLs.first
    }

    let workspace = workspaceURL.standardizedFileURL
    let projectScopeURL: URL

    if workspace.lastPathComponent == ".personakit" {
      projectScopeURL = workspace
    } else {
      projectScopeURL = workspace.appendingPathComponent(".personakit")
    }

    let candidates: [URL] = [
      workspace.appendingPathComponent(normalizedPath),
      projectScopeURL.appendingPathComponent(normalizedPath),
    ]
    .map(\.standardizedFileURL)

    if let existingCandidate = candidates.first(where: { candidate in
      FileManager.default.fileExists(atPath: candidate.path())
    }) {
      return existingCandidate
    }

    return matchingSnapshotFileURLs.first
  }

  private static func snapshotFileURLs(
    snapshot: WorkspaceSnapshot
  ) -> [URL] {
    var allItems: [WorkspaceListItem] = []
    allItems.append(contentsOf: snapshot.personas)
    allItems.append(contentsOf: snapshot.directives)
    allItems.append(contentsOf: snapshot.kits)
    allItems.append(contentsOf: snapshot.skills)
    allItems.append(contentsOf: snapshot.intents)
    allItems.append(contentsOf: snapshot.essentials)

    let libraryFileURLs = allItems.map { item in
      item.fileURL.standardizedFileURL
    }
    let sessionFileURLs = snapshot.sessions.map { item in
      item.fileURL.standardizedFileURL
    }

    return libraryFileURLs + sessionFileURLs
  }
}
