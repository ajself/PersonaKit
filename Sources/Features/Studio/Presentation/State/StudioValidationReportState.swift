import ContextWorkspaceCore
import Foundation

struct StudioValidationAreaRow: Equatable, Sendable, Identifiable {
  let id: String
  let title: String
  let count: Int
  let issueCount: Int
  let sidebarItem: SidebarItem
  let entityType: WorkspaceValidationEntityType

  var countText: String {
    "\(count) \(singularTitle)\(count == 1 ? "" : "s")"
  }

  var statusText: String {
    guard issueCount > 0 else {
      return "No issues reported"
    }

    return "\(issueCount) issue\(issueCount == 1 ? "" : "s")"
  }

  private var singularTitle: String {
    entityType.rawValue
  }
}

struct StudioValidationIssueFilter: Equatable, Sendable, Identifiable {
  let id: String
  let title: String
  let entityType: WorkspaceValidationEntityType?
}

struct StudioValidationReportState: Equatable, Sendable {
  let status: StudioWorkspaceValidationStatus
  let areaRows: [StudioValidationAreaRow]
  let omittedAreaTitles: [String]
  let issues: [WorkspaceValidationIssue]
  /// Reference-missing issues hidden from the displayed list because the global library
  /// is not connected; they cannot be verified, so the panel surfaces a single Connect
  /// prompt instead of reporting each as a hard error.
  let suppressedGlobalReferenceIssues: [WorkspaceValidationIssue]

  init(
    snapshot: WorkspaceSnapshot,
    validation: WorkspaceValidationSnapshot,
    validationErrorMessage: String?,
    globalLibraryConnected: Bool = true
  ) {
    // While the global library is disconnected, unresolved references to shared entities
    // can't be verified — fold them into the Connect prompt instead of showing them as
    // errors. Once connected (or in scopes where global is always readable) every issue
    // is shown as-is.
    let displayedIssues: [WorkspaceValidationIssue]

    if globalLibraryConnected {
      displayedIssues = validation.issues
      suppressedGlobalReferenceIssues = []
    } else {
      displayedIssues = validation.issues.filter { !$0.referencesUnresolvedID }
      suppressedGlobalReferenceIssues = validation.issues.filter(\.referencesUnresolvedID)
    }

    status = StudioWorkspaceValidationStatus.status(
      validation: WorkspaceValidationSnapshot(
        summary: validation.summary,
        issues: displayedIssues
      ),
      validationErrorMessage: validationErrorMessage
    )
    issues = displayedIssues

    let rows = Self.allAreaRows(snapshot: snapshot, issues: displayedIssues)
    areaRows = rows.filter { $0.count > 0 }
    omittedAreaTitles = rows.filter { $0.count == 0 }.map(\.title)
  }

  /// `true` when the global library is disconnected and at least one reference-missing
  /// issue was folded away — the panel should show the single Connect prompt.
  var showsGlobalLibraryBanner: Bool {
    !suppressedGlobalReferenceIssues.isEmpty
  }

  var statusHeadline: String {
    switch status {
    case .clean:
      return "No validation issues reported"
    case .issues(let count):
      return "\(count) issue\(count == 1 ? "" : "s") need review"
    case .validating:
      return "Validating workspace"
    case .failed:
      return "Validation failed"
    case .notRun:
      return "Not validated"
    }
  }

  var coverageLine: String? {
    switch status {
    case .clean,
      .issues:
      break
    case .validating:
      return "Checking workspace contents..."
    case .failed,
      .notRun:
      return nil
    }

    let sessionText = "\(sessionCount) session\(sessionCount == 1 ? "" : "s")"
    let libraryText =
      "\(libraryContextItemCount) library/context item\(libraryContextItemCount == 1 ? "" : "s")"

    return "Checked \(sessionText) and \(libraryText)"
  }

  var checkedItemsText: String {
    "\(checkedItemCount) checked"
  }

  var showsCompletedStats: Bool {
    switch status {
    case .clean,
      .issues:
      return true
    case .validating,
      .failed,
      .notRun:
      return false
    }
  }

  var issueCountText: String {
    "\(issues.count) issue\(issues.count == 1 ? "" : "s")"
  }

  var affectedEntitiesText: String {
    "\(affectedEntityCount) affected entit\(affectedEntityCount == 1 ? "y" : "ies")"
  }

  var affectedFilesText: String {
    "\(affectedFileCount) affected file\(affectedFileCount == 1 ? "" : "s")"
  }

  var omittedAreaSummary: String? {
    guard !omittedAreaTitles.isEmpty else {
      return nil
    }

    return "No \(Self.joinedList(omittedAreaTitles.map { $0.lowercased() })) in this workspace"
  }

  var issueFilterOptions: [StudioValidationIssueFilter] {
    let issueTypes = Set(issues.map(\.entityType))

    let options = Self.areaDefinitions.compactMap { definition -> StudioValidationIssueFilter? in
      guard issueTypes.contains(definition.entityType) else {
        return nil
      }

      return StudioValidationIssueFilter(
        id: definition.entityType.rawValue,
        title: definition.title,
        entityType: definition.entityType
      )
    }

    guard !options.isEmpty else {
      return []
    }

    return [
      StudioValidationIssueFilter(id: "all", title: "All", entityType: nil)
    ] + options
  }

  func visibleIssues(
    selectedFilterID: String?,
    searchText: String
  ) -> [WorkspaceValidationIssue] {
    let normalizedFilterID = selectedFilterID == "all" ? nil : selectedFilterID
    let filteredIssues: [WorkspaceValidationIssue]

    if let normalizedFilterID {
      filteredIssues = issues.filter { $0.entityType.rawValue == normalizedFilterID }
    } else {
      filteredIssues = issues
    }

    let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalizedSearch.isEmpty else {
      return filteredIssues
    }

    return filteredIssues.filter { issue in
      issue.message.localizedCaseInsensitiveContains(normalizedSearch)
        || issue.entityType.rawValue.localizedCaseInsensitiveContains(normalizedSearch)
        || issue.field.localizedCaseInsensitiveContains(normalizedSearch)
        || (issue.entityId?.localizedCaseInsensitiveContains(normalizedSearch) ?? false)
        || (issue.filePath?.localizedCaseInsensitiveContains(normalizedSearch) ?? false)
    }
  }

  private var checkedItemCount: Int {
    areaRows.reduce(0) { $0 + $1.count }
  }

  private var sessionCount: Int {
    areaRows.first { $0.entityType == .session }?.count ?? 0
  }

  private var libraryContextItemCount: Int {
    checkedItemCount - sessionCount
  }

  private var affectedEntityCount: Int {
    Set(issues.map(Self.affectedEntityKey(for:))).count
  }

  private var affectedFileCount: Int {
    Set(issues.compactMap(\.filePath)).count
  }

  private static func affectedEntityKey(
    for issue: WorkspaceValidationIssue
  ) -> String {
    [
      issue.entityType.rawValue,
      issue.entityId ?? issue.filePath ?? issue.field,
    ].joined(separator: "::")
  }

  private static func allAreaRows(
    snapshot: WorkspaceSnapshot,
    issues: [WorkspaceValidationIssue]
  ) -> [StudioValidationAreaRow] {
    areaDefinitions.map { definition in
      StudioValidationAreaRow(
        id: definition.entityType.rawValue,
        title: definition.title,
        count: definition.count(snapshot),
        issueCount: issues.filter { $0.entityType == definition.entityType }.count,
        sidebarItem: definition.sidebarItem,
        entityType: definition.entityType
      )
    }
  }

  private static let areaDefinitions: [StudioValidationAreaDefinition] = [
    StudioValidationAreaDefinition(
      title: "Sessions",
      sidebarItem: .sessions,
      entityType: .session,
      count: { $0.sessions.count }
    ),
    StudioValidationAreaDefinition(
      title: "Personas",
      sidebarItem: .personas,
      entityType: .persona,
      count: { $0.personas.count }
    ),
    StudioValidationAreaDefinition(
      title: "Directives",
      sidebarItem: .directives,
      entityType: .directive,
      count: { $0.directives.count }
    ),
    StudioValidationAreaDefinition(
      title: "Kits",
      sidebarItem: .kits,
      entityType: .kit,
      count: { $0.kits.count }
    ),
    StudioValidationAreaDefinition(
      title: "Skills",
      sidebarItem: .skills,
      entityType: .skill,
      count: { $0.skills.count }
    ),
  ]

  private static func joinedList(_ values: [String]) -> String {
    switch values.count {
    case 0:
      return ""
    case 1:
      return values[0]
    case 2:
      return values.joined(separator: " or ")
    default:
      return values.dropLast().joined(separator: ", ") + ", or " + (values.last ?? "")
    }
  }
}

private struct StudioValidationAreaDefinition: Sendable {
  let title: String
  let sidebarItem: SidebarItem
  let entityType: WorkspaceValidationEntityType
  let count: @Sendable (WorkspaceSnapshot) -> Int
}
