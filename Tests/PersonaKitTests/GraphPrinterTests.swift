import Foundation
import Testing
@testable import PersonaKit

struct GraphPrinterTests {
    @Test
    func graphOutputIsDeterministic() throws {
        let root = fixtureKitRootURL()

        let registry = try Registry.load(root: root)
        let definition = SessionDefinition(
            personaId: "senior-swiftui-engineer",
            taskId: "apply-style",
            kitOverrides: []
        )
        let resolved = try Resolver.resolve(definition: definition, registry: registry, rootURL: root)

        let output = GraphPrinter.render(resolvedSession: resolved, kitOverrides: [])

        let fixtureURL = fixturesRootURL()
            .appendingPathComponent("expected/graph_senior-swiftui-engineer_apply-style.txt")
        let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

        #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
    }

    @Test
    func graphOutputMatchesGoldenFileUsingSession() throws {
        let root = fixtureKitRootURL()
        let session = try SessionFileLoader.load(
            root: root,
            sessionId: "senior-swiftui-engineer_apply-style"
        )

        let registry = try Registry.load(root: root)
        let definition = SessionDefinition(
            personaId: session.personaId,
            taskId: session.taskId,
            kitOverrides: (session.kitOverrides ?? []).isEmpty ? nil : session.kitOverrides
        )
        let resolved = try Resolver.resolve(definition: definition, registry: registry, rootURL: root)

        let output = GraphPrinter.render(
            resolvedSession: resolved,
            kitOverrides: session.kitOverrides ?? []
        )

        let fixtureURL = fixturesRootURL()
            .appendingPathComponent("expected/graph_senior-swiftui-engineer_apply-style.txt")
        let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

        #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
    }

    @Test
    func graphUsesOverrides() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try copyFixtureKit(to: root)

        let extraKitURL = root.appendingPathComponent("Packs/kits/extra.kit.json")
        let extraKit = """
        {
          "id": "extra-kit",
          "version": "1.0",
          "name": "Extra Kit",
          "summary": "Additional kit for testing.",
          "essentialIds": [
            "environment"
          ]
        }
        """
        guard let extraKitData = extraKit.data(using: .utf8) else {
            #expect(Bool(false))
            return
        }
        try extraKitData.write(to: extraKitURL, options: .atomic)

        let registry = try Registry.load(root: root)
        let definition = SessionDefinition(
            personaId: "senior-swiftui-engineer",
            taskId: "apply-style",
            kitOverrides: ["extra-kit"]
        )
        let resolved = try Resolver.resolve(definition: definition, registry: registry, rootURL: root)

        let output = GraphPrinter.render(resolvedSession: resolved, kitOverrides: ["extra-kit"])

        #expect(output.contains("Kit overrides: extra-kit"))
        #expect(output.contains("- extra-kit — Extra Kit"))
    }
}
