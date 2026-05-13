import Foundation
import Testing

@testable import ContextCLI

struct CLIGuidanceCommandTests {
  @Test
  func guidancePrintsBestGroundingJSON() throws {
    let root = repoRootURL().appendingPathComponent(".personakit")

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "guidance",
        "--root",
        root.path,
      ])
    }
    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let scope = try #require(object["scope"] as? [String: Any])
    let commands = try #require(object["suggestedCommands"] as? [String])

    #expect(status == 0)
    #expect(object["schemaVersion"] as? Int == 1)
    #expect(scope["projectRoot"] as? String == root.path)
    #expect(
      commands.contains(
        "personakit contract --root \(root.path) --session solo-dev-v1"
      )
    )
  }
}
