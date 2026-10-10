import ContextWorkspaceCore
import SwiftUI

/// Shared layout and color tokens for Studio views.
enum StudioDesign {
  enum Radius {
    static let card = CGFloat(8)
  }

  /// Fill opacity for tinted badges and highlights.
  static let tintOpacity = 0.16
}

/// Semantic color for a Studio badge.
enum StudioBadgeTone {
  case neutral
  case accent
  case success
  case warning

  fileprivate var fill: Color {
    switch self {
    case .neutral:
      return .secondary
    case .accent:
      return .blue
    case .success:
      return .green
    case .warning:
      return .orange
    }
  }

  /// Status tones color their text; neutral recedes and accent keeps primary text.
  fileprivate var foreground: Color {
    switch self {
    case .neutral:
      return .secondary
    case .accent:
      return .primary
    case .success:
      return .green
    case .warning:
      return .orange
    }
  }
}

/// Capsule label used for scopes, statuses, and counts.
struct StudioBadge: View {
  enum Size {
    /// Inline with a row title: scope, unsaved, node flags.
    case small
    /// Section headers and summaries: status and stat counts.
    case regular
  }

  let title: String
  var tone = StudioBadgeTone.neutral
  var size = Size.small

  var body: some View {
    Text(title)
      .font(size == .small ? .caption2 : .caption)
      .fontWeight(.semibold)
      .padding(.horizontal, size == .small ? 6 : 8)
      .padding(.vertical, size == .small ? 2 : 4)
      .background(
        Capsule()
          .fill(tone.fill.opacity(StudioDesign.tintOpacity))
      )
      .foregroundStyle(tone.foreground)
  }
}

/// Project or Global source badge.
struct StudioScopeBadge: View {
  let scope: WorkspaceSourceScope

  var body: some View {
    StudioBadge(
      title: scope.displayName,
      tone: scope == .project ? .accent : .neutral
    )
    .accessibilityLabel("\(scope.displayName) scope")
  }
}

/// Titled group of rows in an inspector column.
struct StudioInspectorSection<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  init(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 10) {
        content
      }
    }
  }
}

/// Label-over-value row in an inspector column.
struct StudioMetadataRow: View {
  let label: String
  let value: String
  var monospaced = false

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      Text(value)
        .font(monospaced ? .caption.monospaced() : .subheadline)
        .foregroundStyle(.primary)
        .lineLimit(monospaced ? 3 : 4)
        .truncationMode(monospaced ? .middle : .tail)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }
}

/// Two-line list row: a title with a trailing scope badge, then a secondary line.
struct StudioListRow: View {
  let title: String
  let subtitle: String?
  let scope: WorkspaceSourceScope

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title)
          .font(.headline)
          .lineLimit(1)
          .truncationMode(.middle)

        Spacer(minLength: 4)

        StudioScopeBadge(scope: scope)
      }

      if let subtitle {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
      }
    }
    .padding(.vertical, 3)
    .accessibilityElement(children: .combine)
  }
}
