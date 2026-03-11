import Foundation

/// Deterministic workstream-doc projections derived from directive metadata.
public struct WorkstreamDocsCatalog: Equatable, Sendable {
  /// Canonical workstream projection shared by generated docs.
  public struct Workstream: Equatable, Sendable {
    public let id: String
    public let representativeDirectiveId: String
    public let directiveIds: [String]
    public let entrySessionId: String
    public let requiredCloseoutSessionId: String?
    public let nodes: [Directive.Workstream.Node]
    public let edges: [Directive.Workstream.Edge]

    public init(
      id: String,
      representativeDirectiveId: String,
      directiveIds: [String],
      entrySessionId: String,
      requiredCloseoutSessionId: String?,
      nodes: [Directive.Workstream.Node],
      edges: [Directive.Workstream.Edge]
    ) {
      self.id = id
      self.representativeDirectiveId = representativeDirectiveId
      self.directiveIds = directiveIds
      self.entrySessionId = entrySessionId
      self.requiredCloseoutSessionId = requiredCloseoutSessionId
      self.nodes = nodes
      self.edges = edges
    }
  }

  /// Row rendered into the hybrid session-directory membership block.
  public struct Membership: Equatable, Sendable {
    public let sessionId: String
    public let workstreamId: String
    public let phase: String
    public let entrySessionId: String
    public let requiredCloseoutSessionId: String?

    public init(
      sessionId: String,
      workstreamId: String,
      phase: String,
      entrySessionId: String,
      requiredCloseoutSessionId: String?
    ) {
      self.sessionId = sessionId
      self.workstreamId = workstreamId
      self.phase = phase
      self.entrySessionId = entrySessionId
      self.requiredCloseoutSessionId = requiredCloseoutSessionId
    }
  }

  public let workstreams: [Workstream]
  public let memberships: [Membership]

  public init(
    workstreams: [Workstream],
    memberships: [Membership]
  ) {
    self.workstreams = workstreams
    self.memberships = memberships
  }
}

/// Full generated operator-doc payload for the workstream-docs command.
public struct WorkstreamDocsOutput: Equatable, Sendable {
  public let workstreamDirectory: String
  public let sessionDirectory: String

  public init(
    workstreamDirectory: String,
    sessionDirectory: String
  ) {
    self.workstreamDirectory = workstreamDirectory
    self.sessionDirectory = sessionDirectory
  }
}

/// Errors produced while generating or applying workstream-doc projections.
public enum WorkstreamDocsError: LocalizedError, Equatable {
  case inconsistentWorkstreams([ValidationError])
  case missingSessionDirectoryMarkers
  case duplicatedSessionDirectoryMarkers
  case missingWorkstreamSessionFile(String)
  case invalidWorkstreamSessionFile(String)

  public var errorDescription: String? {
    switch self {
    case .inconsistentWorkstreams(let errors):
      return errors.map(\.message).joined(separator: "\n")
    case .missingSessionDirectoryMarkers:
      return "Session directory is missing required workstream membership markers."
    case .duplicatedSessionDirectoryMarkers:
      return "Session directory contains duplicate workstream membership markers."
    case .missingWorkstreamSessionFile(let sessionId):
      return "Missing session file for workstream session id \"\(sessionId)\"."
    case .invalidWorkstreamSessionFile(let sessionId):
      return "Failed to load workstream session id \"\(sessionId)\"."
    }
  }
}

/// Shared builder and renderer for generated workstream operator docs.
public enum WorkstreamDocsBuilder {
  public static let workstreamDirectoryRelativePath =
    "Docs/PersonaKit/Development/workstream-directory.md"
  public static let sessionDirectoryRelativePath =
    "Docs/PersonaKit/Development/session-directory.md"
  public static let membershipStartMarker = "<!-- WORKSTREAM_MEMBERSHIP:START -->"
  public static let membershipEndMarker = "<!-- WORKSTREAM_MEMBERSHIP:END -->"

  /// Builds the normalized catalog used by validation and doc generation.
  public static func buildCatalog(
    root: URL,
    fileManager: FileManager = .default
  ) throws -> WorkstreamDocsCatalog {
    let registry = try Registry.load(root: root, fileManager: fileManager)
    return try buildCatalog(
      directives: registry.directives,
      root: root,
      fileManager: fileManager
    )
  }

  /// Builds the two generated docs using the current manual session directory.
  public static func buildOutput(
    root: URL,
    currentSessionDirectory: String,
    fileManager: FileManager = .default
  ) throws -> WorkstreamDocsOutput {
    let catalog = try buildCatalog(root: root, fileManager: fileManager)
    let workstreamDirectory = renderWorkstreamDirectory(catalog: catalog)
    let membershipSection = renderSessionMembershipSection(catalog: catalog)
    let sessionDirectory = try replacingMembershipSection(
      in: currentSessionDirectory,
      with: membershipSection
    )

    return WorkstreamDocsOutput(
      workstreamDirectory: workstreamDirectory,
      sessionDirectory: sessionDirectory
    )
  }

  /// Returns cross-directive workstream consistency errors.
  public static func consistencyErrors(
    directives: [Directive]
  ) -> [ValidationError] {
    let grouped = Dictionary(
      grouping: directives.compactMap { directive in
        directive.workstream.map {
          GroupedDirective(
            directiveId: directive.id,
            workstream: $0
          )
        }
      },
      by: \.workstream.id
    )

    var errors: [ValidationError] = []

    for workstreamId in grouped.keys.sorted() {
      guard let groupedDirectives = grouped[workstreamId] else {
        continue
      }

      let sortedDirectives = groupedDirectives.sorted { lhs, rhs in
        lhs.directiveId < rhs.directiveId
      }
      guard let representative = sortedDirectives.first else {
        continue
      }

      let directiveIDs = sortedDirectives.map(\.directiveId)
      let normalizedNodes = normalizedNodesKey(representative.workstream.nodes)
      let normalizedEdges = normalizedEdgesKey(representative.workstream.edges)
      let entrySessionId = representative.workstream.entrySessionId
      let requiredCloseoutSessionId = representative.workstream.requiredCloseoutSessionId

      let mismatchedNodeDirectives = sortedDirectives.filter {
        normalizedNodesKey($0.workstream.nodes) != normalizedNodes
      }
      if !mismatchedNodeDirectives.isEmpty {
        errors.append(
          makeConsistencyError(
            representativeDirectiveId: representative.directiveId,
            workstreamId: workstreamId,
            directiveIDs: directiveIDs,
            field: "workstream.nodes",
            message:
              "Workstream id \"\(workstreamId)\" has inconsistent node sets across directives."
          )
        )
      }

      let mismatchedEdgeDirectives = sortedDirectives.filter {
        normalizedEdgesKey($0.workstream.edges) != normalizedEdges
      }
      if !mismatchedEdgeDirectives.isEmpty {
        errors.append(
          makeConsistencyError(
            representativeDirectiveId: representative.directiveId,
            workstreamId: workstreamId,
            directiveIDs: directiveIDs,
            field: "workstream.edges",
            message:
              "Workstream id \"\(workstreamId)\" has inconsistent edge sets across directives."
          )
        )
      }

      let mismatchedEntryDirectives = sortedDirectives.filter {
        $0.workstream.entrySessionId != entrySessionId
      }
      if !mismatchedEntryDirectives.isEmpty {
        errors.append(
          makeConsistencyError(
            representativeDirectiveId: representative.directiveId,
            workstreamId: workstreamId,
            directiveIDs: directiveIDs,
            field: "workstream.entrySessionId",
            message:
              "Workstream id \"\(workstreamId)\" has inconsistent entry session ids across directives."
          )
        )
      }

      let mismatchedCloseoutDirectives = sortedDirectives.filter {
        $0.workstream.requiredCloseoutSessionId != requiredCloseoutSessionId
      }
      if !mismatchedCloseoutDirectives.isEmpty {
        errors.append(
          makeConsistencyError(
            representativeDirectiveId: representative.directiveId,
            workstreamId: workstreamId,
            directiveIDs: directiveIDs,
            field: "workstream.requiredCloseoutSessionId",
            message:
              "Workstream id \"\(workstreamId)\" has inconsistent required closeout session ids across directives."
          )
        )
      }
    }

    return errors
  }

  /// Renders the fully generated workstream directory.
  public static func renderWorkstreamDirectory(
    catalog: WorkstreamDocsCatalog
  ) -> String {
    var lines: [String] = [
      "# Workstream Directory",
      "",
      "> Generated file. Do not edit manually.",
      "> Source of truth: directive-owned workstream metadata in `.personakit/Packs/directives/`.",
      "",
      "This directory is a committed projection over directive workstream metadata.",
      "Regenerate it with `swift run personakit workstream-docs --root .personakit --write`.",
      "",
      "## Active Workstreams",
      "",
    ]

    guard !catalog.workstreams.isEmpty else {
      lines.append("_No workstream metadata is currently declared._")
      lines.append("")
      return lines.joined(separator: "\n")
    }

    for (index, workstream) in catalog.workstreams.enumerated() {
      if index > 0 {
        lines.append("")
      }

      lines.append("### \(workstream.id)")
      lines.append("")
      lines.append("- Entry session: `\(workstream.entrySessionId)`")
      lines.append(
        "- Required closeout session: `\(displayValue(workstream.requiredCloseoutSessionId))`"
      )
      lines.append("")
      lines.append("Session map:")
      lines.append("")
      for node in workstream.nodes {
        lines.append("- `\(node.phase)` -> `\(node.sessionId)`")
      }
      lines.append("")
      lines.append("Edge map:")
      lines.append("")
      for edge in workstream.edges {
        lines.append(
          "- `\(edge.fromSessionId)` -> `\(edge.toSessionId)` (`\(edge.kind)`)"
        )
      }
      lines.append("")
      lines.append("Participating sessions:")
      lines.append("")
      for node in workstream.nodes {
        lines.append("- `\(node.sessionId)`")
      }
    }

    lines.append("")
    return lines.joined(separator: "\n")
  }

  /// Renders the generator-owned membership block for session-directory.md.
  public static func renderSessionMembershipSection(
    catalog: WorkstreamDocsCatalog
  ) -> String {
    var lines: [String] = [
      membershipStartMarker,
      "## Workstream Membership",
      "",
    ]

    guard !catalog.memberships.isEmpty else {
      lines.append("_No workstream memberships are currently declared._")
      lines.append(membershipEndMarker)
      return lines.joined(separator: "\n")
    }

    lines.append(
      "| Session ID | Workstream ID | Phase | Entry Session | Required Closeout Session | Directory Ref |"
    )
    lines.append("| --- | --- | --- | --- | --- | --- |")

    for membership in catalog.memberships {
      let link =
        "[\(membership.workstreamId)](./workstream-directory.md#\(membership.workstreamId))"
      lines.append(
        "| `\(membership.sessionId)` | `\(membership.workstreamId)` | `\(membership.phase)` | `\(membership.entrySessionId)` | `\(displayValue(membership.requiredCloseoutSessionId))` | \(link) |"
      )
    }

    lines.append(membershipEndMarker)
    return lines.joined(separator: "\n")
  }

  /// Replaces the generator-owned membership block inside the hybrid session directory.
  public static func replacingMembershipSection(
    in document: String,
    with membershipSection: String
  ) throws -> String {
    let startMarkers = ranges(
      of: membershipStartMarker,
      in: document
    )
    let endMarkers = ranges(
      of: membershipEndMarker,
      in: document
    )

    guard !startMarkers.isEmpty, !endMarkers.isEmpty else {
      throw WorkstreamDocsError.missingSessionDirectoryMarkers
    }

    guard startMarkers.count == 1, endMarkers.count == 1 else {
      throw WorkstreamDocsError.duplicatedSessionDirectoryMarkers
    }

    guard
      let startRange = startMarkers.first,
      let endRange = endMarkers.first,
      startRange.lowerBound < endRange.upperBound
    else {
      throw WorkstreamDocsError.duplicatedSessionDirectoryMarkers
    }

    let prefix = String(document[..<startRange.lowerBound]).trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let suffix = String(document[endRange.upperBound...]).trimmingCharacters(
      in: .whitespacesAndNewlines
    )

    var parts: [String] = []
    if !prefix.isEmpty {
      parts.append(prefix)
    }
    parts.append(membershipSection)
    if !suffix.isEmpty {
      parts.append(suffix)
    }

    return parts.joined(separator: "\n\n") + "\n"
  }

  private static func buildCatalog(
    directives: [Directive],
    root: URL,
    fileManager: FileManager
  ) throws -> WorkstreamDocsCatalog {
    let errors = consistencyErrors(directives: directives)
    guard errors.isEmpty else {
      throw WorkstreamDocsError.inconsistentWorkstreams(errors)
    }

    let grouped = Dictionary(
      grouping: directives.compactMap { directive in
        directive.workstream.map {
          GroupedDirective(
            directiveId: directive.id,
            workstream: $0
          )
        }
      },
      by: \.workstream.id
    )

    var workstreams: [WorkstreamDocsCatalog.Workstream] = []
    var memberships: [WorkstreamDocsCatalog.Membership] = []

    for workstreamId in grouped.keys.sorted() {
      guard let groupedDirectives = grouped[workstreamId] else {
        continue
      }

      let representative = groupedDirectives.sorted { lhs, rhs in
        lhs.directiveId < rhs.directiveId
      }[0]

      for node in representative.workstream.nodes {
        do {
          _ = try SessionFileLoader.load(
            root: root,
            sessionId: node.sessionId,
            fileManager: fileManager
          )
        } catch let error as SessionFileError {
          switch error {
          case .notFound:
            throw WorkstreamDocsError.missingWorkstreamSessionFile(node.sessionId)
          default:
            throw WorkstreamDocsError.invalidWorkstreamSessionFile(node.sessionId)
          }
        }
      }

      let directiveIds =
        groupedDirectives
        .map(\.directiveId)
        .sorted()

      workstreams.append(
        WorkstreamDocsCatalog.Workstream(
          id: workstreamId,
          representativeDirectiveId: representative.directiveId,
          directiveIds: directiveIds,
          entrySessionId: representative.workstream.entrySessionId,
          requiredCloseoutSessionId: representative.workstream.requiredCloseoutSessionId,
          nodes: representative.workstream.nodes,
          edges: representative.workstream.edges
        )
      )

      memberships.append(
        contentsOf: representative.workstream.nodes.map { node in
          WorkstreamDocsCatalog.Membership(
            sessionId: node.sessionId,
            workstreamId: workstreamId,
            phase: node.phase,
            entrySessionId: representative.workstream.entrySessionId,
            requiredCloseoutSessionId: representative.workstream.requiredCloseoutSessionId
          )
        }
      )
    }

    let sortedMemberships = memberships.sorted { lhs, rhs in
      if lhs.sessionId != rhs.sessionId {
        return lhs.sessionId < rhs.sessionId
      }

      if lhs.workstreamId != rhs.workstreamId {
        return lhs.workstreamId < rhs.workstreamId
      }

      return lhs.phase < rhs.phase
    }

    return WorkstreamDocsCatalog(
      workstreams: workstreams,
      memberships: sortedMemberships
    )
  }

  private static func displayValue(_ value: String?) -> String {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? "none" : trimmed
  }

  private static func normalizedNodesKey(
    _ nodes: [Directive.Workstream.Node]
  ) -> [String] {
    nodes
      .map { "\($0.phase)|\($0.sessionId)" }
      .sorted()
  }

  private static func normalizedEdgesKey(
    _ edges: [Directive.Workstream.Edge]
  ) -> [String] {
    edges
      .map { "\($0.fromSessionId)|\($0.toSessionId)|\($0.kind)" }
      .sorted()
  }

  private static func makeConsistencyError(
    representativeDirectiveId: String,
    workstreamId: String,
    directiveIDs: [String],
    field: String,
    message: String
  ) -> ValidationError {
    ValidationError(
      entityType: .directive,
      entityId: representativeDirectiveId,
      field: field,
      missingId: workstreamId,
      expectedPath: nil,
      message: message + " Conflicting directives: \(directiveIDs.joined(separator: ", "))."
    )
  }

  private static func ranges(
    of substring: String,
    in document: String
  ) -> [Range<String.Index>] {
    var result: [Range<String.Index>] = []
    var searchStart = document.startIndex

    while searchStart < document.endIndex,
      let range = document.range(
        of: substring,
        range: searchStart..<document.endIndex
      )
    {
      result.append(range)
      searchStart = range.upperBound
    }

    return result
  }
}

private struct GroupedDirective {
  let directiveId: String
  let workstream: Directive.Workstream
}
