import SwiftUI

/// Header section for diagnostics actions and summary messaging.
struct StudioDiagnosticsHeaderView: View {
  let report: StudioValidationReportState
  @Binding var searchText: String
  let onValidateWorkspace: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      headerControls

      Text(report.statusHeadline)
        .font(.headline)

      if let coverageLine = report.coverageLine {
        Text(coverageLine)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if report.showsCompletedStats {
        HStack(spacing: 8) {
          statBadge(report.checkedItemsText)
          statBadge(report.issueCountText)
          statBadge(report.affectedFilesText)
        }
      }
    }
  }

  private var headerControls: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        titleGroup

        Spacer(minLength: 12)

        searchAndActionGroup
      }

      VStack(alignment: .leading, spacing: 8) {
        titleGroup
        searchAndActionGroup
      }
    }
  }

  private var titleGroup: some View {
    HStack(spacing: 12) {
      Text("Validation Results")
        .font(.title3)
        .fontWeight(.semibold)

      StudioBadge(title: report.status.title, tone: statusTone, size: .regular)
    }
  }

  private var searchAndActionGroup: some View {
    HStack(spacing: 12) {
      StudioSearchField(
        text: $searchText,
        prompt: "Search Validation"
      )
      .frame(minWidth: 180, idealWidth: 240, maxWidth: 280)

      Button("Validate Workspace") {
        onValidateWorkspace()
      }
    }
  }

  private var statusTone: StudioBadgeTone {
    switch report.status {
    case .clean:
      return .success
    case .issues,
      .failed:
      return .warning
    case .validating,
      .notRun:
      return .neutral
    }
  }

  private func statBadge(_ title: String) -> some View {
    StudioBadge(title: title, size: .regular)
  }
}
