import SwiftUI

/// Header section for diagnostics actions and summary messaging.
struct StudioDiagnosticsHeaderView: View {
  let report: StudioValidationReportState
  let onValidateWorkspace: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
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

        Spacer()

        Button("Validate Workspace") {
          onValidateWorkspace()
        }
      }

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
