import ContextCore
import Foundation

func makeWorkstreamFixtureRoot() throws -> URL {
  let root = try makeTempDirectory().appendingPathComponent("FixtureKit")
  try copyFixtureKit(to: root)
  try installWorkstreamFixture(into: root)
  return root
}

func installWorkstreamFixture(into root: URL) throws {
  try writeSessionFile(
    SessionFile(
      id: "style-followup",
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    ),
    root: root
  )
  try writeSessionFile(
    SessionFile(
      id: "style-closeout",
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    ),
    root: root
  )
  try writeApplyStyleDirective(
    root: root,
    workstream: makeValidFixtureWorkstream()
  )
}

func makeValidFixtureWorkstream() -> Directive.Workstream {
  Directive.Workstream(
    id: "style-workstream",
    phase: "planning",
    entrySessionId: "senior-swiftui-engineer_apply-style",
    requiredCloseoutSessionId: "style-closeout",
    nodes: [
      .init(
        sessionId: "senior-swiftui-engineer_apply-style",
        phase: "planning"
      ),
      .init(
        sessionId: "style-followup",
        phase: "followup"
      ),
      .init(
        sessionId: "style-closeout",
        phase: "closeout"
      ),
    ],
    edges: [
      .init(
        fromSessionId: "senior-swiftui-engineer_apply-style",
        toSessionId: "style-followup",
        kind: "required-next"
      ),
      .init(
        fromSessionId: "style-followup",
        toSessionId: "style-closeout",
        kind: "required-closeout"
      ),
    ]
  )
}

func writeApplyStyleDirective(
  root: URL,
  workstream: Directive.Workstream?
) throws {
  let directiveURL = root.appendingPathComponent("Packs/directives/apply-style.directive.json")
  let data = try Data(contentsOf: directiveURL)
  let directive = try JSONDecoder().decode(Directive.self, from: data)
  let updatedDirective = Directive(
    id: directive.id,
    version: directive.version,
    title: directive.title,
    goal: directive.goal,
    steps: directive.steps,
    acceptanceCriteria: directive.acceptanceCriteria,
    verification: directive.verification,
    requiresIntentTemplateIds: directive.requiresIntentTemplateIds,
    requiresSkillIds: directive.requiresSkillIds,
    workstream: workstream
  )
  try encodeSortedJSON(updatedDirective).write(
    to: directiveURL,
    options: .atomic
  )
}

func writeSessionFile(
  _ session: SessionFile,
  root: URL
) throws {
  let sessionURL = root.appendingPathComponent("Sessions/\(session.id).session.json")
  try encodeSortedJSON(session).write(
    to: sessionURL,
    options: .atomic
  )
}

func removeSessionFile(
  id: String,
  root: URL
) throws {
  let sessionURL = root.appendingPathComponent("Sessions/\(id).session.json")
  try FileManager.default.removeItem(at: sessionURL)
}

func encodeSortedJSON<T: Encodable>(_ value: T) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  return try encoder.encode(value)
}
