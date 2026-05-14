import SwiftUI

/// Header section for diagnostics actions and summary messaging.
struct StudioDiagnosticsHeaderView: View {
  let summary: String
  let validationStatus: StudioWorkspaceValidationStatus
  let onValidateWorkspace: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text("Validation Results")
        .font(.title3)
        .fontWeight(.semibold)

      Text(validationStatus.title)
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

    Text(summary)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }

  private var statusColor: Color {
    switch validationStatus {
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
}
