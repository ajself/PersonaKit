import Foundation

/// Initializes a destination directory with a starter PersonaKit pack set.
struct PersonaKitInitializer {
  /// Validates and initializes the given destination.
  ///
  /// - Parameter destination: Destination path to initialize.
  /// - Parameter force: Whether to replace an existing non-empty destination.
  /// - Throws: `InitError` when validation fails, or file-system errors during writing.
  func run(destination: String, force: Bool = false) throws {
    let destinationURL = try DestinationValidator().validate(path: destination)
    try StarterKitWriter().write(to: destinationURL, force: force)
  }
}

/// Writes the starter PersonaKit manifest to disk.
struct StarterKitWriter {
  private let fileManager = FileManager.default

  /// Creates the destination directory and writes all starter files atomically.
  ///
  /// - Parameter destination: Directory where the starter content is written.
  /// - Parameter force: Whether to replace an existing non-empty destination.
  /// - Throws: Any error produced while removing, creating, or writing files.
  func write(to destination: URL, force: Bool = false) throws {
    if fileManager.fileExists(atPath: destination.path) {
      guard force || isEmptyDirectory(destination) else {
        throw InitError.destinationExists(destination.path)
      }

      try fileManager.removeItem(at: destination)
    }

    do {
      try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
      for entry in StarterKitManifest.entries {
        let fileURL = destination.appendingPathComponent(entry.relativePath)
        try fileManager.createDirectory(
          at: fileURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try entry.contents.write(to: fileURL, options: .atomic)
      }
    } catch {
      try? fileManager.removeItem(at: destination)
      throw error
    }
  }

  private func isEmptyDirectory(_ destination: URL) -> Bool {
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return false
    }

    let contents = (try? fileManager.contentsOfDirectory(atPath: destination.path)) ?? []

    return contents.isEmpty
  }
}

/// Validates initialization destinations before starter content is written.
struct DestinationValidator {
  private let fileManager = FileManager.default

  /// Expands and validates a destination path for safe initialization.
  ///
  /// - Parameter path: User-provided path string.
  /// - Returns: A standardized absolute destination URL.
  /// - Throws: `InitError` when the input path is empty or unsafe.
  func validate(path: String) throws -> URL {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw InitError.emptyPath
    }

    let expanded = (trimmed as NSString).expandingTildeInPath
    let absolutePath: String
    if expanded.hasPrefix("/") {
      absolutePath = expanded
    } else {
      absolutePath = (fileManager.currentDirectoryPath as NSString)
        .appendingPathComponent(expanded)
    }

    let destination = URL(fileURLWithPath: absolutePath).standardizedFileURL
    let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL

    if destination.path == "/" {
      throw InitError.disallowedPath(destination.path)
    }

    if destination.path == home.path {
      throw InitError.disallowedPath(destination.path)
    }

    return destination
  }
}

/// Errors produced while validating or initializing starter directories.
enum InitError: Error, Equatable {
  /// The destination path is empty after trimming whitespace.
  case emptyPath
  /// The destination path resolves to a location that must not be initialized.
  case disallowedPath(String)
  /// The destination already exists and contains files.
  case destinationExists(String)

  /// Human-readable error description for CLI output.
  var description: String {
    switch self {
    case .emptyPath:
      return "Destination path is required."
    case .disallowedPath(let path):
      return "Refusing to initialize at unsafe destination: \(path)"
    case .destinationExists(let path):
      return "Refusing to replace non-empty destination without --force: \(path)"
    }
  }
}

extension InitError: LocalizedError {
  var errorDescription: String? {
    description
  }
}

/// A single file entry included in the starter manifest.
struct StarterFile: Equatable {
  /// File path relative to the root destination.
  let relativePath: String
  /// UTF-8 file contents to write at `relativePath`.
  let contents: Data
}

/// In-repo starter content used by `personakit init`.
enum StarterKitManifest {
  /// Ordered starter files written into a freshly initialized PersonaKit root.
  static let entries: [StarterFile] = [
    StarterFile(
      relativePath: "README.md",
      contents:
        """
        # PersonaKit Authored Source

        This directory contains PersonaKit authored source.

        Do not use these files as normal agent operating context. For agent startup, resolve a session through PersonaKit MCP or CLI:

        - MCP: read `personakit://catalog/start`, then resolve the intended session.
        - CLI: run `personakit guidance`, then `personakit contract --root .personakit --session <id>` or `personakit export --root .personakit --session <id>`.

        Read raw files here only for PersonaKit authoring, validation failures, or resolver diagnostics.

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/personas/solo-developer.persona.json",
      contents:
        """
        {
          "id": "solo-developer",
          "version": "1.0",
          "name": "Solo Developer",
          "summary": "CLI-first developer who keeps changes small, explicit, and reviewable.",
          "responsibilities": [
            "Resolve the active operating contract before starting work",
            "Keep implementation changes scoped to the requested task",
            "Preserve deterministic behavior and clear verification steps"
          ],
          "values": [
            "explicit over inferred",
            "small diffs",
            "deterministic output",
            "human review"
          ],
          "nonGoals": [
            "workflow orchestration",
            "memory systems",
            "multi-agent control flows"
          ],
          "defaultKitIds": [
            "cli-guardrails"
          ],
          "allowedSkillIds": [],
          "forbiddenSkillIds": []
        }

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/kits/cli-guardrails.kit.json",
      contents:
        """
        {
          "id": "cli-guardrails",
          "version": "1.0",
          "name": "CLI Guardrails",
          "summary": "Guardrails for narrow PersonaKit CLI work.",
          "essentialIds": [
            "contract-boundaries"
          ]
        }

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/directives/small-cli-change.directive.json",
      contents:
        """
        {
          "id": "small-cli-change",
          "version": "1.0",
          "title": "Make a small CLI change",
          "goal": "Complete one bounded CLI improvement without expanding PersonaKit's supported scope.",
          "steps": [
            {
              "text": "Read the active contract and identify the requested change."
            },
            {
              "text": "Make the smallest implementation or documentation update that satisfies the task."
            },
            {
              "text": "Stop for review if the task requires new execution behavior, persistence, or orchestration.",
              "requiresReview": true
            },
            {
              "text": "Verify the change and summarize the result."
            }
          ],
          "acceptanceCriteria": [
            "The change stays inside the requested CLI task",
            "No new autonomous execution behavior is introduced",
            "Output ordering remains deterministic",
            "Verification steps are reported"
          ],
          "verification": [
            {
              "kind": "command",
              "text": "swift test"
            },
            {
              "kind": "command",
              "text": "swift run personakit validate"
            }
          ],
          "requiresIntentTemplateIds": [],
          "requiresSkillIds": []
        }

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/essentials/contract-boundaries.md",
      contents:
        "# Contract Boundaries\n\nPersonaKit resolves a deterministic operating contract and exports handoff context for another coding tool.\n\nStay inside these boundaries:\n\n- Use sessions as stable entry points.\n- Validate authored PersonaKit data before handing context to another tool.\n- Use `personakit contract` to inspect structured resolution output.\n- Use `personakit export` to produce handoff context.\n- Do not add workflow orchestration, memory, persistence, or multi-agent control flow.\n- Stop for human review before adding new execution behavior.\n"
        .utf8Data
    ),
    StarterFile(
      relativePath: "Sessions/solo-dev.session.json",
      contents:
        """
        {
          "id": "solo-dev",
          "personaId": "solo-developer",
          "directiveId": "small-cli-change"
        }

        """.utf8Data
    ),
  ]
}

extension String {
  /// UTF-8 encoded data representation of the string.
  fileprivate var utf8Data: Data {
    Data(self.utf8)
  }
}
