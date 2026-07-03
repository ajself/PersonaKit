import Foundation
import Testing

@testable import ContextCore

struct WorkstreamConsistencyTests {
  @Test
  func consistencyErrorsIgnoreDirectivePhaseDifferences() throws {
    let baseWorkstream = makeValidFixtureWorkstream()
    let followupDirective = Directive.Workstream(
      id: baseWorkstream.id,
      phase: "followup",
      entrySessionId: baseWorkstream.entrySessionId,
      requiredCloseoutSessionId: baseWorkstream.requiredCloseoutSessionId,
      nodes: baseWorkstream.nodes,
      edges: baseWorkstream.edges
    )
    let directives = [
      makeDirectiveFixture(
        id: "apply-style",
        workstream: baseWorkstream
      ),
      makeDirectiveFixture(
        id: "style-followup",
        workstream: followupDirective
      ),
    ]

    let errors = ValidatorWorkstreamValidator.consistencyErrors(
      directives: directives
    )

    #expect(errors.isEmpty)
  }

  @Test
  func consistencyErrorsRejectMismatchedEntrySession() {
    let baseWorkstream = makeValidFixtureWorkstream()
    let mismatchedWorkstream = Directive.Workstream(
      id: baseWorkstream.id,
      phase: "followup",
      entrySessionId: "style-followup",
      requiredCloseoutSessionId: baseWorkstream.requiredCloseoutSessionId,
      nodes: baseWorkstream.nodes,
      edges: baseWorkstream.edges
    )
    let directives = [
      makeDirectiveFixture(
        id: "apply-style",
        workstream: baseWorkstream
      ),
      makeDirectiveFixture(
        id: "style-followup",
        workstream: mismatchedWorkstream
      ),
    ]

    let errors = ValidatorWorkstreamValidator.consistencyErrors(
      directives: directives
    )

    #expect(errors.count == 1)
    #expect(errors.first?.field == "workstream.entrySessionId")
    #expect(errors.first?.message.contains("style-workstream") == true)
    #expect(errors.first?.message.contains("apply-style") == true)
    #expect(errors.first?.message.contains("style-followup") == true)
  }
}

private func makeDirectiveFixture(
  id: String,
  workstream: Directive.Workstream
) -> Directive {
  Directive(
    id: id,
    version: "1.0",
    title: id,
    goal: "Goal",
    steps: [],
    acceptanceCriteria: [],
    verification: [],
    requiresSkillIds: [],
    workstream: workstream
  )
}
