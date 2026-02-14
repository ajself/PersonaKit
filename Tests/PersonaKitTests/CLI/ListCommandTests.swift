import Foundation
import Testing
@testable import PersonaKit

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
            "tools-and-constraints"
        ].joined(separator: "\n")

        #expect(output == expected)
    }
}
