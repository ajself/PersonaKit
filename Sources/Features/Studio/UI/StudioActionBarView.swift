import SwiftUI

/// Reusable command bar used by Studio CRUD list panels.
struct StudioActionBarView: View {
  let actions: [StudioActionItem]
  let isLoading: Bool
  let searchText: Binding<String>?
  let searchPrompt: String?

  init(
    actions: [StudioActionItem],
    isLoading: Bool,
    searchText: Binding<String>? = nil,
    searchPrompt: String? = nil
  ) {
    self.actions = actions
    self.isLoading = isLoading
    self.searchText = searchText
    self.searchPrompt = searchPrompt
  }

  private static let controlSize: ControlSize = .small

  private static let itemSpacing = CGFloat(8)
  private static let sectionSpacing = CGFloat(12)

  private enum LabelMode {
    case full
    case compact
  }

  var body: some View {
    VStack(spacing: 0) {
      actionBarContent
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.1))

      Divider()
    }
  }

  private var actionBarContent: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Self.itemSpacing) {
        actionButtons

        Spacer(minLength: 12)

        searchAccessory
      }

      VStack(alignment: .leading, spacing: 8) {
        actionButtons
        searchAccessory
      }
    }
  }

  private var actionButtons: some View {
    ViewThatFits(in: .horizontal) {
      actionButtonRow(labelMode: .full)
      actionButtonRow(labelMode: .compact)
    }
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var searchAccessory: some View {
    if let searchText,
      let searchPrompt
    {
      StudioSearchField(
        text: searchText,
        prompt: searchPrompt
      )
      .frame(minWidth: 140, idealWidth: 200, maxWidth: 260)
    }
  }

  private var sectionSpacer: some View {
    Rectangle()
      .fill(.quaternary)
      .frame(width: 1, height: 18)
      .padding(.horizontal, Self.sectionSpacing / 2)
  }

  private func actionButtonRow(labelMode: LabelMode) -> some View {
    HStack(spacing: Self.itemSpacing) {
      actionSection(for: .primary, labelMode: labelMode)

      if labelMode == .full,
        hasActions(for: .primary),
        hasActions(for: .selection)
      {
        sectionSpacer
      }

      actionSection(for: .selection, labelMode: labelMode)

      if isLoading {
        ProgressView()
          .controlSize(Self.controlSize)
      }

      if labelMode == .full,
        hasActions(for: .destructive),
        hasActions(for: .selection)
      {
        sectionSpacer
      }

      actionSection(for: .destructive, labelMode: labelMode)
    }
  }

  private func actionsForGroup(_ group: StudioActionGroup) -> [StudioActionItem] {
    actions.filter { $0.group == group }
  }

  private func hasActions(for group: StudioActionGroup) -> Bool {
    !actionsForGroup(group).isEmpty
  }

  @ViewBuilder
  private func actionSection(
    for group: StudioActionGroup,
    labelMode: LabelMode
  ) -> some View {
    ForEach(actionsForGroup(group)) { action in
      actionButton(
        for: action,
        labelMode: labelMode
      )
    }
  }

  @ViewBuilder
  private func actionButton(
    for action: StudioActionItem,
    labelMode: LabelMode
  ) -> some View {
    switch action.role {
    case .primary:
      Button {
        action.action()
      } label: {
        actionLabel(action, labelMode: labelMode)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(Self.controlSize)
      .disabled(!action.isEnabled)
      .help(action.title)

    case .standard:
      Button {
        action.action()
      } label: {
        actionLabel(action, labelMode: labelMode)
      }
      .buttonStyle(.bordered)
      .controlSize(Self.controlSize)
      .disabled(!action.isEnabled)
      .help(action.title)

    case .destructive:
      Button(role: .destructive) {
        action.action()
      } label: {
        actionLabel(action, labelMode: labelMode)
      }
      .buttonStyle(.bordered)
      .controlSize(Self.controlSize)
      .disabled(!action.isEnabled)
      .help(action.title)
    }
  }

  @ViewBuilder
  private func actionLabel(
    _ action: StudioActionItem,
    labelMode: LabelMode
  ) -> some View {
    switch labelMode {
    case .full:
      Label(action.title, systemImage: action.systemImage)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)

    case .compact:
      Label(action.title, systemImage: action.systemImage)
        .labelStyle(.iconOnly)
    }
  }
}
