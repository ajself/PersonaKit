import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Session map detail content with layered dependency visualization.
struct SessionsMapTabView: View {
  let selectedSession: WorkspaceSessionListItem
  let sessionMap: WorkspaceSessionMap?
  let sessionMapErrorMessage: String?
  let isLoadingSessionMap: Bool
  let snapshot: WorkspaceSnapshot
  let onNavigateToDiagnostics: () -> Void
  let onSelectNode: (WorkspaceSessionMapNode) -> Void

  @State private var highlightedNodeKey: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if isLoadingSessionMap {
        VStack(spacing: 10) {
          ProgressView()

          Text("Loading map...")
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let sessionMapErrorMessage {
        ContentUnavailableView(
          "Map Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(sessionMapErrorMessage)
        )
      } else if let sessionMap {
        VStack(alignment: .leading, spacing: 10) {
          SessionDependencyMapView(
            map: sessionMap,
            scopeByNodeKey: scopeByNodeKey,
            highlightedNodeKey: highlightedNodeKey,
            compact: false,
            onSelectNode: { node in
              highlightedNodeKey = node.key
              onSelectNode(node)
            }
          )
          .frame(minHeight: 320)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(.quaternary.opacity(0.18))
          )

          if !sessionMap.resolutionErrors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Relationship Issues")
                .font(.headline)

              ForEach(Array(sessionMap.resolutionErrors.enumerated()), id: \.offset) { _, issue in
                issueRow(issue: issue, map: sessionMap)
              }
            }
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.08))
            )
          }
        }
      } else {
        ContentUnavailableView(
          "No Map",
          systemImage: "point.topleft.down.curvedto.point.bottomright.up",
          description: Text("Generate a map for the selected session.")
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
  }

  private var scopeByNodeKey: [String: WorkspaceSourceScope] {
    var scopes: [String: WorkspaceSourceScope] = [:]

    for session in snapshot.sessions {
      scopes["session:\(session.id)"] = session.sourceScope
    }

    for persona in snapshot.personas {
      scopes["persona:\(persona.id)"] = persona.sourceScope
    }

    for directive in snapshot.directives {
      scopes["directive:\(directive.id)"] = directive.sourceScope
    }

    for kit in snapshot.kits {
      scopes["kit:\(kit.id)"] = kit.sourceScope
    }

    for intent in snapshot.intents {
      scopes["intent:\(intent.id)"] = intent.sourceScope
    }

    for skill in snapshot.skills {
      scopes["skill:\(skill.id)"] = skill.sourceScope
    }

    for essential in snapshot.essentials {
      scopes["essential:\(essential.id)"] = essential.sourceScope
    }

    scopes["session:active-session"] = selectedSession.sourceScope

    return scopes
  }

  private func issueRow(
    issue: ResolverError,
    map: WorkspaceSessionMap
  ) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text(issueDescription(issue))
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let nodeKey = nodeKey(for: issue),
        map.nodes.contains(where: { $0.key == nodeKey })
      {
        Button("Go to Node") {
          highlightedNodeKey = nodeKey
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }

      Button("Go to Diagnostics") {
        onNavigateToDiagnostics()
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }

  private func issueDescription(_ issue: ResolverError) -> String {
    switch issue {
    case .missingPersona(let field, let id):
      return "Session \(field) references missing persona \"\(id)\"."
    case .missingDirective(let field, let id):
      return "Session \(field) references missing directive \"\(id)\"."
    case .missingKitId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing kit \"\(missingId)\"."
    case .missingIntentId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing intent \"\(missingId)\"."
    case .missingSkillId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing skill \"\(missingId)\"."
    case .conflictingPersonaSkillId(let sourceId, _, let missingId):
      return "persona \(sourceId) lists skill \"\(missingId)\" in both allowed and forbidden sets."
    case .unauthorizedSkillId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) requires unauthorized skill \"\(missingId)\"."
    case .missingEssentialFile(let sourceType, let sourceId, let field, let missingId, _):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing essential \"\(missingId)\"."
    case .missingReferenceId(let sourceType, let sourceId, let field, let missingId):
      return "\(sourceType.rawValue) \(sourceId) \(field) references missing reference \"\(missingId)\"."
    }
  }

  private func nodeKey(for issue: ResolverError) -> String? {
    switch issue {
    case .missingPersona(_, let id):
      return "persona:\(id)"
    case .missingDirective(_, let id):
      return "directive:\(id)"
    case .missingKitId(_, _, _, let missingID):
      return "kit:\(missingID)"
    case .missingIntentId(_, _, _, let missingID):
      return "intent:\(missingID)"
    case .missingSkillId(_, _, _, let missingID):
      return "skill:\(missingID)"
    case .conflictingPersonaSkillId(let sourceId, _, _):
      return "persona:\(sourceId)"
    case .unauthorizedSkillId(_, _, _, let missingID):
      return "skill:\(missingID)"
    case .missingEssentialFile(_, _, _, let missingID, _):
      return "essential:\(missingID)"
    case .missingReferenceId(_, _, _, let missingID):
      return "reference:\(missingID)"
    }
  }
}
