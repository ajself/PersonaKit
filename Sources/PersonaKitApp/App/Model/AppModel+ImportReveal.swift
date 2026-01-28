import Dependencies
import Foundation
import PersonaKitCore

/// Pack import, reveal, and removal behaviors for ``AppModel``.
extension AppModel {
  /// Returns true when the selected pack is a directory-based user pack.
  var canRevealSelectedPack: Bool {
    guard let location = selectedPackLocation else { return false }
    return location.isDirectoryPack
  }

  /// Returns true when the selected pack can be removed from disk.
  var canRemoveSelectedPack: Bool {
    guard let location = selectedPackLocation,
      let personaID = composer.selectedPersonaID,
      let source = personaSourcesByID[personaID]
    else { return false }
    return location.isDirectoryPack && source.kind == .user
  }

  /// Imports a persona pack from disk into PersonaKit-managed storage.
  func importPack() {
    let appClient = DependencyValues.current.appClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.uuid) var uuid
    guard let selection = appClient.selectPackURL() else { return }

    let paths: PersonaKitStoragePaths
    do {
      paths = try ensureStorageDirectories(fileClient: fileClient)
    } catch {
      appClient.presentError(
        "Import Failed",
        "Could not create PersonaKit storage folders. Fix: check permissions for Application Support."
      )
      return
    }

    let planResult = PersonaPackImportPlan.plan(from: selection)
    switch planResult {
    case .failure(let error):
      appClient.presentError("Import Failed", error.userFacingMessage)
      return
    case .success(let plan):
      let existingNames = existingPackDirectoryNames(in: paths.packs, fileClient: fileClient)
      let preferred = PersonaKitStorage.preferredPackDirectoryName(for: plan.pack)
      let folderName = PersonaKitStorage.uniquePackDirectoryName(
        preferred: preferred, existing: existingNames)
      let destination = paths.packs.appendingPathComponent(folderName, isDirectory: true)
      let tempFolderName = ".import_tmp_\(uuid().uuidString)"
      let tempDestination = paths.packs.appendingPathComponent(tempFolderName, isDirectory: true)

      do {
        try fileClient.createDirectory(tempDestination, true)
        for file in plan.filesToCopy {
          guard let relativePath = plan.relativePath(for: file) else {
            throw ImportCopyFailure.outsideRoot
          }
          let target = tempDestination.appendingPathComponent(relativePath)
          let targetFolder = target.deletingLastPathComponent()
          try fileClient.createDirectory(targetFolder, true)
          try fileClient.copyItem(file, target)
        }
        try fileClient.moveItem(tempDestination, destination)
      } catch {
        try? fileClient.removeItem(tempDestination)
        if case ImportCopyFailure.outsideRoot = error {
          appClient.presentError(
            "Import Failed",
            "One or more files are outside the selected folder. Fix: ensure all pack files live under the pack folder."
          )
          return
        }
        appClient.presentError(
          "Import Failed",
          "Could not copy pack files. Fix: ensure the destination is writable. (\(error.localizedDescription))"
        )
        return
      }
    }

    reloadAll()
  }

  /// Reveals the PersonaKit storage root in Finder, creating it if needed.
  func revealStorageRoot() {
    let appClient = DependencyValues.current.appClient
    @Dependency(\.fileClient) var fileClient
    let paths: PersonaKitStoragePaths
    do {
      paths = try ensureStorageDirectories(fileClient: fileClient)
    } catch {
      appClient.presentError(
        "Reveal Failed",
        "Could not create PersonaKit storage folders. Fix: check permissions for Application Support."
      )
      return
    }
    appClient.openURL(paths.root)
  }

  /// Reveals the selected pack directory in Finder when applicable.
  func revealSelectedPack() {
    let appClient = DependencyValues.current.appClient
    guard let location = selectedPackLocation, location.isDirectoryPack else {
      appClient.presentError("Reveal Failed", "Selected pack is not a user pack folder.")
      return
    }
    appClient.openURL(location.packRoot)
  }

  /// Deletes the selected user pack directory after confirmation.
  func removeSelectedPack() {
    let appClient = DependencyValues.current.appClient
    @Dependency(\.fileClient) var fileClient
    guard let location = selectedPackLocation,
      let personaID = composer.selectedPersonaID,
      let source = personaSourcesByID[personaID],
      location.isDirectoryPack,
      source.kind == .user
    else {
      appClient.presentError(
        "Remove Failed", "Only user packs stored in PersonaKit can be removed.")
      return
    }

    guard appClient.confirmRemovePack() else { return }

    do {
      try fileClient.removeItem(location.packRoot)
      reloadAll()
    } catch {
      appClient.presentError(
        "Remove Failed",
        "Could not delete the pack folder. Fix: check permissions. (\(error.localizedDescription))"
      )
    }
  }

  /// Copies the composed prompt preview to the clipboard.
  func copyPromptToClipboard() {
    let appClient = DependencyValues.current.appClient
    appClient.copyToClipboard(preview.promptPreview)
  }

  private var selectedPackLocation: PackLocation? {
    guard let personaID = composer.selectedPersonaID else { return nil }
    return packLocationsByPersonaID[personaID]
  }

  private func ensureStorageDirectories(fileClient: FileClient) throws -> PersonaKitStoragePaths {
    let paths = PersonaKitStoragePaths.standard(homeDirectory: fileClient.homeDirectory())
    try fileClient.createDirectory(paths.packs, true)
    try fileClient.createDirectory(paths.state, true)
    return paths
  }

  private func existingPackDirectoryNames(in packsRoot: URL, fileClient: FileClient) -> Set<String> {
    guard let contents = try? fileClient.contentsOfDirectory(packsRoot, [.isDirectoryKey]) else {
      return []
    }
    return Set(
      contents.compactMap { url in
        let isDirectory = fileClient.isDirectory(url)
        return isDirectory ? url.lastPathComponent : nil
      })
  }

  private enum ImportCopyFailure: Error {
    case outsideRoot
  }
}
