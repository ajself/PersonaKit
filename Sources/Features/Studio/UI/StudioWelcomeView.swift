import SwiftUI

struct StudioWelcomeView: View {
  let recentWorkspaces: [StudioRecentWorkspace]
  let onOpenWorkspace: () -> Void
  let onOpenRecentWorkspace: (StudioRecentWorkspace) -> Void
  let onRemoveRecentWorkspace: (StudioRecentWorkspace) -> Void

  private let rows: [StudioWelcomeRow] = [
    StudioWelcomeRow(
      title: "Read a Contract",
      detail: "See what a session hands your agent: its role, skills, boundaries, and stop points.",
      systemImage: "doc.text.magnifyingglass"
    ),
    StudioWelcomeRow(
      title: "Write the Pieces",
      detail: "Create and edit the personas, directives, kits, and skills a session is built from.",
      systemImage: "square.and.pencil"
    ),
    StudioWelcomeRow(
      title: "Check Before Handoff",
      detail: "Validation flags missing references and schema problems before you export.",
      systemImage: "checkmark.seal"
    ),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      headerView

      VStack(alignment: .leading, spacing: 14) {
        ForEach(rows) { row in
          StudioWelcomeRowView(row: row)
        }
      }

      Button {
        onOpenWorkspace()
      } label: {
        Label("Open Workspace…", systemImage: "folder")
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .help("Open a folder that contains a .personakit directory")

      if !recentWorkspaces.isEmpty {
        recentWorkspacesView
      }
    }
    .padding(44)
    .frame(maxWidth: 620, alignment: .leading)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }

  private var headerView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Welcome to PersonaKit Studio")
        .font(.largeTitle.bold())

      Text("Read, write, and check the contracts your coding agents work under.")
        .font(.title3)
        .foregroundStyle(.secondary)
    }
  }

  private var recentWorkspacesView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Recent Workspaces")
        .font(.headline)

      VStack(alignment: .leading, spacing: 6) {
        ForEach(recentWorkspaces) { workspace in
          StudioRecentWorkspaceRowView(
            workspace: workspace,
            onOpen: {
              onOpenRecentWorkspace(workspace)
            },
            onRemove: {
              onRemoveRecentWorkspace(workspace)
            }
          )
        }
      }
    }
  }
}

private struct StudioWelcomeRow: Identifiable {
  let title: String
  let detail: String
  let systemImage: String

  var id: String {
    title
  }
}

private struct StudioWelcomeRowView: View {
  let row: StudioWelcomeRow

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: row.systemImage)
        .font(.title3)
        .foregroundStyle(.secondary)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 3) {
        Text(row.title)
          .font(.headline)

        Text(row.detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct StudioRecentWorkspaceRowView: View {
  let workspace: StudioRecentWorkspace
  let onOpen: () -> Void
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Button(action: onOpen) {
        VStack(alignment: .leading, spacing: 2) {
          Text(workspace.displayName)
            .font(.subheadline)
            .fontWeight(.semibold)
            .lineLimit(1)

          Text(workspace.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Open \(workspace.displayName)")
      .accessibilityValue(workspace.detail)
      .help(workspace.path)

      Button(action: onRemove) {
        Image(systemName: "xmark")
      }
      .buttonStyle(.borderless)
      .controlSize(.small)
      .accessibilityLabel("Remove \(workspace.displayName)")
      .help("Remove Recent Workspace")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: StudioDesign.Radius.card)
        .fill(.secondary.opacity(0.08))
    )
  }
}
