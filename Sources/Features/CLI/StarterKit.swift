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
          "requiresSkillIds": [],
          "referenceIds": [
            "cli-change-checklist"
          ]
        }

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/references/cli-change-checklist.reference.json",
      contents:
        """
        {
          "id": "cli-change-checklist",
          "version": "1.0",
          "name": "CLI Change Checklist",
          "summary": "Triggered checklist for small CLI changes. Edit the companion .md body, or author your own with `personakit create reference`.",
          "triggerRules": [
            {
              "pathGlobs": [
                "**/*.swift"
              ],
              "referenceTags": [
                "cli"
              ]
            }
          ]
        }

        """.utf8Data
    ),
    StarterFile(
      relativePath: "Packs/references/cli-change-checklist.md",
      contents:
        "# CLI Change Checklist\n\nThis reference body is surfaced when its trigger rules match (see `cli-change-checklist.reference.json`). A reference is a `.reference.json` metadata file paired with this `.md` body.\n\n- Confirm the change stays inside the requested CLI task.\n- Keep output ordering deterministic.\n- Add or update tests alongside the change.\n- Run `personakit validate` before handing off.\n\nReplace this checklist with your own guidance, or scaffold new references with `personakit create reference`.\n"
        .utf8Data
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
    StarterFile(
      relativePath: "personakit-grounding/SKILL.md",
      contents:
        """
        ---
        name: personakit-grounding
        description: Resolve PersonaKit or PK sessions before acting. Use when the user asks to operate under, resolve, inspect, recommend, trace, activate, export, or use a PersonaKit session or PK session; route through PersonaKit MCP or CLI contract resolution before reading raw .personakit or ~/.personakit files.
        ---

        # PersonaKit Grounding

        ## Purpose

        Use PersonaKit as the source of resolved contract truth. Do not crawl raw `.personakit` or `~/.personakit` JSON as the first step when a user asks to use, resolve, inspect, recommend, trace, activate, export, or operate under a PersonaKit session.

        This is a host-local skill. It helps an agent invoke PersonaKit correctly from a familiar skill, autocomplete, or command-palette surface. PersonaKit remains the authority for the operating contract.

        ## Trigger Phrases

        Treat these as PersonaKit-session intent:

        - "PersonaKit session" or "PK session"
        - "operate under ..."
        - "use the ... session"
        - "resolve contract"
        - "recommend a session"
        - "trace session"
        - "activate session"
        - "work from session"

        ## Required Workflow

        1. Identify the intended PersonaKit root and session id if the user supplied them.
        2. Prefer PersonaKit MCP resources and tools:
           - Read `personakit://catalog/start` if the client or scope is unfamiliar.
           - Read session catalog resources when listing or selecting sessions.
           - Call `personakit_recommend_session` when no session id is supplied.
           - Call `personakit_resolve_contract` for the selected session.
           - Call `personakit_trace_session` when provenance, source files, or dependency reasons matter.
           - Call `personakit_export` only when a human-readable grounding payload is needed.
        3. If MCP tools are unavailable, use the installed `personakit` executable for CLI fallback:
           - `personakit guidance`
           - `personakit list sessions`
           - `personakit recommend --goal "<task>"`
           - `personakit contract --session <id>`
           - `personakit contract --root <root> --session <id>` for repo-local session grounding
           - `personakit export --session <id>`
           - `personakit validate`
        4. Treat the resolved contract as authoritative for persona, directive, kits, essentials, skill authorization, stop points, and provenance.
        5. Continue the user's requested work only after the contract resolves cleanly.

        ## Host Skill vs PersonaKit Skill

        - This skill is a host skill: it tells the agent how to ground itself in PersonaKit.
        - PersonaKit skill declarations are contract metadata: they describe capabilities that a resolved session may allow, require, or forbid.
        - A host-local skill being available does not mean the PersonaKit contract authorizes its use.
        - If the resolved contract forbids or omits a needed capability, stop and ask for re-grounding, reassignment, or operator approval.

        ## Root Selection

        - Prefer an explicit root from the user.
        - If the user says global, personal, or does not specify a project-local root, use the configured/global PersonaKit root.
        - For repo-local PersonaKit grounding, use the project `.personakit` root only when the user asks for repo-local grounding or the task clearly depends on repo-local PersonaKit content.
        - If global and repo-local roots conflict, stop and ask which root should govern.

        Examples:

        - Explicit project root: resolve with `personakit contract --root <path> --session <id>`.
        - Repo-local request: use the current project's `.personakit` root when present and relevant.
        - Global/personal request: use the configured global root.
        - Ambiguous request with both project and global candidates: stop and ask which root governs.

        ## Raw File Access

        Read raw PersonaKit files only when:

        - The user asks to create, edit, or review PersonaKit content.
        - MCP or CLI resolution fails and file-level diagnostics are needed.
        - The task is explicitly pack authoring or schema/content maintenance.

        Even then, use MCP or CLI resolution first when possible so file reads are grounded by a failing or resolved contract.

        ## Stop Conditions

        Stop and report clearly when:

        - The requested session cannot be resolved.
        - PersonaKit MCP and CLI fallback are both unavailable.
        - The root is ambiguous and choosing one would change authority.
        - The task would mutate public behavior, adapters, runtime execution, memory, persistence, or orchestration without explicit approval.

        ## What This Skill Is Not

        - It does not execute PersonaKit-authored work.
        - It does not authorize a forbidden host skill, tool, write, command, deployment, or handoff.
        - It does not turn PersonaKit into an agent launcher, workflow engine, memory system, or orchestration layer.
        - It does not replace operator approval when the resolved contract requires a stop.

        ## Examples

        User: "Operate under the global staff-code-quality-review session and review Sources/Shared."

        Expected routing: resolve `staff-code-quality-review` from the global PersonaKit root through MCP or CLI, then perform the review under that contract. Do not inspect raw JSON first.

        User: "Use the pack-authoring session to draft a new PersonaKit session."

        Expected routing: resolve `pack-authoring`, then inspect or edit raw PersonaKit files only as part of the requested authoring work.

        User: "Recommend a PersonaKit session for Staff-level code review."

        Expected routing: call `personakit_recommend_session` or `personakit recommend --goal ...`; do not browse sessions by reading files first.

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
