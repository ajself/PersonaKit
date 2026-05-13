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
            "v1-cli-guardrails"
          ],
          "allowedSkillIds": [
            "opencode-cli"
          ],
          "forbiddenSkillIds": [
            "autonomous-agent-loop"
          ]
        }

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/kits/v1-cli-guardrails.kit.json",
      contents:
        """
        {
          "id": "v1-cli-guardrails",
          "version": "1.0",
          "name": "V1 CLI Guardrails",
          "summary": "Guardrails for narrow PersonaKit V1 CLI work.",
          "essentialIds": [
            "v1-boundaries"
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
          "goal": "Complete one bounded CLI improvement without expanding PersonaKit's V1 scope.",
          "steps": [
            {
              "text": "Read the active contract and identify the requested change."
            },
            {
              "text": "Make the smallest implementation or documentation update that satisfies the task."
            },
            {
              "text": "Stop for review if the task requires new execution behavior, a new adapter, persistence, or orchestration.",
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
          "requiresSkillIds": [
            "opencode-cli"
          ]
        }

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/skills/opencode-cli.skill.json",
      contents:
        """
        {
          "id": "opencode-cli",
          "version": "1.0",
          "name": "OpenCode CLI",
          "description": "Use the local OpenCode CLI outside PersonaKit after PersonaKit resolves the operating contract.",
          "providedBy": [
            "opencode"
          ],
          "risk": {
            "level": "medium",
            "requiresHumanReview": true,
            "notes": [
              "PersonaKit resolves context; OpenCode performs the requested work."
            ]
          },
          "notes": [
            "PersonaKit V1 supports one explicitly selected agent adapter."
          ]
        }

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/skills/autonomous-agent-loop.skill.json",
      contents:
        """
        {
          "id": "autonomous-agent-loop",
          "version": "1.0",
          "name": "Autonomous Agent Loop",
          "description": "Long-running autonomous planning or execution loop.",
          "providedBy": [
            "unsupported"
          ],
          "risk": {
            "level": "high",
            "requiresHumanReview": true,
            "notes": [
              "Out of scope for PersonaKit V1."
            ]
          },
          "notes": [
            "Included only so the example can explicitly forbid this capability."
          ]
        }

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/essentials/v1-boundaries.md",
      contents:
        "# V1 Boundaries\n\nPersonaKit V1 resolves a deterministic operating contract and launches one explicitly selected supported agent adapter.\n\nStay inside these boundaries:\n\n- Use sessions as stable entry points.\n- Validate authored PersonaKit data before running work.\n- Use dry-run output to inspect the runtime payload before launching an agent.\n- Do not add workflow orchestration, memory, persistence, or multi-agent control flow.\n- Stop for human review before adding new execution behavior.\n"
        .utf8Data
    ),
    StarterFile(
      relativePath: "Sessions/solo-dev-v1.session.json",
      contents:
        """
        {
          "id": "solo-dev-v1",
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
