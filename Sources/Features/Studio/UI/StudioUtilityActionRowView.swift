import SwiftUI

/// Shared utility action descriptor for compact primary and secondary action rows.
struct StudioUtilityActionItem: Identifiable {
  let id: String
  let title: String
  let systemImage: String
  let isEnabled: Bool
  let action: () -> Void
}

/// Shared utility row with one prominent primary action and optional secondary actions.
struct StudioUtilityActionRowView: View {
  let primaryAction: StudioUtilityActionItem?
  let secondaryActions: [StudioUtilityActionItem]
  var controlSize: ControlSize = .small
  var visibleSecondaryActionCount = 1

  var body: some View {
    HStack(spacing: 8) {
      if let primaryAction {
        primaryActionButton(primaryAction)
      }

      if !secondaryActions.isEmpty {
        secondaryActionRail
      }
    }
  }

  private var secondaryActionRail: some View {
    HStack(spacing: 8) {
      ForEach(visibleSecondaryActions) { action in
        secondaryActionButton(action)
      }

      if !overflowSecondaryActions.isEmpty {
        secondaryActionMenu
      }
    }
  }

  private var visibleSecondaryActions: [StudioUtilityActionItem] {
    Array(secondaryActions.prefix(visibleSecondaryActionCount))
  }

  private var overflowSecondaryActions: [StudioUtilityActionItem] {
    Array(secondaryActions.dropFirst(visibleSecondaryActionCount))
  }

  private var secondaryActionMenu: some View {
    Menu {
      ForEach(overflowSecondaryActions) { action in
        Button {
          action.action()
        } label: {
          Label(action.title, systemImage: action.systemImage)
        }
        .disabled(!action.isEnabled)
      }
    } label: {
      Label("More", systemImage: "ellipsis.circle")
        .labelStyle(.iconOnly)
    }
    .menuStyle(.button)
    .buttonStyle(.bordered)
    .controlSize(controlSize)
    .accessibilityLabel("More Actions")
  }

  private func primaryActionButton(_ action: StudioUtilityActionItem) -> some View {
    Button {
      action.action()
    } label: {
      adaptiveLabel(action)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(controlSize)
    .disabled(!action.isEnabled)
    .accessibilityLabel(action.title)
    .accessibilityIdentifier(action.id)
  }

  private func secondaryActionButton(
    _ action: StudioUtilityActionItem
  ) -> some View {
    Button {
      action.action()
    } label: {
      adaptiveLabel(action)
    }
    .buttonStyle(.bordered)
    .controlSize(controlSize)
    .disabled(!action.isEnabled)
    .accessibilityLabel(action.title)
    .accessibilityIdentifier(action.id)
  }

  private func adaptiveLabel(_ action: StudioUtilityActionItem) -> some View {
    ViewThatFits(in: .horizontal) {
      Label(action.title, systemImage: action.systemImage)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)

      Label(action.title, systemImage: action.systemImage)
        .labelStyle(.iconOnly)
    }
  }
}
