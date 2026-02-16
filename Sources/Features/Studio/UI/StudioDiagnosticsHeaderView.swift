import SwiftUI

/// Header section for diagnostics actions and summary messaging.
struct StudioDiagnosticsHeaderView: View {
  let summary: String
  let onValidateWorkspace: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text("Validation Results")
        .font(.title3)
        .fontWeight(.semibold)

      Spacer()

      Button("Validate Workspace") {
        onValidateWorkspace()
      }
    }

    Text(summary)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }
}
