import Foundation
import Synchronization
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLICreateCommandTests {
  @Test
  func createPersonaDryRunJSONEmitsRenderedContentWithoutWriting() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "persona",
        "--root",
        root.path,
        "--name",
        "Session Planner",
        "--summary",
        "Plans milestone slices honestly.",
        "--dry-run",
        "--json",
      ])
    }

    #expect(status == 0)

    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let result = try #require(object["result"] as? [String: Any])

    #expect(result["entityType"] as? String == "persona")
    #expect(result["entityID"] as? String == "session-planner")
    #expect(result["dryRun"] as? Bool == true)

    let renderedContent = try #require(object["renderedContent"] as? String)
    #expect(renderedContent.contains("\"id\" : \"session-planner\""))
    #expect(
      !FileManager.default.fileExists(
        atPath: root.appendingPathComponent("Packs/personas/session-planner.persona.json").path
      )
    )
  }

  @Test
  func createPersonaInteractivePromptsAndWritesFile() throws {
    let root = try makeWritableFixtureRoot()
    let interactiveIO = makeInteractiveIO(
      lines: [
        "Session Planner",
        "",
        "Plans milestone slices honestly.",
        "",
        "",
        "",
        "",
        "",
        "",
        "y",
      ]
    )

    var status: Int32 = 0
    _ = captureStdout {
      status = PersonaKitCLI(interactiveIO: interactiveIO).run(arguments: [
        "personakit",
        "create",
        "persona",
        "--root",
        root.path,
      ])
    }

    #expect(status == 0)

    let personaURL = root.appendingPathComponent("Packs/personas/session-planner.persona.json")
    let rawJSON = try String(contentsOf: personaURL, encoding: .utf8)
    let data = try #require(rawJSON.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["id"] as? String == "session-planner")
    #expect(object["name"] as? String == "Session Planner")
    #expect(object["summary"] as? String == "Plans milestone slices honestly.")
  }

  @Test
  func createSessionRejectsUnknownPersona() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "session",
        "--root",
        root.path,
        "--persona",
        "missing-persona",
        "--directive",
        "apply-style",
        "--dry-run",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Persona id \"missing-persona\" is not valid."))
  }

  @Test
  func createEssentialReadsBodyFromStdin() throws {
    let root = try makeWritableFixtureRoot()
    let interactiveIO = makeInteractiveIO(
      lines: [],
      isInteractive: false,
      stdin: "Keep milestone slices honest."
    )

    var status: Int32 = 0
    _ = captureStdout {
      status = PersonaKitCLI(interactiveIO: interactiveIO).run(arguments: [
        "personakit",
        "create",
        "essential",
        "--root",
        root.path,
        "--title",
        "Planning Guardrails",
        "--stdin-body",
      ])
    }

    #expect(status == 0)

    let essentialURL = root.appendingPathComponent("Packs/essentials/planning-guardrails.md")
    let markdown = try String(contentsOf: essentialURL, encoding: .utf8)

    #expect(markdown == "# Planning Guardrails\n\nKeep milestone slices honest.\n")
  }

  @Test
  func createSessionCanReferenceGlobalPersonaWhenWritingProjectRoot() throws {
    let tempDirectory = try makeTempDirectory()
    let projectContainer = tempDirectory.appendingPathComponent("Project")
    let projectRoot = projectContainer.appendingPathComponent(".personakit")
    let homeDirectory = tempDirectory.appendingPathComponent("Home")
    let globalRoot = homeDirectory.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: projectContainer, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: homeDirectory, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: fixtureKitRootURL(), to: projectRoot)
    try FileManager.default.copyItem(at: fixtureKitRootURL(), to: globalRoot)
    try FileManager.default.removeItem(
      at: projectRoot.appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
    )

    let cli = PersonaKitCLI(
      scopeRootResolver: ScopeRootResolver(
        startingURL: projectContainer,
        homeDirectory: homeDirectory
      )
    )

    var status: Int32 = 0
    let output = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "create",
        "session",
        "--root",
        projectRoot.path,
        "--persona",
        "senior-swiftui-engineer",
        "--directive",
        "apply-style",
        "--dry-run",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("Dry run for session \"senior-swiftui-engineer_apply-style\""))
  }

  @Test
  func createPersonaDryRunAllowsExistingDestination() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "persona",
        "--root",
        root.path,
        "--id",
        "senior-swiftui-engineer",
        "--name",
        "Senior SwiftUI Engineer",
        "--summary",
        "Pragmatic, accessibility-first, small diffs.",
        "--dry-run",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("Dry run for persona \"senior-swiftui-engineer\""))
    #expect(output.contains("\"id\" : \"senior-swiftui-engineer\""))
  }

  @Test
  func createKitBuiltInEssentialDoesNotWarnAsUnknown() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "kit",
        "--root",
        root.path,
        "--name",
        "Runtime Kit",
        "--summary",
        "Summary",
        "--essential",
        "persona-activation-contract",
        "--dry-run",
      ])
    }

    #expect(status == 0)
    #expect(!output.contains("Unknown essential ids"))
  }

  private func makeWritableFixtureRoot() throws -> URL {
    let tempDirectory = try makeTempDirectory()
    let root = tempDirectory.appendingPathComponent(".personakit")
    try FileManager.default.copyItem(at: fixtureKitRootURL(), to: root)
    return root
  }
}

private func makeInteractiveIO(
  lines: [String],
  isInteractive: Bool = true,
  stdin: String = ""
) -> CLIInteractiveIO {
  let lineState = InteractiveLineState(lines: lines)

  return CLIInteractiveIO(
    isInteractive: { isInteractive },
    readLine: {
      lineState.next()
    },
    readStdinToEnd: {
      stdin
    }
  )
}

private final class InteractiveLineState: Sendable {
  private let lines: Mutex<[String]>

  init(lines: [String]) {
    self.lines = Mutex(lines)
  }

  func next() -> String? {
    return lines.withLock { lines in
      guard !lines.isEmpty else {
        return nil
      }

      return lines.removeFirst()
    }
  }
}
