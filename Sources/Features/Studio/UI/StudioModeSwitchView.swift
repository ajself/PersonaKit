import SwiftUI

private enum StudioModeSwitchTokens {
  static let railHeight = CGFloat(32)
  static let railHorizontalPadding = CGFloat(3)
  static let segmentHorizontalPadding = CGFloat(12)
  static let segmentMinimumWidth = CGFloat(92)
}

/// Reusable capsule-rail switch for compact mode toggles in Studio panels.
struct StudioModeSwitchView<ID: Hashable>: View {
  let items: [StudioModeSwitchItem<ID>]
  @Binding var selection: ID
  let keyboardShortcut: (ID) -> (key: KeyEquivalent, modifiers: EventModifiers)?

  @Namespace private var activeSegmentNamespace
  @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
  @State private var hoveredItemID: ID?

  init(
    items: [StudioModeSwitchItem<ID>],
    selection: Binding<ID>,
    keyboardShortcut: @escaping (ID) -> (key: KeyEquivalent, modifiers: EventModifiers)? = { _ in
      nil
    }
  ) {
    self.items = items
    _selection = selection
    self.keyboardShortcut = keyboardShortcut
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(items) { item in
        itemButton(item)
      }
    }
    .animation(
      accessibilityReduceMotion
        ? nil
        : .snappy(duration: 0.16),
      value: selection
    )
    .padding(.horizontal, StudioModeSwitchTokens.railHorizontalPadding)
    .frame(height: StudioModeSwitchTokens.railHeight)
    .background(
      Capsule(style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          Capsule(style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Detail Mode")
  }

  @ViewBuilder
  private func itemButton(_ item: StudioModeSwitchItem<ID>) -> some View {
    if let shortcut = keyboardShortcut(item.id) {
      baseItemButton(item)
        .keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    } else {
      baseItemButton(item)
    }
  }

  private func baseItemButton(_ item: StudioModeSwitchItem<ID>) -> some View {
    let isSelected = selection == item.id

    return Button(action: {
      assignSelection(item.id)
    }) {
      segmentContent(
        item: item,
        isSelected: isSelected
      )
    }
    .buttonStyle(.plain)
    .contentShape(Capsule(style: .continuous))
    .onHover { isHovering in
      if isHovering {
        hoveredItemID = item.id
      } else if hoveredItemID == item.id {
        hoveredItemID = nil
      }
    }
    .accessibilityLabel("\(item.title) Mode")
    .accessibilityHint(item.accessibilityHint ?? "")
    .accessibilityValue(isSelected ? "Selected" : "Not Selected")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func assignSelection(_ itemID: ID) {
    selection = itemID
  }

  private func segmentContent(
    item: StudioModeSwitchItem<ID>,
    isSelected: Bool
  ) -> some View {
    ZStack {
      if isSelected {
        Capsule(style: .continuous)
          .fill(.tint.opacity(0.82))
          .overlay(
            Capsule(style: .continuous)
              .strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
          )
          .overlay(
            Capsule(style: .continuous)
              .fill(
                LinearGradient(
                  colors: [
                    .white.opacity(0.18),
                    .clear,
                  ],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
          )
          .matchedGeometryEffect(
            id: "studio.mode-switch.active-segment",
            in: activeSegmentNamespace
          )
      } else if hoveredItemID == item.id {
        Capsule(style: .continuous)
          .fill(.white.opacity(0.08))
      }

      HStack(spacing: 6) {
        Image(systemName: item.systemImage)
          .font(.callout.weight(.semibold))

        Text(item.title)
          .font(.callout.weight(.semibold))

        if let badgeText = item.badgeText {
          Text(badgeText)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
              Capsule(style: .continuous)
                .fill(badgeBackgroundStyle(isSelected: isSelected))
            )
        }
      }
      .foregroundStyle(isSelected ? .white : .secondary)
      .padding(.horizontal, StudioModeSwitchTokens.segmentHorizontalPadding)
      .frame(minWidth: StudioModeSwitchTokens.segmentMinimumWidth, maxWidth: .infinity)
      .frame(maxHeight: .infinity)
    }
  }

  private func badgeBackgroundStyle(
    isSelected: Bool
  ) -> AnyShapeStyle {
    if isSelected {
      return AnyShapeStyle(.white.opacity(0.2))
    }

    return AnyShapeStyle(.quaternary.opacity(0.3))
  }
}
