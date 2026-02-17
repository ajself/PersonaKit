import SwiftUI

/// Compact, non-modal entry point for contextual section help.
struct StudioHelpHintChipView: View {
  let hintText: String
  @Binding var isExpanded: Bool

  var body: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        isExpanded.toggle()
      }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "info.circle")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        Text(hintText)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(2)

        Spacer(minLength: 8)

        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Section Help")
    .accessibilityHint("Shows contextual guidance for this section.")
    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
  }
}
