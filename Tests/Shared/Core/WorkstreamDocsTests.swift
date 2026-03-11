import Foundation
import Testing

@testable import ContextCore

struct WorkstreamDocsTests {
  @Test
  func buildCatalogProducesCanonicalWorkstreamProjection() throws {
    let root = try makeWorkstreamFixtureRoot()
    let followupDirective = Directive.Workstream(
      id: "style-workstream",
      phase: "followup",
      entrySessionId: "senior-swiftui-engineer_apply-style",
      requiredCloseoutSessionId: "style-closeout",
      nodes: makeValidFixtureWorkstream().nodes,
      edges: makeValidFixtureWorkstream().edges
    )
    try writeDirective(
      id: "z-style-followup",
      title: "Style followup",
      root: root,
      workstream: followupDirective
    )

    let catalog = try WorkstreamDocsBuilder.buildCatalog(root: root)

    #expect(catalog.workstreams.count == 1)
    #expect(catalog.memberships.count == 3)

    let workstream = try #require(catalog.workstreams.first)
    #expect(workstream.id == "style-workstream")
    #expect(workstream.representativeDirectiveId == "apply-style")
    #expect(
      workstream.directiveIds
        == [
          "apply-style",
          "z-style-followup",
        ]
    )
  }

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

    let errors = WorkstreamDocsBuilder.consistencyErrors(
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

    let errors = WorkstreamDocsBuilder.consistencyErrors(
      directives: directives
    )

    #expect(errors.count == 1)
    #expect(errors.first?.field == "workstream.entrySessionId")
    #expect(errors.first?.message.contains("style-workstream") == true)
    #expect(errors.first?.message.contains("apply-style") == true)
    #expect(errors.first?.message.contains("style-followup") == true)
  }

  @Test
  func renderWorkstreamDirectoryIsDeterministic() throws {
    let root = try makeWorkstreamFixtureRoot()

    let catalog = try WorkstreamDocsBuilder.buildCatalog(root: root)
    let output = WorkstreamDocsBuilder.renderWorkstreamDirectory(
      catalog: catalog
    )

    let expected = """
      # Workstream Directory

      > Generated file. Do not edit manually.
      > Source of truth: directive-owned workstream metadata in `.personakit/Packs/directives/`.

      This directory is a committed projection over directive workstream metadata.
      Regenerate it with `swift run personakit workstream-docs --root .personakit --write`.

      ## Active Workstreams

      ### style-workstream

      - Entry session: `senior-swiftui-engineer_apply-style`
      - Required closeout session: `style-closeout`

      Session map:

      - `planning` -> `senior-swiftui-engineer_apply-style`
      - `followup` -> `style-followup`
      - `closeout` -> `style-closeout`

      Edge map:

      - `senior-swiftui-engineer_apply-style` -> `style-followup` (`required-next`)
      - `style-followup` -> `style-closeout` (`required-closeout`)

      Participating sessions:

      - `senior-swiftui-engineer_apply-style`
      - `style-followup`
      - `style-closeout`
      """

    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func replacingMembershipSectionUpdatesOnlySentinelBlock() throws {
    let document = """
      # Session Directory

      Intro

      ## State Summary

      - `active`: 1 sessions

      <!-- WORKSTREAM_MEMBERSHIP:START -->
      ## Workstream Membership

      old
      <!-- WORKSTREAM_MEMBERSHIP:END -->
      """
    let replacement = """
      <!-- WORKSTREAM_MEMBERSHIP:START -->
      ## Workstream Membership

      new
      <!-- WORKSTREAM_MEMBERSHIP:END -->
      """

    let output = try WorkstreamDocsBuilder.replacingMembershipSection(
      in: document,
      with: replacement
    )

    #expect(output.contains("# Session Directory"))
    #expect(output.contains("## State Summary"))
    #expect(output.contains("new"))
    #expect(!output.contains("\nold\n"))
  }

  @Test
  func replacingMembershipSectionFailsWhenMarkersMissing() {
    do {
      _ = try WorkstreamDocsBuilder.replacingMembershipSection(
        in: "# Session Directory\n",
        with: "ignored"
      )
      Issue.record("Expected missing marker failure.")
    } catch let error as WorkstreamDocsError {
      #expect(error == .missingSessionDirectoryMarkers)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func replacingMembershipSectionFailsWhenMarkersAreDuplicated() {
    let document = """
      <!-- WORKSTREAM_MEMBERSHIP:START -->
      one
      <!-- WORKSTREAM_MEMBERSHIP:START -->
      two
      <!-- WORKSTREAM_MEMBERSHIP:END -->
      """

    do {
      _ = try WorkstreamDocsBuilder.replacingMembershipSection(
        in: document,
        with: "ignored"
      )
      Issue.record("Expected duplicated marker failure.")
    } catch let error as WorkstreamDocsError {
      #expect(error == .duplicatedSessionDirectoryMarkers)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func buildOutputRendersWorkstreamDirectoryAndHybridSessionDirectory() throws {
    let root = try makeWorkstreamFixtureRoot()
    let sessionDirectory = """
      # Session Directory

      Manual intro

      ## State Summary

      - `active`: 1 sessions

      <!-- WORKSTREAM_MEMBERSHIP:START -->
      ## Workstream Membership

      old
      <!-- WORKSTREAM_MEMBERSHIP:END -->
      """

    let output = try WorkstreamDocsBuilder.buildOutput(
      root: root,
      currentSessionDirectory: sessionDirectory
    )

    #expect(output.workstreamDirectory.contains("### style-workstream"))
    #expect(output.sessionDirectory.contains("## Workstream Membership"))
    #expect(output.sessionDirectory.contains("`style-followup`"))
    #expect(
      output.sessionDirectory.contains(
        "./workstream-directory.md#style-workstream"
      )
    )
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
    requiresIntentTemplateIds: [],
    requiresSkillIds: [],
    workstream: workstream
  )
}
