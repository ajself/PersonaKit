import SwiftUI

struct StudioWorkspaceSummaryView: View {
  let state: StudioWorkspaceSummaryState

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Workspace Summary")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)

        Text(state.workspacePath)
          .font(.caption.monospaced())
          .foregroundStyle(.primary)
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)
      }

      validationBadge

      Divider()
        .frame(height: 22)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(state.counts) { count in
            countBadge(count)
          }
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.08))
  }

  private var validationBadge: some View {
    Text(state.validationStatus.title)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        Capsule()
          .fill(validationColor.opacity(0.16))
      )
      .foregroundStyle(validationColor)
      .accessibilityLabel("Validation \(state.validationStatus.title)")
  }

  private var validationColor: Color {
    switch state.validationStatus {
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

  private func countBadge(_ count: StudioWorkspaceCount) -> some View {
    HStack(spacing: 4) {
      Text(count.title)
        .foregroundStyle(.secondary)

      Text("\(count.count)")
        .fontWeight(.semibold)
        .foregroundStyle(.primary)
    }
    .font(.caption)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(.secondary.opacity(0.1))
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(count.title) \(count.count)")
  }
}
