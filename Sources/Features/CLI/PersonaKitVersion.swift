import Foundation

/// Version metadata for the PersonaKit toolchain.
enum PersonaKitVersion {
  /// Current semantic version for this build.
  ///
  /// Must match `RELEASE_VERSION` in the Makefile (the canonical release
  /// version). `make version-check` enforces this and runs as part of
  /// `cli-install` and the release preflight, so drift fails fast instead of
  /// shipping a stale `--version`.
  static let current = "1.0.0"
}
