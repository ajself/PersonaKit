import SwiftUI

struct StudioWorkspaceSummaryView: View {
  let state: StudioWorkspaceSummaryState
  let onNavigate: (SidebarItem) -> Void
  let onRevealWorkspace: () -> Void

  @State private var isPopoverPresented = false

  var body: some View {
    Button {
      isPopoverPresented.toggle()
    } label: {
      HStack(spacing: 7) {
        Image(systemName: "folder")
          .imageScale(.small)

        Text(state.chipTitle)
          .font(.caption)
          .fontWeight(.semibold)
          .lineLimit(1)
          .truncationMode(.middle)

        toolbarValidationBadge

        Image(systemName: "chevron.down")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .foregroundStyle(.primary)
    .accessibilityLabel(state.accessibilitySummary)
    .help("Workspace Status")
    .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
      popoverContent
    }
  }

  private var popoverContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Label(state.workspaceDisplayName, systemImage: "folder")
          .font(.headline)

        Spacer()

        validationBadge
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Path")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)

        Text(state.workspacePath)
          .font(.caption.monospaced())
          .textSelection(.enabled)
          .lineLimit(2)
          .truncationMode(.middle)
      }

      Divider()

      Button {
        navigate(to: .validationResults)
      } label: {
        popoverRow(
          systemImage: SidebarItem.validationResults.systemImage,
          title: "Validation Results",
          detail: state.validationStatus.title
        )
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Open Validation Results, \(state.validationStatus.title)")

      VStack(alignment: .leading, spacing: 6) {
        Text("Contents")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)

        ForEach(state.counts) { count in
          if let sidebarItem = StudioWorkspaceSummaryNavigationResolver.sidebarItem(for: count) {
            Button {
              navigate(to: sidebarItem)
            } label: {
              popoverRow(
                systemImage: sidebarItem.systemImage,
                title: count.title,
                detail: "\(count.count)"
              )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(count.title), \(count.count)")
          }
        }
      }

      Divider()

      Button {
        isPopoverPresented = false
        onRevealWorkspace()
      } label: {
        Label("Reveal Workspace", systemImage: "folder")
      }
      .controlSize(.small)
    }
    .padding(16)
    .frame(width: 380, alignment: .leading)
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

  @ViewBuilder
  private var toolbarValidationBadge: some View {
    switch state.validationStatus {
    case .clean:
      Image(systemName: "checkmark.circle.fill")
        .font(.caption)
        .foregroundStyle(.green)
        .accessibilityLabel("Validation No issues")

    case .issues(let count):
      HStack(spacing: 3) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.caption2)

        Text("\(count)")
          .font(.caption2)
          .fontWeight(.bold)
      }
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(
        Capsule()
          .fill(.orange.opacity(0.18))
      )
      .foregroundStyle(.orange)
      .accessibilityLabel("Validation \(state.validationStatus.title)")

    case .validating:
      ProgressView()
        .controlSize(.mini)
        .accessibilityLabel("Validation Validating")

    case .failed:
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.caption)
        .foregroundStyle(.orange)
        .accessibilityLabel("Validation failed")

    case .notRun:
      Image(systemName: "circle.dashed")
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Validation Not validated")
    }
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

  private func popoverRow(
    systemImage: String,
    title: String,
    detail: String
  ) -> some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage)
        .frame(width: 16)
        .foregroundStyle(.secondary)

      Text(title)
        .font(.subheadline)

      Spacer()

      Text(detail)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      Image(systemName: "chevron.right")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
    .padding(.vertical, 3)
  }

  private func navigate(to sidebarItem: SidebarItem) {
    isPopoverPresented = false
    onNavigate(sidebarItem)
  }
}

enum StudioWorkspaceSummaryNavigationResolver {
  static func sidebarItem(for count: StudioWorkspaceCount) -> SidebarItem? {
    switch count.id {
    case "sessions":
      return .sessions
    case "personas":
      return .personas
    case "directives":
      return .directives
    case "kits":
      return .kits
    case "skills":
      return .skills
    default:
      return nil
    }
  }
}
