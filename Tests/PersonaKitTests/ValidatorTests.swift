import Foundation
import Testing
@testable import PersonaKit

struct ValidatorTests {
    @Test
    func validateStarterKitClean() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)

        let result = try Validator.validate(root: root)

        #expect(result.errors.isEmpty)
        #expect(
            result.counts == ValidationCounts(
                personas: 1,
                kits: 3,
                tasks: 1,
                intents: 1,
                skills: 2,
                essentials: 5
            )
        )
    }

    @Test
    func validateMissingEssentialFile() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)

        let missingURL = root.appendingPathComponent("Packs/essentials/swiftui-style-guide.md")
        try FileManager.default.removeItem(at: missingURL)

        let result = try Validator.validate(root: root)

        #expect(
            result.errors == [
                ValidationError(
                    entityType: .kit,
                    entityId: "swiftui-style-kit",
                    field: "essentialIds",
                    missingId: "swiftui-style-guide",
                    expectedPath: "Packs/essentials/swiftui-style-guide.md",
                    message: "Missing essential file at Packs/essentials/swiftui-style-guide.md."
                )
            ]
        )
    }

    @Test
    func validateUnknownKitId() throws {
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
            defaultKitIds: ["unknown-kit"],
            allowedSkillIds: persona.allowedSkillIds,
            forbiddenSkillIds: persona.forbiddenSkillIds
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updatedPersona).write(to: personaURL)

        let result = try Validator.validate(root: root)

        #expect(
            result.errors == [
                ValidationError(
                    entityType: .persona,
                    entityId: "senior-swiftui-engineer",
                    field: "defaultKitIds",
                    missingId: "unknown-kit",
                    expectedPath: nil,
                    message: "Missing kit id \"unknown-kit\"."
                )
            ]
        )
    }
}
