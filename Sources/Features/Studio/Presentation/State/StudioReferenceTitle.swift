import ContextWorkspaceCore

/// Name-first text for a library item named by id, matching the library list's name-then-id rows.
enum StudioReferenceTitle {
  /// "Name (id)", or the id alone when the item has no distinct name.
  static func nameFirst(
    name: String,
    id: String
  ) -> String {
    name == id ? id : "\(name) (\(id))"
  }

  /// ``nameFirst(name:id:)`` for the item with `id`, or the bare id when it isn't loaded.
  static func nameFirst(
    id: String,
    in items: [WorkspaceListItem]
  ) -> String {
    nameFirst(name: displayName(for: id, in: items), id: id)
  }

  /// The loaded item's display name, or the id when it isn't loaded.
  static func displayName(
    for id: String,
    in items: [WorkspaceListItem]
  ) -> String {
    items.first { $0.id == id }?.displayName ?? id
  }
}
