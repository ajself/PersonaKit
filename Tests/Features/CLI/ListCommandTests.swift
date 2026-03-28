import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct ListCommandTests {
  @Test
  func listPersonas() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let output = try ListCommand.list(root: root, entityType: .personas)

    #expect(output == "senior-swiftui-engineer — Senior SwiftUI Engineer")
  }

  @Test
  func listEssentials() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let output = try ListCommand.list(root: root, entityType: .essentials)

    let expected = [
      "environment",
      "non-goals",
      "swift-style-guide",
      "swiftui-style-guide",
      "tools-and-constraints",
    ].joined(separator: "\n")

    #expect(output == expected)
  }

  @Test
  func listReferences() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)

    let output = try ListCommand.list(root: root, entityType: .references)

    let expected = [
      "swift-style-guide-reference — Swift Style Guide Reference",
      "swiftui-style-guide-reference — SwiftUI Style Guide Reference",
    ].joined(separator: "\n")

    #expect(output == expected)
  }

  @Test
  func listSessions() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: root.path)
    try writeSession(
      root: root,
      session: SessionFile(
        id: "review-swiftui",
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: ["swift-style", "swiftui-style"]
      )
    )

    let output = try ListCommand.list(root: root, entityType: .sessions)

    #expect(
      output
        == "review-swiftui — senior-swiftui-engineer / apply-style [kits: swift-style, swiftui-style]"
    )
  }

  @Test
  func listSessionsPrefersProjectScopeForDuplicateIDs() throws {
    let tempRoot = try makeTempDirectory()
    let projectRoot = tempRoot.appendingPathComponent("Project/.personakit")
    let globalRoot = tempRoot.appendingPathComponent("Global/.personakit")

    try PersonaKitInitializer().run(destination: projectRoot.path)
    try PersonaKitInitializer().run(destination: globalRoot.path)

    try writeSession(
      root: globalRoot,
      session: SessionFile(
        id: "shared-review",
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: nil
      )
    )
    try writeSession(
      root: projectRoot,
      session: SessionFile(
        id: "shared-review",
        personaId: "senior-swiftui-engineer",
        directiveId: "review-implementation-prompts",
        kitOverrides: nil
      )
    )

    let scopes = ScopeSet(
      projectScopeURL: projectRoot,
      globalScopeURL: globalRoot
    )

    let output = try ListCommand.list(scopes: scopes, entityType: .sessions)

    #expect(output == "shared-review — senior-swiftui-engineer / review-implementation-prompts")
  }
}

private func writeSession(root: URL, session: SessionFile) throws {
  let sessionsURL = root.appendingPathComponent("Sessions", isDirectory: true)
  try FileManager.default.createDirectory(
    at: sessionsURL,
    withIntermediateDirectories: true
  )

  let fileURL = sessionsURL.appendingPathComponent("\(session.id).session.json")
  let data = try JSONEncoder().encode(session)
  try data.write(to: fileURL)
}
