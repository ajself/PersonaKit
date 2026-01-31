import Foundation
import XCTest
@testable import PersonaKit

final class ListCommandTests: XCTestCase {
    func testListPersonas() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)

        let output = try ListCommand.list(root: root, entityType: .personas)

        XCTAssertEqual(output, "senior-swiftui-engineer — Senior SwiftUI Engineer")
    }

    func testListEssentials() throws {
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

        XCTAssertEqual(output, expected)
    }
}
