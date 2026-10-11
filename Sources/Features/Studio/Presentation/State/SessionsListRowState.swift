import ContextWorkspaceCore

/// Display text and search matching for Sessions list rows.
enum SessionsListRowState {
  /// "Persona name · Directive title", falling back to ids for unresolved references.
  static func subtitle(
    for session: WorkspaceSessionListItem,
    in snapshot: WorkspaceSnapshot
  ) -> String {
    let personaName = displayName(for: session.personaId, in: snapshot.personas)
    let directiveName = displayName(for: session.directiveId, in: snapshot.directives)

    return "\(personaName) · \(directiveName)"
  }

  /// Matches the session id, persona and directive ids, and their display names.
  static func matches(
    _ session: WorkspaceSessionListItem,
    searchText: String,
    in snapshot: WorkspaceSnapshot
  ) -> Bool {
    let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalizedSearch.isEmpty else {
      return true
    }

    return [
      session.id,
      session.personaId,
      session.directiveId,
      subtitle(for: session, in: snapshot),
    ]
    .contains { $0.localizedCaseInsensitiveContains(normalizedSearch) }
  }

  static func filteredSessions(
    _ sessions: [WorkspaceSessionListItem],
    searchText: String,
    in snapshot: WorkspaceSnapshot
  ) -> [WorkspaceSessionListItem] {
    sessions.filter { matches($0, searchText: searchText, in: snapshot) }
  }

  private static func displayName(
    for id: String,
    in items: [WorkspaceListItem]
  ) -> String {
    items.first { $0.id == id }?.displayName ?? id
  }
}
