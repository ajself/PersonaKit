import Foundation

/// Host-neutral capability vocabulary describing what a skill *does*, independent of
/// the concrete tool that provides it (which is captured by `Skill.providedBy`).
///
/// The vocabulary is intentionally small and closed so capability declarations travel
/// between hosts without drift. The raw values are mirrored by the `enum` constraint in
/// `skill.schema.json`; ``skillCapabilityVocabularyMatchesSchema`` guards them in sync.
public enum SkillCapability: String, CaseIterable, Sendable {
  /// Reads files, docs, or state and runs non-mutating commands; never edits sources.
  case readOnlyInspection = "read-only-inspection"

  /// Modifies repository files.
  case editFiles = "edit-files"

  /// Executes shell, build, test, or tooling commands.
  case runCommands = "run-commands"

  /// Makes outbound network requests.
  case networkAccess = "network-access"

  /// Runs unattended or iterative control flow without per-step review.
  case autonomousLoop = "autonomous-loop"

  /// The full vocabulary as sorted raw values.
  public static let vocabulary: [String] = allCases.map(\.rawValue).sorted()

  /// Whether a raw capability string is part of the known vocabulary.
  public static func isKnown(_ value: String) -> Bool {
    SkillCapability(rawValue: value) != nil
  }
}
