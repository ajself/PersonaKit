import Foundation
import Testing

@testable import PersonaPadCore

@Suite("PersonaPadCore Resolver")
struct PersonaPadCoreResolverTests {
  @Test("Merge sets overrides later and warns on duplicates")
  func mergeSetsOverridesLaterAndWarnsOnDuplicates() {
    let sourceA = PersonaSource(kind: .project, url: URL(fileURLWithPath: "/tmp/a.json"))
    let sourceB = PersonaSource(kind: .project, url: URL(fileURLWithPath: "/tmp/b.json"))
    let pack = PackMeta(id: "pack.id", name: "Pack", author: nil, description: nil, homepage: nil)

    let first = Persona(id: "dup", name: "First", system: "SYSTEM_A")
    let second = Persona(id: "dup", name: "Second", system: "SYSTEM_B")

    let setA = PersonaSet(source: sourceA, pack: pack, defaults: nil, personas: [first])
    let setB = PersonaSet(source: sourceB, pack: pack, defaults: nil, personas: [second])

    let result = PersonaResolver.mergeSets([setA, setB])
    #expect(result.personas["dup"]?.name == "Second")
    #expect(
      result.diagnostics.contains {
        $0.severity == .warning
          && $0.source == sourceB
          && $0.message.contains("overrides an earlier definition")
      }
    )
  }
}
