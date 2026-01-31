import XCTest
@testable import PersonaKit

final class RegistryTests: XCTestCase {
    func testRegistryLoadsStarterKit() throws {
        let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: destination.path)

        let registry = try Registry.load(root: destination)

        XCTAssertEqual(registry.personas.map(\.id), ["senior-swiftui-engineer"])
        XCTAssertEqual(registry.kits.map(\.id), ["repo-constraints-kit", "swift-style-kit", "swiftui-style-kit"])
        XCTAssertEqual(registry.tasks.map(\.id), ["apply-style"])
        XCTAssertEqual(registry.intentTemplates.map(\.id), ["swift-refactor-safe"])
        XCTAssertEqual(registry.skills.map(\.id), ["autonomous-agent-loop", "codex-cli"])
    }

    func testRegistryDetectsDuplicateIDs() throws {
        let root = try makeTempDirectory()
        let packs = root.appendingPathComponent("Packs/personas")
        try FileManager.default.createDirectory(at: packs, withIntermediateDirectories: true)

        let personaJSON = """
        {
          \"id\": \"duplicate-persona\",
          \"version\": \"1.0\",
          \"name\": \"Duplicate Persona\",
          \"summary\": \"Testing duplicates\",
          \"responsibilities\": [],
          \"values\": [],
          \"nonGoals\": [],
          \"defaultKitIds\": [],
          \"allowedSkillIds\": [],
          \"forbiddenSkillIds\": []
        }
        """

        try Data(personaJSON.utf8).write(to: packs.appendingPathComponent("alpha.persona.json"))
        try Data(personaJSON.utf8).write(to: packs.appendingPathComponent("beta.persona.json"))

        do {
            _ = try Registry.load(root: root)
            XCTFail("Expected duplicate error")
        } catch let error as RegistryLoadError {
            XCTAssertEqual(error.errors.count, 1)
            let first = error.errors[0]
            XCTAssertEqual(first.entityType, .persona)
            XCTAssertEqual(first.id, "duplicate-persona")
            XCTAssertEqual(first.relativePath, "Packs/personas/beta.persona.json")
            XCTAssertEqual(first.message, "Duplicate id \"duplicate-persona\".")
        }
    }

    func testRegistryFailsOnMissingPacksDirectory() throws {
        let root = try makeTempDirectory()

        do {
            _ = try Registry.load(root: root)
            XCTFail("Expected missing Packs error")
        } catch let error as RegistryLoadError {
            XCTAssertEqual(error.errors.count, 1)
            let first = error.errors[0]
            XCTAssertEqual(first.entityType, .packsRoot)
            XCTAssertEqual(first.relativePath, "Packs")
            XCTAssertEqual(first.message, "Missing Packs directory.")
        }
    }
}
