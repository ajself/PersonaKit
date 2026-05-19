import SwiftUI

/// Section-local search field for Studio lists and review surfaces.
struct StudioSearchField: View {
  @Binding var text: String
  let prompt: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      TextField(prompt, text: $text)
        .textFieldStyle(.plain)
        .lineLimit(1)
        .accessibilityLabel(prompt)

      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear \(prompt)")
        .help("Clear \(prompt)")
      }
    }
    .font(.subheadline)
    .controlSize(.small)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(.quaternary.opacity(0.16))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(.quaternary.opacity(0.6), lineWidth: 1)
    )
  }
}
