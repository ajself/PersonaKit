import Foundation
import XCTest
@testable import PersonaKit

final class ResolverTests: XCTestCase {
    func testResolveHappyPath() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)
        let registry = try Registry.load(root: root)

        let definition = SessionDefinition(
            personaId: "senior-swiftui-engineer",
            taskId: "apply-style",
            kitOverrides: nil
        )

        let session = try Resolver.resolve(definition: definition, registry: registry, rootURL: root)

        XCTAssertEqual(session.persona.id, "senior-swiftui-engineer")
        XCTAssertEqual(session.task.id, "apply-style")
        XCTAssertEqual(
            session.kits.map { $0.id },
            ["repo-constraints-kit", "swift-style-kit", "swiftui-style-kit"]
        )
        XCTAssertEqual(session.intents.map { $0.id }, ["swift-refactor-safe"])
        XCTAssertEqual(session.skills.map { $0.id }, ["codex-cli"])
        XCTAssertEqual(
            session.essentials.map { $0.id },
            [
                "environment",
                "non-goals",
                "swift-style-guide",
                "swiftui-style-guide",
                "tools-and-constraints"
            ]
        )
    }

    func testMissingKitIdError() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)

        let personaURL = root.appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
        let data = try Data(contentsOf: personaURL)
        let persona = try JSONDecoder().decode(Persona.self, from: data)
        let updatedPersona = Persona(
            id: persona.id,
            version: persona.version,
            name: persona.name,
            summary: persona.summary,
            responsibilities: persona.responsibilities,
            values: persona.values,
            nonGoals: persona.nonGoals,
            defaultKitIds: ["missing-kit"],
            allowedSkillIds: persona.allowedSkillIds,
            forbiddenSkillIds: persona.forbiddenSkillIds
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updatedPersona).write(to: personaURL)

        let registry = try Registry.load(root: root)
        let definition = SessionDefinition(
            personaId: "senior-swiftui-engineer",
            taskId: "apply-style",
            kitOverrides: nil
        )

        XCTAssertThrowsError(try Resolver.resolve(definition: definition, registry: registry, rootURL: root)) { error in
            guard let resolutionError = error as? ResolverResolutionError else {
                return XCTFail("Expected ResolverResolutionError")
            }
            XCTAssertEqual(
                resolutionError.errors,
                [
                    .missingKitId(
                        sourceType: .persona,
                        sourceId: "senior-swiftui-engineer",
                        field: "defaultKitIds",
                        missingId: "missing-kit"
                    )
                ]
            )
        }
    }

    func testMissingEssentialFileError() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)

        let missingURL = root.appendingPathComponent("Packs/essentials/swiftui-style-guide.md")
        try FileManager.default.removeItem(at: missingURL)

        let registry = try Registry.load(root: root)
        let definition = SessionDefinition(
            personaId: "senior-swiftui-engineer",
            taskId: "apply-style",
            kitOverrides: nil
        )

        XCTAssertThrowsError(try Resolver.resolve(definition: definition, registry: registry, rootURL: root)) { error in
            guard let resolutionError = error as? ResolverResolutionError else {
                return XCTFail("Expected ResolverResolutionError")
            }
            XCTAssertEqual(
                resolutionError.errors,
                [
                    .missingEssentialFile(
                        sourceType: .kit,
                        sourceId: "swiftui-style-kit",
                        field: "essentialIds",
                        missingId: "swiftui-style-guide",
                        expectedPath: "Packs/essentials/swiftui-style-guide.md"
                    )
                ]
            )
        }
    }

    func testDeterministicOrdering() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)
        let registry = try Registry.load(root: root)

        let definition = SessionDefinition(
            personaId: "senior-swiftui-engineer",
            taskId: "apply-style",
            kitOverrides: nil
        )

        let session = try Resolver.resolve(definition: definition, registry: registry, rootURL: root)

        XCTAssertEqual(session.kits.map { $0.id }, session.kits.map { $0.id }.sorted())
        XCTAssertEqual(session.intents.map { $0.id }, session.intents.map { $0.id }.sorted())
        XCTAssertEqual(session.skills.map { $0.id }, session.skills.map { $0.id }.sorted())
        XCTAssertEqual(session.essentials.map { $0.id }, session.essentials.map { $0.id }.sorted())
    }
}
