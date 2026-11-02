/// Centralized contextual help catalog for Studio sections.
enum StudioHelpCatalog {
  static func topic(
    for topicID: StudioHelpTopicID
  ) -> StudioHelpTopic? {
    switch topicID {
    case .directives:
      return StudioHelpTopic(
        id: .directives,
        title: "Directives Help",
        shortHint: "Directives define what work should happen right now.",
        purpose:
          "Directives are explicit task contracts that keep AI work scoped, reviewable, and behavior-preserving when needed.",
        keyFields: [
          "Use the id as a stable reference from sessions.",
          "Keep steps concrete and ordered.",
          "Write acceptance criteria that are testable.",
          "Workstream metadata is routing context only, not runtime automation.",
        ],
        commonMistakes: [
          "Using vague goals without concrete completion criteria.",
          "Mixing multiple unrelated tasks into one directive.",
          "Forgetting to include explicit stop/review points.",
          "Treating workstream metadata as something PersonaKit runs.",
        ],
        examples: [
          "Example directive: \"Refactor handoff context caching without changing export behavior.\"",
          "Example routing note: a directive can declare a workstream id and phase so the next session is visible without executing anything.",
        ],
        nextStepText: "Link this directive from a session, then inspect its handoff context and map before saving.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil),
          StudioHelpLink(label: "Go to Validation Results", destination: .validationResults, searchText: nil),
        ]
      )

    case .kits:
      return StudioHelpTopic(
        id: .kits,
        title: "Kits Help",
        shortHint: "Kits bundle skill ids that related sessions share.",
        purpose:
          "A kit bundles the skills a group of sessions shares, so personas and sessions can pull them in by one id instead of listing each skill.",
        keyFields: [
          "Use the id as a stable reference from personas and session kit overrides.",
          "List the skills the kit requires in Skill IDs.",
          "Keep kit overrides intentional and minimal.",
        ],
        commonMistakes: [
          "Packing unrelated skills into one giant kit.",
          "Expecting a kit to add rules that none of its skills carry.",
          "Creating duplicate kits with slight wording differences.",
        ],
        examples: [
          "Example kit: \"swiftui-style\" requiring the formatting, testing, and accessibility skills."
        ],
        nextStepText:
          "Check Used by in the inspector to see what relies on this kit, then confirm it in Validation Results.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil),
          StudioHelpLink(label: "Go to Validation Results", destination: .validationResults, searchText: nil),
        ]
      )

    case .personas:
      return StudioHelpTopic(
        id: .personas,
        title: "Personas Help",
        shortHint: "Personas define who the agent is acting as.",
        purpose:
          "Personas establish role boundaries, values, and non-goals so outputs reflect a consistent professional perspective.",
        keyFields: [
          "Keep id stable and human-readable.",
          "Document responsibilities and values clearly.",
          "List non-goals to prevent scope drift.",
        ],
        commonMistakes: [
          "Using vague role descriptions without boundaries.",
          "Combining multiple roles into one persona.",
          "Omitting non-goals and escalation guidance.",
        ],
        examples: [
          "Example persona: \"Senior SwiftUI Engineer\" with explicit responsibilities and non-goals."
        ],
        nextStepText:
          "Pair this persona with a directive in Sessions and verify the handoff context matches expectations.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Directives", destination: .directives, searchText: nil),
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil),
        ]
      )

    case .sessions:
      return StudioHelpTopic(
        id: .sessions,
        title: "Sessions Help",
        shortHint: "Sessions create reusable handoff context for AI sessions.",
        purpose:
          "A session bundles persona, directive, and optional kit overrides into one named session for an AI assistant. Its handoff context is the concrete text you copy or export into an assistant, and because PersonaKit is deterministic, the same session id resolves to the same handoff context again later.",
        keyFields: [
          "List rows show the session id, its persona and directive names, and scope.",
          "The Handoff tab shows the exact handoff context you provide to an AI assistant.",
          "Map mode shows dependency resolution and missing reference issues.",
          "Switch between Handoff and Map with ⌘1 and ⌘2.",
          "If a directive carries workstream routing, the session shows where that directive phase sits in the larger stream.",
        ],
        commonMistakes: [
          "Treating a session as something PersonaKit runs instead of context it resolves.",
          "Ignoring map resolution issues before exporting handoff context.",
          "Editing global-scope sessions instead of copying to project scope.",
          "Assuming workstream visibility means PersonaKit will auto-switch sessions for you.",
        ],
        examples: [
          "Example usage: export the handoff context from one session and paste it into a fresh AI chat as starting context."
        ],
        nextStepText:
          "Create or edit a session, confirm handoff/map health, then export the handoff context for your active agent.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Personas", destination: .personas, searchText: nil),
          StudioHelpLink(label: "Go to Directives", destination: .directives, searchText: nil),
          StudioHelpLink(label: "Go to Kits", destination: .kits, searchText: nil),
          StudioHelpLink(label: "Go to Validation Results", destination: .validationResults, searchText: nil),
        ]
      )

    case .skills:
      return StudioHelpTopic(
        id: .skills,
        title: "Skills Help",
        shortHint:
          "Skills are machine-checkable capability boundaries that become plain operating guidance.",
        purpose:
          "A Skill is not a runnable command. It declares a capability, who provides it, and its risk so PersonaKit can decide whether a resolved session may use that capability.",
        keyFields: [
          "Use the id as the stable capability name referenced by personas, kits, and directives.",
          "Use providedBy to name the external tool or environment associated with the capability.",
          "Document risk so the agent can translate authorization into ordinary operating judgment.",
          "Personas allow or forbid skills; kits and directives can require them.",
        ],
        commonMistakes: [
          "Treating skills as slash commands, prompts, or executable automation.",
          "Listing every installed local tool instead of declared capabilities that matter to contracts.",
          "Assuming a required skill is usable just because it exists; it must also be authorized by the active persona.",
          "Forgetting that undeclared host-local skills are unauthorized by default.",
        ],
        examples: [
          "Example: code-editing declares that a coding tool may perform edits after PersonaKit exports the resolved operating contract. PersonaKit records the capability boundary; it does not launch the tool."
        ],
        nextStepText:
          "Confirm the selected skill reads like a capability boundary, then verify references resolve in map/validation before exporting handoff context.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Personas", destination: .personas, searchText: nil),
          StudioHelpLink(label: "Go to Directives", destination: .directives, searchText: nil),
          StudioHelpLink(label: "Go to Kits", destination: .kits, searchText: nil),
          StudioHelpLink(label: "Go to Validation Results", destination: .validationResults, searchText: nil),
        ]
      )

    case .validationResults:
      return StudioHelpTopic(
        id: .validationResults,
        title: "Validation Results Help",
        shortHint: "Validation Results shows schema and reference errors across the workspace.",
        purpose:
          "Use validation to catch invalid json/markdown structure and broken cross-entity references before exporting handoff context.",
        keyFields: [
          "Summary indicates current workspace validation status.",
          "Validation reruns on its own after every save and every file change on disk.",
          "Issue list can search by id, file path, and message text.",
          "Issue actions navigate directly to the affected section.",
        ],
        commonMistakes: [
          "Ignoring warnings/errors and exporting anyway.",
          "Searching manually instead of navigating from issue links.",
        ],
        examples: [
          "Example: fix one missing persona id, save, then confirm the list shows no unresolved issues."
        ],
        nextStepText: "Resolve listed issues and save; return to Sessions when the workspace is clean.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil)
        ]
      )
    }
  }

  static func topic(
    for sidebarItem: SidebarItem
  ) -> StudioHelpTopic? {
    topic(for: sidebarItem.helpTopicID)
  }
}
extension SidebarItem {
  var helpTopicID: StudioHelpTopicID {
    switch self {
    case .sessions:
      return .sessions
    case .personas:
      return .personas
    case .directives:
      return .directives
    case .kits:
      return .kits
    case .skills:
      return .skills
    case .validationResults:
      return .validationResults
    }
  }
}
