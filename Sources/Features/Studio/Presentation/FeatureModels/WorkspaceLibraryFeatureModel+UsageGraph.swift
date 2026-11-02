import ContextWorkspaceCore
import Foundation

extension WorkspaceLibraryFeatureModel {
  /// Reloads the workspace dependency graph behind the inspector's "Used by" list. Called
  /// after every successful workspace reload; a failed load keeps the last graph on screen.
  func refreshUsageGraph(workspaceURL: URL) {
    let requestedWorkspaceURL = workspaceURL.standardizedFileURL

    usageGraphTask?.cancel()

    if usageGraphWorkspaceURL != requestedWorkspaceURL {
      usageGraph = nil
    }

    usageGraphWorkspaceURL = requestedWorkspaceURL
    usageGraphLoadErrorMessage = nil

    usageGraphTask = Task { [requestedWorkspaceURL] in
      let outcome: WorkspaceLoadOutcome<WorkspaceSessionMap>

      do {
        outcome = .loaded(
          try await operationRunner.loadWorkspaceRelationshipMap(workspaceURL: requestedWorkspaceURL)
        )
      } catch {
        outcome = .failed(error.localizedDescription)
      }

      guard !Task.isCancelled, usageGraphWorkspaceURL == requestedWorkspaceURL else {
        return
      }

      switch outcome {
      case .loaded(let graph):
        usageGraph = graph
      case .failed(let message):
        usageGraphLoadErrorMessage = usageGraph == nil ? message : nil
      }

      usageGraphTask = nil
    }
  }

  /// Cancels any graph load and forgets the graph when the workspace closes or changes.
  func clearUsageGraph() {
    usageGraphTask?.cancel()
    usageGraphTask = nil
    usageGraphWorkspaceURL = nil
    usageGraph = nil
    usageGraphLoadErrorMessage = nil
  }

  /// Sessions and library items that reference the given item, or `nil` before any graph
  /// has loaded for this workspace.
  func usedBy(
    kind: WorkspaceSessionMapNodeKind,
    id: String
  ) -> [WorkspaceSessionMapNode]? {
    guard let usageGraph else {
      return nil
    }

    return StudioLibraryUsageState.users(
      of: StudioLibraryUsageState.nodeKey(kind: kind, id: id),
      in: usageGraph
    )
  }
}
