/// Action routing helpers for ``AppStore.send(_:)``.
extension AppStore {
  /// Handles lifecycle and app command actions.
  func handleLifecycle(_ action: Action) -> Bool {
    switch action {
    case .task, .reloadAll:
      reloadAll()
      return true
    case .importPack:
      importPack()
      return true
    case .revealStorageRoot:
      revealStorageRoot()
      return true
    case .revealSelectedPack:
      revealSelectedPack()
      return true
    case .removeSelectedPack:
      removeSelectedPack()
      return true
    case .copyPromptToClipboard:
      copyPromptToClipboard()
      return true
    default:
      return false
    }
  }
}
