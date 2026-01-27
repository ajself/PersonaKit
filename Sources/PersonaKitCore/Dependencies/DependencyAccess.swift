import Dependencies

/// Dependency access helper for retrieving the current ``FileClient``.
struct FileClientProvider {
  @Dependency(\.fileClient)
  var fileClient
}
