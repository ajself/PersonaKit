import Foundation
import Testing

@testable import ContextCore

struct ReferenceGraphTests {
  private func makeGraph() -> ReferenceGraph {
    let persona = Persona(
      id: "p",
      version: "1.0",
      name: "P",
      summary: "",
      responsibilities: [],
      values: [],
      nonGoals: [],
      defaultKitIds: ["k"],
      allowedSkillIds: ["used-skill"],
      forbiddenSkillIds: []
    )
    let kit = Kit(
      id: "k",
      version: "1.0",
      name: "K",
      summary: "",
      skillIds: ["used-skill"]
    )
    func skill(_ id: String) -> Skill {
      Skill(
        id: id,
        version: "1.0",
        name: id,
        description: "",
        providedBy: ["tests"],
        risk: Skill.Risk(level: "low", requiresHumanReview: false, notes: []),
        notes: []
      )
    }
    let session = SessionFile(id: "s", personaId: "p", directiveId: "d", kitOverrides: nil)

    let registry = Registry(
      personasById: ["p": persona],
      kitsById: ["k": kit],
      directivesById: [:],
      skillsById: ["used-skill": skill("used-skill"), "lonely-skill": skill("lonely-skill")]
    )

    return ReferenceGraph(registry: registry, sessions: [session])
  }

  @Test
  func orphansReportsUnreferencedEntitiesAndExcludesSessions() {
    let orphans = makeGraph().orphans()

    #expect(orphans == [ReferenceNode(type: .skill, id: "lonely-skill")])
  }

  @Test
  func incomingEdgesTraceEveryReferrer() {
    let graph = makeGraph()
    let incoming = graph.incoming(to: ReferenceNode(type: .skill, id: "used-skill"))

    #expect(incoming.count == 2)
    #expect(incoming.contains { $0.from == ReferenceNode(type: .persona, id: "p") && $0.field == "allowedSkillIds" })
    #expect(incoming.contains { $0.from == ReferenceNode(type: .kit, id: "k") && $0.field == "skillIds" })
  }

  @Test
  func outgoingEdgesTraceEveryReference() {
    let graph = makeGraph()
    let outgoing = graph.outgoing(from: ReferenceNode(type: .persona, id: "p"))

    #expect(outgoing.map(\.to) == [
      ReferenceNode(type: .kit, id: "k"),
      ReferenceNode(type: .skill, id: "used-skill"),
    ])
  }

  @Test
  func directlyInvocableTypesAreSessionsPersonasAndDirectives() {
    #expect(ReferenceEntityType.session.isDirectlyInvocable)
    #expect(ReferenceEntityType.persona.isDirectlyInvocable)
    #expect(ReferenceEntityType.directive.isDirectlyInvocable)
    #expect(!ReferenceEntityType.kit.isDirectlyInvocable)
    #expect(!ReferenceEntityType.skill.isDirectlyInvocable)
  }

  @Test
  func nodesWithIdMatchAcrossTypes() {
    let graph = makeGraph()

    #expect(graph.nodes(withId: "k") == [ReferenceNode(type: .kit, id: "k")])
    #expect(graph.nodes(withId: "missing").isEmpty)
  }
}
