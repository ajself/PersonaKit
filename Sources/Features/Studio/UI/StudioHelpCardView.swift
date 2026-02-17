import SwiftUI

/// Expanded contextual guidance card rendered inline inside Studio panels.
struct StudioHelpCardView: View {
  let topic: StudioHelpTopic

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(topic.title, systemImage: "info.circle.fill")
        .font(.headline)

      section(
        title: "Purpose",
        content: {
          Text(topic.purpose)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        }
      )

      section(
        title: "Key Fields",
        content: {
          bulletList(topic.keyFields)
        }
      )

      section(
        title: "Common Mistakes",
        content: {
          bulletList(topic.commonMistakes)
        }
      )

      section(
        title: "Next Step",
        content: {
          Text(topic.nextStepText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        }
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func section<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.subheadline.weight(.semibold))

      content()
    }
  }

  private func bulletList(
    _ items: [String]
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        Text("- \(item)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
