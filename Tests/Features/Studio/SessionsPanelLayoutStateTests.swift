import Testing

@testable import StudioFeatures

struct SessionsPanelLayoutStateTests {
  @Test
  func resolvedDetailModeDefaultsToPreviewWhenRawValueIsMissing() {
    let mode = SessionsPanelLayoutState.resolvedDetailMode(
      persistedRawValue: nil
    )

    #expect(mode == .preview)
  }

  @Test
  func resolvedDetailModeDefaultsToPreviewWhenRawValueIsInvalid() {
    let mode = SessionsPanelLayoutState.resolvedDetailMode(
      persistedRawValue: "invalid"
    )

    #expect(mode == .preview)
  }

  @Test
  func resolvedDetailModeRestoresPersistedRawValue() {
    let mode = SessionsPanelLayoutState.resolvedDetailMode(
      persistedRawValue: SessionsDetailMode.map.rawValue
    )

    #expect(mode == .map)
  }

  @Test
  func persistedRawValueMatchesDetailModeRawValue() {
    let persistedRawValue = SessionsPanelLayoutState.persistedRawValue(
      for: .map
    )

    #expect(persistedRawValue == SessionsDetailMode.map.rawValue)
  }

  @Test
  func reconciledSelectionPreservesExistingSessionWhenStillAvailable() {
    let reconciledSelection = SessionsPanelLayoutState.reconciledSelection(
      currentSelectedSessionID: "session-a",
      availableSessionIDs: ["session-a", "session-b"]
    )

    #expect(reconciledSelection == "session-a")
  }

  @Test
  func reconciledSelectionClearsSelectionWhenSessionNoLongerExists() {
    let reconciledSelection = SessionsPanelLayoutState.reconciledSelection(
      currentSelectedSessionID: "session-a",
      availableSessionIDs: ["session-b", "session-c"]
    )

    #expect(reconciledSelection == nil)
  }

  @Test
  func reconciledSelectionRemainsNilWhenNothingIsSelected() {
    let reconciledSelection = SessionsPanelLayoutState.reconciledSelection(
      currentSelectedSessionID: nil,
      availableSessionIDs: ["session-a"]
    )

    #expect(reconciledSelection == nil)
  }

  @Test
  func unresolvedIssueBadgeTextReturnsNilForMissingOrZeroIssueCount() {
    let nilBadge = SessionsPanelLayoutState.unresolvedIssueBadgeText(
      issueCount: nil
    )
    let zeroBadge = SessionsPanelLayoutState.unresolvedIssueBadgeText(
      issueCount: 0
    )

    #expect(nilBadge == nil)
    #expect(zeroBadge == nil)
  }

  @Test
  func unresolvedIssueBadgeTextReturnsCountForPositiveIssueCount() {
    let badgeText = SessionsPanelLayoutState.unresolvedIssueBadgeText(
      issueCount: 3
    )

    #expect(badgeText == "3")
  }

  @Test
  func expectedSessionMapRequestKeyBuildsSessionRequestKey() {
    let requestKey = SessionsPanelLayoutState.expectedSessionMapRequestKey(for: "session-a")

    #expect(requestKey == "session:session-a")
  }

  @Test
  func unresolvedIssueBadgeTextReturnsCountWhenMapRequestMatchesSelection() {
    let badgeText = SessionsPanelLayoutState.unresolvedIssueBadgeText(
      issueCount: 2,
      mapRequestKey: "session:session-a",
      selectedSessionID: "session-a"
    )

    #expect(badgeText == "2")
  }

  @Test
  func unresolvedIssueBadgeTextReturnsNilWhenMapRequestIsStale() {
    let badgeText = SessionsPanelLayoutState.unresolvedIssueBadgeText(
      issueCount: 2,
      mapRequestKey: "session:session-a",
      selectedSessionID: "session-b"
    )

    #expect(badgeText == nil)
  }

  @Test
  func personaMetadataLineFormatsPersonaID() {
    let personaLine = SessionsPanelLayoutState.personaMetadataLine(
      personaID: "persona-a"
    )

    #expect(personaLine == "persona: persona-a")
  }

  @Test
  func directiveMetadataLineFormatsDirectiveID() {
    let directiveLine = SessionsPanelLayoutState.directiveMetadataLine(
      directiveID: "directive-b"
    )

    #expect(directiveLine == "directive: directive-b")
  }

  @Test
  func workstreamMetadataLineFormatsWorkstreamSummary() {
    let metadataLine = SessionsPanelLayoutState.workstreamMetadataLine(
      workstreamID: "worktree-squad-lifecycle",
      phase: "planning"
    )

    #expect(metadataLine == "workstream: worktree-squad-lifecycle · phase: planning")
  }

  @Test
  func mapHealthTextReturnsRefreshingWhileLoading() {
    let healthText = SessionsPanelLayoutState.mapHealthText(
      isLoading: true,
      mapIsFullyResolved: nil,
      unresolvedIssueCount: nil
    )

    #expect(healthText == "Refreshing...")
  }

  @Test
  func mapHealthTextReturnsUnavailableWhenMapIsMissing() {
    let healthText = SessionsPanelLayoutState.mapHealthText(
      isLoading: false,
      mapIsFullyResolved: nil,
      unresolvedIssueCount: nil
    )

    #expect(healthText == "Unavailable")
  }

  @Test
  func mapHealthTextReturnsResolvedWhenMapIsFullyResolved() {
    let healthText = SessionsPanelLayoutState.mapHealthText(
      isLoading: false,
      mapIsFullyResolved: true,
      unresolvedIssueCount: 0
    )

    #expect(healthText == "Resolved")
  }

  @Test
  func mapHealthTextReturnsIssueCountWhenMapHasResolutionErrors() {
    let healthText = SessionsPanelLayoutState.mapHealthText(
      isLoading: false,
      mapIsFullyResolved: false,
      unresolvedIssueCount: 3
    )

    #expect(healthText == "3 issues")
  }

  @Test
  func mapHealthTextReturnsSingularIssueWhenMapHasSingleResolutionError() {
    let healthText = SessionsPanelLayoutState.mapHealthText(
      isLoading: false,
      mapIsFullyResolved: false,
      unresolvedIssueCount: 1
    )

    #expect(healthText == "1 issue")
  }
}
