import Foundation
import PersonaPadCore

extension AppStore {
  var canRevealSelectedPack: Bool {
    guard let location = selectedPackLocation else { return false }
    return location.isDirectoryPack
  }

  var canRemoveSelectedPack: Bool {
    guard let location = selectedPackLocation,
      let personaID = state.selectedPersonaID,
      let source = state.personaSourcesByID[personaID]
    else { return false }
    return location.isDirectoryPack && source.kind == .user
  }

  func importPack() {
    guard let selection = appClient.selectPackURL() else { return }

    let paths: PersonaPadStoragePaths
    do {
      paths = try ensureStorageDirectories()
    } catch {
      appClient.presentError(
        "Import Failed",
        "Could not create PersonaPad storage folders. Fix: check permissions for Application Support."
      )
      return
    }

    let planResult = PersonaPackImportPlan.plan(from: selection)
    switch planResult {
    case .failure(let error):
      appClient.presentError("Import Failed", error.userFacingMessage)
      return
    case .success(let plan):
      let existingNames = existingPackDirectoryNames(in: paths.packs)
      let preferred = PersonaPadStorage.preferredPackDirectoryName(for: plan.pack)
      let folderName = PersonaPadStorage.uniquePackDirectoryName(
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

  func revealStorageRoot() {
    let paths: PersonaPadStoragePaths
    do {
      paths = try ensureStorageDirectories()
    } catch {
      appClient.presentError(
        "Reveal Failed",
        "Could not create PersonaPad storage folders. Fix: check permissions for Application Support."
      )
      return
    }
    appClient.openURL(paths.root)
  }

  func revealSelectedPack() {
    guard let location = selectedPackLocation, location.isDirectoryPack else {
      appClient.presentError("Reveal Failed", "Selected pack is not a user pack folder.")
      return
    }
    appClient.openURL(location.packRoot)
  }

  func removeSelectedPack() {
    guard let location = selectedPackLocation,
      let personaID = state.selectedPersonaID,
      let source = state.personaSourcesByID[personaID],
      location.isDirectoryPack,
      source.kind == .user
    else {
      appClient.presentError(
        "Remove Failed", "Only user packs stored in PersonaPad can be removed.")
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

  func copyPromptToClipboard() {
    appClient.copyToClipboard(state.promptPreview)
  }

  private var selectedPackLocation: PackLocation? {
    guard let personaID = state.selectedPersonaID else { return nil }
    return state.packLocationsByPersonaID[personaID]
  }

  private func ensureStorageDirectories() throws -> PersonaPadStoragePaths {
    let paths = PersonaPadStoragePaths.standard(homeDirectory: fileClient.homeDirectory())
    try fileClient.createDirectory(paths.packs, true)
    try fileClient.createDirectory(paths.state, true)
    return paths
  }

  private func existingPackDirectoryNames(in packsRoot: URL) -> Set<String> {
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
