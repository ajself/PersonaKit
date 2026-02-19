import SwiftUI

/// Shared inline help container with collapsed hint row and expandable content.
struct StudioInlineHelpView: View {
  let topic: StudioHelpTopic
  @Binding var isExpanded: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StudioHelpHintChipView(
        hintText: topic.shortHint,
        isExpanded: $isExpanded
      )
      .padding(.horizontal, 10)
      .padding(.vertical, 10)

      if isExpanded {
        Divider()
          .overlay(.white.opacity(0.08))
          .padding(.horizontal, 10)
          .padding(.bottom, 12)

        StudioHelpCardView(
          topic: topic
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .transition(.opacity)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(.quaternary.opacity(0.1))
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(.white.opacity(0.08), lineWidth: 0.8)
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .padding(.horizontal, 8)
    .padding(.top, 8)
  }
}
