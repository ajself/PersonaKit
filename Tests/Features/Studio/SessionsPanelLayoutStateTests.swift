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
}
