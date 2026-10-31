import Foundation
import Testing

@testable import StudioFeatures

/// Which owners refresh after a file change. FSEvents may report a coalesced parent directory instead of the file,
/// so most cases below pass directories as well as exact file URLs.
struct WorkspaceFileChangeRelevanceTests {
  private let personaURL = URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/solo.persona.json")
  private let sessionURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json")

  @Test
  func affectsFileMatchesTheFileItsDirectoriesAndItsName() {
    let cases: [(changed: Set<URL>?, expected: Bool, label: String)] = [
      (nil, true, "an explicit reload"),
      ([], false, "no changes"),
      ([personaURL], true, "the file itself"),
      ([URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/other.persona.json")], false, "a sibling file"),
      ([URL(fileURLWithPath: "/Global/.personakit/Packs/personas/solo.persona.json")], true, "the same name elsewhere"),
      ([URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas")], true, "the parent directory"),
      ([URL(fileURLWithPath: "/Workspace/.personakit")], true, "an ancestor directory"),
      ([URL(fileURLWithPath: "/Workspace/.personakit/Pack")], false, "a directory that only prefixes the path"),
      ([URL(fileURLWithPath: "/Workspace/.personakit/Packs/kits")], false, "a sibling directory"),
      ([URL(fileURLWithPath: "/Workspace/.personakit/Packs/kits/../personas")], true, "an unstandardized parent"),
    ]

    for (changed, expected, label) in cases {
      #expect(
        WorkspaceFileChangeRelevance.affectsFile(personaURL, changedFileURLs: changed) == expected,
        "\(label)"
      )
    }
  }

  @Test
  func affectsSessionIgnoresOnlyOtherSessionsFiles() {
    let otherSessionURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-b.session.json")
    let cases: [(changed: Set<URL>?, expected: Bool, label: String)] = [
      (nil, true, "an explicit reload"),
      ([], false, "no changes"),
      ([sessionURL], true, "its own session file"),
      ([otherSessionURL], false, "another session's file"),
      ([URL(fileURLWithPath: "/Global/.personakit/Sessions/session-a.session.json")], true, "its name elsewhere"),
      ([personaURL], true, "a library file it may resolve from"),
      ([otherSessionURL, personaURL], true, "another session's file and a library file"),
      ([URL(fileURLWithPath: "/Workspace/.personakit/Sessions")], true, "the sessions directory"),
    ]

    for (changed, expected, label) in cases {
      #expect(
        WorkspaceFileChangeRelevance.affectsSession(fileURL: sessionURL, changedFileURLs: changed) == expected,
        "\(label)"
      )
    }
  }

  @Test
  func meaningfulChangesDropsFinderMetadata() {
    let finderMetadataURL = URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/.DS_Store")

    #expect(
      WorkspaceFileChangeRelevance.meaningfulChanges([personaURL, finderMetadataURL, personaURL]) == [personaURL]
    )
    #expect(WorkspaceFileChangeRelevance.meaningfulChanges([finderMetadataURL]).isEmpty)
  }

  @Test
  func affectsFileResolvesSymlinks() throws {
    let rootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realDirectoryURL = rootURL.appendingPathComponent("real", isDirectory: true)
    let linkURL = rootURL.appendingPathComponent("link", isDirectory: true)
    try FileManager.default.createDirectory(at: realDirectoryURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: rootURL) }
    try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: realDirectoryURL)

    // Only an existing path resolves; the detail item's file exists while it is shown.
    let fileURL = realDirectoryURL.appendingPathComponent("solo.persona.json")
    try Data("{}".utf8).write(to: fileURL)

    #expect(WorkspaceFileChangeRelevance.affectsFile(fileURL, changedFileURLs: [linkURL]))
    #expect(
      WorkspaceFileChangeRelevance.affectsFile(
        linkURL.appendingPathComponent("solo.persona.json"),
        changedFileURLs: [realDirectoryURL]
      )
    )
  }
}
