import SwiftUI

/// Reusable command bar used by Studio CRUD list panels.
struct StudioActionBarView: View {
  let actions: [StudioActionItem]
  let isLoading: Bool

  private static let controlSize: ControlSize = .small

  private static let itemSpacing = CGFloat(8)
  private static let sectionSpacing = CGFloat(12)

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: Self.itemSpacing) {
        actionSection(for: .primary)

        if hasActions(for: .primary),
          hasActions(for: .selection)
        {
          sectionSpacer
        }

        actionSection(for: .selection)

        if isLoading {
          ProgressView()
            .controlSize(Self.controlSize)
        }

        if hasActions(for: .destructive),
          hasActions(for: .selection)
        {
          sectionSpacer
        }

        actionSection(for: .destructive)

        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.1))

      Divider()
    }
  }

  private var sectionSpacer: some View {
    Rectangle()
      .fill(.quaternary)
      .frame(width: 1, height: 18)
      .padding(.horizontal, Self.sectionSpacing / 2)
  }

  @ViewBuilder
  private func actionSection(for group: StudioActionGroup) -> some View {
    ForEach(actionsForGroup(group)) { action in
      actionButton(for: action)
    }
  }

  private func actionsForGroup(_ group: StudioActionGroup) -> [StudioActionItem] {
    actions.filter { $0.group == group }
  }

  private func hasActions(for group: StudioActionGroup) -> Bool {
    !actionsForGroup(group).isEmpty
  }

  @ViewBuilder
  private func actionButton(for action: StudioActionItem) -> some View {
    switch action.role {
    case .primary:
      Button {
        action.action()
      } label: {
        Label(action.title, systemImage: action.systemImage)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(Self.controlSize)
      .disabled(!action.isEnabled)

    case .standard:
      Button {
        action.action()
      } label: {
        Label(action.title, systemImage: action.systemImage)
      }
      .buttonStyle(.bordered)
      .controlSize(Self.controlSize)
      .disabled(!action.isEnabled)

    case .destructive:
      Button(role: .destructive) {
        action.action()
      } label: {
        Label(action.title, systemImage: action.systemImage)
      }
      .buttonStyle(.bordered)
      .controlSize(Self.controlSize)
      .disabled(!action.isEnabled)
    }
  }
}
