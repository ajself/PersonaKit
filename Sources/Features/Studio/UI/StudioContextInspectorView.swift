import SwiftUI

/// Shared segmented inspector shell for section context and contextual help.
struct StudioContextInspectorView<ContextContent: View>: View {
  let primaryTitle: String
  let helpTopic: StudioHelpTopic?
  @Binding var mode: StudioInspectorMode
  let onNavigateHelpLink: (StudioHelpLink) -> Void
  let contextContent: () -> ContextContent

  init(
    primaryTitle: String,
    helpTopic: StudioHelpTopic?,
    mode: Binding<StudioInspectorMode>,
    onNavigateHelpLink: @escaping (StudioHelpLink) -> Void,
    @ViewBuilder contextContent: @escaping () -> ContextContent
  ) {
    self.primaryTitle = primaryTitle
    self.helpTopic = helpTopic
    _mode = mode
    self.onNavigateHelpLink = onNavigateHelpLink
    self.contextContent = contextContent
  }

  var body: some View {
    VStack(spacing: 0) {
      Picker("Inspector Mode", selection: $mode) {
        Text(primaryTitle)
          .tag(StudioInspectorMode.primary)

        Text("Help")
          .tag(StudioInspectorMode.help)
      }
      .pickerStyle(.segmented)
      .controlSize(.small)
      .labelsHidden()
      .accessibilityLabel("Inspector Mode")
      .padding(.horizontal, 14)
      .padding(.top, 14)
      .padding(.bottom, 10)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          switch mode {
          case .primary:
            contextContent()
          case .help:
            helpContent
          }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private var helpContent: some View {
    if let helpTopic {
      StudioHelpCardView(topic: helpTopic)

      if !helpTopic.relatedLinks.isEmpty {
        relatedLinksView(helpTopic.relatedLinks)
      }
    } else {
      ContentUnavailableView(
        "No Help Available",
        systemImage: "questionmark.circle",
        description: Text("This Studio section does not provide contextual help.")
      )
      .frame(maxWidth: .infinity, minHeight: 220)
    }
  }

  private func relatedLinksView(
    _ links: [StudioHelpLink]
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Related")
        .font(.subheadline.weight(.semibold))

      VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(links.enumerated()), id: \.offset) { _, link in
          Button {
            onNavigateHelpLink(link)
          } label: {
            HStack(spacing: 10) {
              Image(systemName: link.destination.systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 26, alignment: .leading)

              Text(link.label)
                .lineLimit(1)
                .truncationMode(.tail)

              Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .accessibilityLabel(link.label)
          .accessibilityHint("Navigates to \(link.destination.title).")
        }
      }
    }
  }
}
