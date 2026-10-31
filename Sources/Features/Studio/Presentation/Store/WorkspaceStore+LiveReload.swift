import Foundation

/// Why the workspace is reloading.
enum WorkspaceReloadTrigger: Equatable {
  /// The user opened, saved, connected, or otherwise asked for fresh data.
  case explicit
  /// Files changed on disk outside Studio's own write paths (or through them; reloads are
  /// idempotent either way).
  case externalChange(Set<URL>)

  /// The files behind an external change, or `nil` for an explicit reload.
  var changedFileURLs: Set<URL>? {
    switch self {
    case .explicit:
      return nil
    case .externalChange(let changedFileURLs):
      return changedFileURLs
    }
  }

  /// One trigger covering both reloads: an explicit reload absorbs everything, and two
  /// external changes combine their files.
  func merged(with other: WorkspaceReloadTrigger) -> WorkspaceReloadTrigger {
    switch (self, other) {
    case (.externalChange(let changedFileURLs), .externalChange(let otherChangedFileURLs)):
      return .externalChange(changedFileURLs.union(otherChangedFileURLs))
    default:
      return .explicit
    }
  }
}

extension WorkspaceStore {
  /// Directories whose changes reload the open workspace: its `.personakit` tree and, when
  /// readable, the global library the snapshot also resolves from.
  var liveReloadDirectories: [URL] {
    guard let workspaceURL else {
      return []
    }

    let workspace = workspaceURL.standardizedFileURL
    let projectScopeURL =
      workspace.lastPathComponent == ".personakit"
      ? workspace
      : workspace.appendingPathComponent(".personakit", isDirectory: true)

    return [projectScopeURL] + [currentGlobalScopeURL].compactMap(\.self)
  }

  func reloadWorkspaceAfterExternalChange(changedFileURLs: Set<URL>) {
    guard workspaceURL != nil, !changedFileURLs.isEmpty else {
      return
    }

    loadWorkspace(trigger: .externalChange(changedFileURLs))
  }

  /// Starts (or keeps) watching the loaded workspace. Called after each successful load so
  /// the watch follows a newly created `.personakit` folder or a newly connected library.
  func watchLoadedWorkspace() {
    loadFeatureModel.startWatching(directories: liveReloadDirectories) { [weak self] changedFileURLs in
      self?.reloadWorkspaceAfterExternalChange(changedFileURLs: changedFileURLs)
    }
  }
}
