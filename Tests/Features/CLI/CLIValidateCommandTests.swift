import Foundation
import Testing

@testable import ContextCLI

struct CLIValidateCommandTests {
  @Test
  func validateRejectsPackPathWhenItIsAFile() throws {
    let root = try makeValidateRootWithPackFile(relativePath: "personas")

    var status: Int32 = 0
    let stdoutOutput = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "validate",
        "--root",
        root.path,
      ])
    }

    #expect(status == 1)
    #expect(stdoutOutput.contains("errors=1"))
    #expect(stdoutOutput.contains("persona file: Expected directory. expectedPath=Packs/personas"))
  }

  @Test
  func validateRejectsEssentialPathWhenItIsAFile() throws {
    let root = try makeValidateRootWithPackFile(relativePath: "essentials")

    var status: Int32 = 0
    let stdoutOutput = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "validate",
        "--root",
        root.path,
      ])
    }

    #expect(status == 1)
    #expect(stdoutOutput.contains("errors=1"))
    #expect(stdoutOutput.contains("essentials file: Expected directory. expectedPath=Packs/essentials"))
  }
}

private func makeValidateRootWithPackFile(relativePath: String) throws -> URL {
  let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
  let packsURL = root.appendingPathComponent("Packs")
  try FileManager.default.createDirectory(
    at: packsURL,
    withIntermediateDirectories: true
  )
  try Data("not a directory".utf8).write(to: packsURL.appendingPathComponent(relativePath))

  return root
}
