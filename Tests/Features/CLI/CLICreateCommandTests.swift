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
  func createPersonaJSONFailurePreservesValidationMessage() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "persona",
        "--root",
        root.path,
        "--json",
      ])
    }

    #expect(status == 1)

    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let error = try #require(object["error"] as? String)

    #expect(error.contains("Missing required fields: --id/--name, --name, --summary."))
    #expect(!error.contains("ArgumentParser.ValidationError error"))
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
  func createGroundingSkillWritesJSONAndMarkdownBody() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    _ = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "skill",
        "--root",
        root.path,
        "--name",
        "Swift Style Guide",
        "--description",
        "Deeper Swift rationale.",
        "--path-glob",
        "**/*.swift",
        "--skill-tag",
        "swift",
      ])
    }

    #expect(status == 0)

    let jsonURL = root.appendingPathComponent("Packs/skills/swift-style-guide.skill.json")
    let bodyURL = root.appendingPathComponent("Packs/skills/swift-style-guide.md")
    #expect(FileManager.default.fileExists(atPath: bodyURL.path))

    let rawJSON = try String(contentsOf: jsonURL, encoding: .utf8)
    let data = try #require(rawJSON.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["id"] as? String == "swift-style-guide")
    let triggerRules = try #require(object["triggerRules"] as? [[String: Any]])
    #expect(triggerRules.first?["pathGlobs"] as? [String] == ["**/*.swift"])
    #expect(triggerRules.first?["skillTags"] as? [String] == ["swift"])
  }

  @Test
  func createSkillBodyWithoutTriggerFailsWithGuidance() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "skill",
        "--root",
        root.path,
        "--name",
        "Orphan Body",
        "--description",
        "Body with no trigger.",
        "--body",
        "# Never surfaced",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("--path-glob"))
    #expect(stderrOutput.contains("--skill-tag"))
    #expect(
      !FileManager.default.fileExists(
        atPath: root.appendingPathComponent("Packs/skills/orphan-body.skill.json").path
      )
    )
  }

  @Test
  func createSkillRejectsCapabilitiesCombinedWithTriggers() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "skill",
        "--root",
        root.path,
        "--name",
        "Hybrid Skill",
        "--description",
        "Declares both a capability and a trigger.",
        "--capability",
        "edit-files",
        "--path-glob",
        "**/*.swift",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("grounding skill") || stderrOutput.contains("tool skill"))
    #expect(
      !FileManager.default.fileExists(
        atPath: root.appendingPathComponent("Packs/skills/hybrid-skill.skill.json").path
      )
    )
  }

  @Test
  func createGroundingSkillRefusesToClobberExistingBodyWithoutForce() throws {
    let root = try makeWritableFixtureRoot()
    let skillsDir = root.appendingPathComponent("Packs/skills")
    try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)
    let bodyURL = skillsDir.appendingPathComponent("swift-style-guide.md")
    try "hand-authored body".write(to: bodyURL, atomically: true, encoding: .utf8)

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "skill",
        "--root",
        root.path,
        "--name",
        "Swift Style Guide",
        "--description",
        "Deeper Swift rationale.",
        "--path-glob",
        "**/*.swift",
        "--json",
      ])
    }

    #expect(status == 1)
    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let error = try #require(object["error"] as? String)
    #expect(error.contains("Refusing to overwrite existing file"))
    #expect(try String(contentsOf: bodyURL, encoding: .utf8) == "hand-authored body")
  }

  @Test
  func createDirectiveWithSkillEmitsRequiresSkillIds() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "directive",
        "--root",
        root.path,
        "--title",
        "Apply Style",
        "--goal",
        "Apply the repo style contract.",
        "--skill",
        "swift-style-guide",
        "--dry-run",
        "--json",
      ])
    }

    #expect(status == 0)

    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let renderedContent = try #require(object["renderedContent"] as? String)
    #expect(renderedContent.contains("\"requiresSkillIds\""))
    #expect(renderedContent.contains("\"swift-style-guide\""))
  }

  @Test
  func createDirectiveInlineReviewMarkerKeepsStepOrder() throws {
    let root = try makeWritableFixtureRoot()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "create",
        "directive",
        "--root",
        root.path,
        "--title",
        "Ordered",
        "--goal",
        "Check ordering.",
        "--step",
        "First normal step.",
        "--step",
        "review: Stop and review before the write.",
        "--step",
        "Final normal step.",
        "--dry-run",
        "--json",
      ])
    }

    #expect(status == 0)

    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let renderedContent = try #require(object["renderedContent"] as? String)
    let rendered = try #require(
      JSONSerialization.jsonObject(with: Data(renderedContent.utf8)) as? [String: Any]
    )
    let steps = try #require(rendered["steps"] as? [[String: Any]])

    #expect(steps.count == 3)
    #expect(steps[0]["text"] as? String == "First normal step.")
    #expect(steps[0]["requiresReview"] == nil)
    #expect(steps[1]["text"] as? String == "Stop and review before the write.")
    #expect(steps[1]["requiresReview"] as? Bool == true)
    #expect(steps[2]["text"] as? String == "Final normal step.")
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
