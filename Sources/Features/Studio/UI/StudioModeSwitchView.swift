import SwiftUI

private enum StudioModeSwitchTokens {
  static let controlHeight = CGFloat(28)
}

/// Reusable native segmented switch for compact mode toggles in Studio panels.
struct StudioModeSwitchView<ID: Hashable>: View {
  let items: [StudioModeSwitchItem<ID>]
  @Binding var selection: ID
  let keyboardShortcut: (ID) -> (key: KeyEquivalent, modifiers: EventModifiers)?
  let accessibilityLabel: String

  init(
    items: [StudioModeSwitchItem<ID>],
    selection: Binding<ID>,
    keyboardShortcut: @escaping (ID) -> (key: KeyEquivalent, modifiers: EventModifiers)? = { _ in
      nil
    },
    accessibilityLabel: String = "Detail Mode"
  ) {
    self.items = items
    _selection = selection
    self.keyboardShortcut = keyboardShortcut
    self.accessibilityLabel = accessibilityLabel
  }

  var body: some View {
    Picker(accessibilityLabel, selection: $selection) {
      ForEach(items) { item in
        Label(item.title, systemImage: item.systemImage)
          .tag(item.id)
      }
    }
    .pickerStyle(.segmented)
    .controlSize(.small)
    .labelsHidden()
    .frame(height: StudioModeSwitchTokens.controlHeight)
    .background(shortcutButtons)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityLabel)
  }

  @ViewBuilder
  private var shortcutButtons: some View {
    ForEach(items) { item in
      if let shortcut = keyboardShortcut(item.id) {
        Button(item.title) {
          selection = item.id
        }
        .keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
      }
    }
    .opacity(0)
    .accessibilityHidden(true)
    .frame(width: 0, height: 0)
  }
}
