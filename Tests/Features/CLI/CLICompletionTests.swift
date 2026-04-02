import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore
@testable import ContextMCP

struct CLICompletionTests {
  @Test
  func sessionCompletionUsesDiscoveredProjectScope() throws {
    let projectRoot = try makeTempDirectory().appendingPathComponent("Project")
    let personaKitRoot = projectRoot.appendingPathComponent(".personakit")
    try PersonaKitInitializer().run(destination: personaKitRoot.path)
    try writeCompletionSession(
      root: personaKitRoot,
      session: SessionFile(
        id: "sample-review-session",
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: nil
      )
    )

    let context = CLIContext(
      scopeRootResolver: ScopeRootResolver(startingURL: projectRoot),
      mcpServerRunner: MCPServerRunner()
    )

    let completions = CLIEnvironment.withContext(context) {
      CLICompletions.sessionIDs(
        arguments: ["personakit", "export", "--session", "sample"],
        index: 3,
        prefix: "sample"
      )
    }

    #expect(completions == ["sample-review-session"])
  }

  @Test
  func sessionCompletionHonorsExplicitRootOverride() throws {
    let tempRoot = try makeTempDirectory()
    let firstRoot = tempRoot.appendingPathComponent("First/.personakit")
    let secondRoot = tempRoot.appendingPathComponent("Second/.personakit")
    try PersonaKitInitializer().run(destination: firstRoot.path)
    try PersonaKitInitializer().run(destination: secondRoot.path)

    try writeCompletionSession(
      root: firstRoot,
      session: SessionFile(
        id: "first-session",
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: nil
      )
    )
    try writeCompletionSession(
      root: secondRoot,
      session: SessionFile(
        id: "second-session",
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: nil
      )
    )

    let context = CLIContext(
      scopeRootResolver: ScopeRootResolver(startingURL: tempRoot),
      mcpServerRunner: MCPServerRunner()
    )

    let completions = CLIEnvironment.withContext(context) {
      CLICompletions.sessionIDs(
        arguments: [
          "personakit",
          "export",
          "--root",
          secondRoot.path,
          "--session",
          "sec",
        ],
        index: 5,
        prefix: "sec"
      )
    }

    #expect(completions == ["second-session"])
  }
}

private func writeCompletionSession(root: URL, session: SessionFile) throws {
  let sessionsURL = root.appendingPathComponent("Sessions", isDirectory: true)
  try FileManager.default.createDirectory(
    at: sessionsURL,
    withIntermediateDirectories: true
  )

  let fileURL = sessionsURL.appendingPathComponent("\(session.id).session.json")
  let data = try JSONEncoder().encode(session)
  try data.write(to: fileURL)
}
