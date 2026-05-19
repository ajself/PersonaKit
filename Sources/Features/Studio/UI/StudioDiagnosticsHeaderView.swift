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

      Text(report.status.title)
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          Capsule()
            .fill(statusColor.opacity(0.16))
        )
        .foregroundStyle(statusColor)
    }
  }

  private var searchAndActionGroup: some View {
    HStack(spacing: 12) {
      StudioSearchField(
        text: $searchText,
        prompt: "Search Validation"
      )
      .frame(width: 260)

      Button("Validate Workspace") {
        onValidateWorkspace()
      }
    }
  }

  private var statusColor: Color {
    switch report.status {
    case .clean:
      return .green
    case .issues,
      .failed:
      return .orange
    case .validating,
      .notRun:
      return .secondary
    }
  }

  private func statBadge(_ title: String) -> some View {
    Text(title)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        Capsule()
          .fill(.secondary.opacity(0.1))
      )
  }
}
