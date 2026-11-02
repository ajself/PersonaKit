import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Diagnostics panel with validation issue search and navigation helpers.
struct StudioDiagnosticsPanelView: View {
  let workspaceStore: WorkspaceStore
  @Binding var searchText: String
  @Binding var isInspectorPresented: Bool
  @Binding var inspectorMode: StudioInspectorMode
  let onNavigate: (StudioNavigationTarget) -> Void

  @State private var selectedIssueFilterID = "all"

  var body: some View {
    let report = StudioValidationReportState(
      snapshot: workspaceStore.snapshot,
      validation: workspaceStore.validation,
      validationErrorMessage: workspaceStore.validationErrorMessage
    )
    let issues = report.visibleIssues(
      selectedFilterID: selectedIssueFilterID,
      searchText: searchText
    )

    // Root as a ScrollView so its content insets below the window toolbar. A plain
    // VStack detail underlaps the unified toolbar, hiding the header behind it; a scroll
    // container reserves that safe area.
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        StudioDiagnosticsHeaderView(
          report: report,
          searchText: $searchText,
          onValidateWorkspace: {
            workspaceStore.validateWorkspace()
          }
        )

        if let validationErrorMessage = workspaceStore.validationErrorMessage {
          ContentUnavailableView(
            "Validation Failed",
            systemImage: "exclamationmark.triangle",
            description: Text(validationErrorMessage)
          )
        } else if report.issues.isEmpty {
          StudioValidationReportOverviewView(
            report: report,
            onNavigateToArea: { row in
              onNavigate(
                StudioNavigationTarget(
                  sidebarItem: row.sidebarItem,
                  searchText: ""
                )
              )
            }
          )
        } else {
          StudioValidationIssueFilterBarView(
            options: report.issueFilterOptions,
            selectedIssueFilterID: $selectedIssueFilterID
          )

          if issues.isEmpty {
            ContentUnavailableView.search
              .frame(maxWidth: .infinity, minHeight: 180)
          } else {
            StudioDiagnosticsIssueListView(
              issues: issues,
              onNavigateToIssue: { issue in
                let navigationTarget = StudioDiagnosticsNavigationResolver.navigationTarget(for: issue)
                onNavigate(navigationTarget)
              },
              onRevealIssueFile: { issue in
                guard let filePath = issue.filePath else {
                  return
                }

                workspaceStore.revealValidationIssueInFinder(filePath: filePath)
              }
            )
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .padding()
    }
    .inspector(isPresented: $isInspectorPresented) {
      StudioContextInspectorView(
        primaryTitle: "Info",
        helpTopic: StudioHelpCatalog.topic(for: SidebarItem.validationResults),
        mode: $inspectorMode,
        onNavigateHelpLink: { link in
          onNavigate(
            StudioNavigationTarget(
              sidebarItem: link.destination,
              searchText: link.searchText ?? ""
            )
          )
        }
      ) {
        StudioValidationStatusInspectorView(
          report: report,
          selectedIssueFilterID: selectedIssueFilterID
        )
      }
      .inspectorColumnWidth(min: 190, ideal: 270, max: 360)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onChange(of: report.issueFilterOptions.map(\.id)) { _, filterIDs in
      if !filterIDs.contains(selectedIssueFilterID) {
        selectedIssueFilterID = "all"
      }
    }
  }
}

private struct StudioValidationReportOverviewView: View {
  let report: StudioValidationReportState
  let onNavigateToArea: (StudioValidationAreaRow) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Validated Areas")
        .font(.headline)

      VStack(spacing: 0) {
        ForEach(report.areaRows) { row in
          Button {
            onNavigateToArea(row)
          } label: {
            HStack(spacing: 10) {
              Image(systemName: row.issueCount == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(row.issueCount == 0 ? .green : .orange)
                .frame(width: 18)

              VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                  .font(.subheadline)
                  .fontWeight(.semibold)

                Text(row.countText)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Spacer()

              Text(statusText(for: row))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(statusColor(for: row))

              Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 9)
          }
          .buttonStyle(.plain)

          if row.id != report.areaRows.last?.id {
            Divider()
          }
        }
      }
      .padding(.horizontal, 12)
      .background(
        RoundedRectangle(cornerRadius: StudioDesign.Radius.card)
          .fill(.secondary.opacity(0.06))
      )

      if let omittedAreaSummary = report.omittedAreaSummary {
        Text(omittedAreaSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .contain)
  }

  private func statusText(for row: StudioValidationAreaRow) -> String {
    switch report.status {
    case .clean,
      .issues:
      return row.statusText
    case .validating:
      return "Checking"
    case .failed:
      return "Unavailable"
    case .notRun:
      return "Not validated"
    }
  }

  private func statusColor(for row: StudioValidationAreaRow) -> Color {
    if row.issueCount > 0 {
      return .orange
    }

    return .secondary
  }
}

private struct StudioValidationIssueFilterBarView: View {
  let options: [StudioValidationIssueFilter]
  @Binding var selectedIssueFilterID: String

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(options) { option in
          Button(option.title) {
            selectedIssueFilterID = option.id
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .tint(selectedIssueFilterID == option.id ? .accentColor : .secondary)
        }
      }
    }
    .accessibilityLabel("Validation issue filters")
  }
}

private struct StudioValidationStatusInspectorView: View {
  let report: StudioValidationReportState
  let selectedIssueFilterID: String

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Validation Status")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      StudioInspectorSection("Summary") {
        StudioMetadataRow(label: "Status", value: report.status.title)
        StudioMetadataRow(label: "Headline", value: report.statusHeadline)

        if let coverageLine = report.coverageLine {
          StudioMetadataRow(label: "Coverage", value: coverageLine)
        }
      }

      StudioInspectorSection("Issues") {
        StudioMetadataRow(label: "Count", value: report.issueCountText)
        StudioMetadataRow(label: "Entities", value: report.affectedEntitiesText)
        StudioMetadataRow(label: "Files", value: report.affectedFilesText)
        StudioMetadataRow(label: "Filter", value: selectedFilterTitle)
      }

      StudioInspectorSection("Validated Areas") {
        if report.areaRows.isEmpty {
          StudioMetadataRow(label: "Areas", value: "None")
        } else {
          ForEach(report.areaRows) { row in
            StudioMetadataRow(label: row.title, value: row.statusText)
          }
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  private var selectedFilterTitle: String {
    report.issueFilterOptions.first { $0.id == selectedIssueFilterID }?.title ?? "All"
  }
}

enum StudioDiagnosticsNavigationResolver {
  static func navigationTarget(
    for issue: WorkspaceValidationIssue
  ) -> StudioNavigationTarget {
    let sidebarItem = sidebarItem(for: issue.entityType)
    let selectedLibraryItemID = issue.entityId ?? inferredEntityID(for: issue)

    if let selectedLibraryItemID {
      return StudioNavigationTarget(
        sidebarItem: sidebarItem,
        selectedLibraryItemID: selectedLibraryItemID,
        searchText: selectedLibraryItemID
      )
    }

    if issue.filePath != nil {
      // Lists don't search file paths, so land on the section unfiltered.
      return StudioNavigationTarget(
        sidebarItem: sidebarItem,
        searchText: ""
      )
    }

    return StudioNavigationTarget(
      sidebarItem: sidebarItem,
      searchText: issue.message
    )
  }

  static func sidebarItem(
    for entityType: WorkspaceValidationEntityType
  ) -> SidebarItem {
    switch entityType {
    case .session:
      return .sessions
    case .persona:
      return .personas
    case .kit:
      return .kits
    case .directive:
      return .directives
    case .skill:
      return .skills
    }
  }

  private static func inferredEntityID(
    for issue: WorkspaceValidationIssue
  ) -> String? {
    guard let filePath = issue.filePath else {
      return nil
    }

    let lastPathComponent = URL(fileURLWithPath: filePath).lastPathComponent

    switch issue.entityType {
    case .session:
      return removingSuffix(".session.json", from: lastPathComponent)
    case .persona:
      return removingSuffix(".persona.json", from: lastPathComponent)
    case .kit:
      return removingSuffix(".kit.json", from: lastPathComponent)
    case .directive:
      return removingSuffix(".directive.json", from: lastPathComponent)
    case .skill:
      return removingSuffix(".skill.json", from: lastPathComponent)
    }
  }

  private static func removingSuffix(
    _ suffix: String,
    from value: String
  ) -> String? {
    guard value.hasSuffix(suffix) else {
      return nil
    }

    return String(value.dropLast(suffix.count))
  }
}
