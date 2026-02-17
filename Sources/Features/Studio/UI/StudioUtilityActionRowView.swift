import SwiftUI

/// Shared utility action descriptor for compact primary + segmented secondary rows.
struct StudioUtilityActionItem: Identifiable {
  let id: String
  let title: String
  let systemImage: String
  let isEnabled: Bool
  let action: () -> Void
}

/// Shared utility row with one prominent primary action and optional segmented secondary actions.
struct StudioUtilityActionRowView: View {
  let primaryAction: StudioUtilityActionItem?
  let secondaryActions: [StudioUtilityActionItem]
  var controlSize: ControlSize = .small

  @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
  @State private var hoveredSecondaryActionID: String?

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
    HStack(spacing: 0) {
      ForEach(Array(secondaryActions.enumerated()), id: \.element.id) { index, action in
        if index > 0 {
          railSeparator
        }

        secondaryActionButton(action)
      }
    }
    .padding(.horizontal, 2)
    .padding(.vertical, 2)
    .background(
      Capsule(style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          Capsule(style: .continuous)
            .strokeBorder(.white.opacity(0.11), lineWidth: 0.8)
        )
    )
  }

  private var railSeparator: some View {
    Rectangle()
      .fill(.white.opacity(0.14))
      .frame(width: 1, height: 14)
      .padding(.horizontal, 4)
      .padding(.vertical, 5)
  }

  private func primaryActionButton(_ action: StudioUtilityActionItem) -> some View {
    Button {
      action.action()
    } label: {
      Label(action.title, systemImage: action.systemImage)
        .labelStyle(.titleAndIcon)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(controlSize)
    .disabled(!action.isEnabled)
    .accessibilityLabel(action.title)
  }

  private func secondaryActionButton(
    _ action: StudioUtilityActionItem
  ) -> some View {
    let isHovered = hoveredSecondaryActionID == action.id

    return Button {
      action.action()
    } label: {
      Label(action.title, systemImage: action.systemImage)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(minHeight: 24)
        .background(
          Capsule(style: .continuous)
            .fill(isHovered ? .white.opacity(0.09) : .clear)
        )
    }
    .buttonStyle(.plain)
    .contentShape(Capsule(style: .continuous))
    .controlSize(controlSize)
    .disabled(!action.isEnabled)
    .foregroundStyle(action.isEnabled ? .primary : .secondary)
    .opacity(action.isEnabled ? 1 : 0.55)
    .animation(
      accessibilityReduceMotion ? nil : .easeOut(duration: 0.12),
      value: isHovered
    )
    .onHover { isHovering in
      guard action.isEnabled else {
        if hoveredSecondaryActionID == action.id {
          hoveredSecondaryActionID = nil
        }

        return
      }

      if isHovering {
        hoveredSecondaryActionID = action.id
      } else if hoveredSecondaryActionID == action.id {
        hoveredSecondaryActionID = nil
      }
    }
    .accessibilityLabel(action.title)
  }
}
