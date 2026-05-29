/// Centralized contextual help catalog for Studio sections and focused workflows.
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
          "Treating workstream metadata like an executable workflow engine.",
        ],
        examples: [
          "Example directive: \"Refactor session preview caching without changing export behavior.\"",
          "Example routing note: a directive can declare a workstream id and phase so the next session is visible without executing anything.",
        ],
        nextStepText: "Link this directive from a session, then inspect session preview and map before saving.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil),
          StudioHelpLink(label: "Go to Validation Results", destination: .validationResults, searchText: nil),
        ]
      )

    case .essentials:
      return StudioHelpTopic(
        id: .essentials,
        title: "Essentials Help",
        shortHint: "Essentials are always-included rules and constraints.",
        purpose:
          "Essentials provide non-negotiable context that should be present across sessions regardless of directive specifics.",
        keyFields: [
          "Use concise titles and deterministic markdown content.",
          "Keep file names and ids stable for session references.",
          "Treat essentials as reusable ground rules, not task-specific prompts.",
        ],
        commonMistakes: [
          "Putting one-off task steps into essentials.",
          "Duplicating the same rule across multiple files.",
          "Using unclear filenames that are hard to discover.",
        ],
        examples: [
          "Example essential: \"All Swift edits must pass swift-format before commit.\""
        ],
        nextStepText: "Confirm essentials are referenced by kits or personas used in your active sessions.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Kits", destination: .kits, searchText: nil),
          StudioHelpLink(label: "Go to References", destination: .references, searchText: nil),
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil),
        ]
      )

    case .references:
      return StudioHelpTopic(
        id: .references,
        title: "References Help",
        shortHint: "References are first-class pack entities with deterministic trigger rules.",
        purpose:
          "References define reusable supporting material that sessions can expose without folding those documents into Essentials.",
        keyFields: [
          "Keep ids and filenames stable so reference links stay deterministic.",
          "Use clear summaries and trigger rules that match the intended source files or tags.",
          "Treat reference bodies as authored pack documents under `Packs/references`.",
        ],
        commonMistakes: [
          "Storing references in Essentials just because they are markdown files.",
          "Writing vague trigger rules that do not map cleanly to the intended surface area.",
          "Changing ids casually and breaking directive, kit, or intent links.",
        ],
        examples: [
          "Example reference: a SwiftUI style guide with trigger rules for `*View.swift` files and the `swiftui` reference tag."
        ],
        nextStepText:
          "Confirm references resolve from the right directives, kits, or intents, then inspect the Relationship Map for clean source edges.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Directives", destination: .directives, searchText: nil),
          StudioHelpLink(label: "Go to Kits", destination: .kits, searchText: nil),
          StudioHelpLink(label: "Go to Relationship Map", destination: .relationshipMap, searchText: nil),
          StudioHelpLink(label: "Go to Validation Results", destination: .validationResults, searchText: nil),
        ]
      )

    case .intents:
      return StudioHelpTopic(
        id: .intents,
        title: "Intents Help",
        shortHint: "Intents define reusable work patterns and decision rails.",
        purpose:
          "Intents encode repeatable approaches so directives can rely on consistent professional judgment patterns.",
        keyFields: [
          "Use a clear id and focused intent title.",
          "Capture decision boundaries and expected outputs.",
          "Keep intent language reusable across directives.",
        ],
        commonMistakes: [
          "Encoding one specific ticket instead of a reusable pattern.",
          "Leaving expected deliverables implicit.",
          "Overlapping heavily with directive content.",
        ],
        examples: [
          "Example intent: \"When blocked by ambiguity, stop and request a single clarifying decision.\""
        ],
        nextStepText: "Reference intent ids from kits/directives, then validate workspace for missing links.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Directives", destination: .directives, searchText: nil),
          StudioHelpLink(label: "Go to Kits", destination: .kits, searchText: nil),
          StudioHelpLink(label: "Go to Validation Results", destination: .validationResults, searchText: nil),
        ]
      )

    case .kits:
      return StudioHelpTopic(
        id: .kits,
        title: "Kits Help",
        shortHint: "Kits define how work is performed in your environment.",
        purpose:
          "Kits hold standards, constraints, and workflow assumptions that shape execution across many directives.",
        keyFields: [
          "Use explicit ids for standards and constraints references.",
          "Group related rules into coherent kits.",
          "Keep kit overrides intentional and minimal.",
        ],
        commonMistakes: [
          "Packing unrelated standards into one giant kit.",
          "Relying on implicit context not written in the kit.",
          "Creating duplicate kits with slight wording differences.",
        ],
        examples: [
          "Example kit: \"swiftui-style\" including formatting, testing, and accessibility constraints."
        ],
        nextStepText: "Verify kit ids used by sessions and directives resolve cleanly in the relationship map.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil),
          StudioHelpLink(label: "Go to Relationship Map", destination: .relationshipMap, searchText: nil),
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
          "Pair this persona with a directive in Sessions and verify the preview output matches expectations.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Directives", destination: .directives, searchText: nil),
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil),
        ]
      )

    case .relationshipMap:
      return StudioHelpTopic(
        id: .relationshipMap,
        title: "Relationship Map Help",
        shortHint: "Relationship Map shows cross-entity references and resolution health.",
        purpose:
          "Use this panel to visualize dependencies between sessions, personas, directives, kits, intents, skills, essentials, and references.",
        keyFields: [
          "Map Health summarizes whether references are fully resolved.",
          "Focus Selected Session narrows the graph to one session context.",
          "Entity type and scope filters reduce noise during troubleshooting.",
        ],
        commonMistakes: [
          "Ignoring unresolved badges before exporting session context.",
          "Troubleshooting from list views without checking graph dependencies.",
          "Assuming missing nodes are safe if preview still renders.",
        ],
        examples: [
          "Example check: select a session, enable focus mode, then resolve every orange issue badge."
        ],
        nextStepText: "Drill into unresolved nodes or jump to Validation Results to fix broken references.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil),
          StudioHelpLink(label: "Go to Validation Results", destination: .validationResults, searchText: nil),
        ]
      )

    case .sessionEditor:
      return StudioHelpTopic(
        id: .sessionEditor,
        title: "Session Editor Help",
        shortHint: "A Session is a deterministic Persona + Directive pairing with optional kit overrides.",
        purpose:
          "Session creation defines the exact context to export for an agent: role, task, and optional workflow constraints.",
        keyFields: [
          "Session id must be stable and filesystem-safe.",
          "Persona selects who performs the work.",
          "Directive selects what work is done.",
          "Kit overrides refine or extend how the work should be done.",
          "Directive-selected workstream routing is read-only context, not a runnable workflow.",
        ],
        commonMistakes: [
          "Using invalid session ids or ids that change frequently.",
          "Selecting persona/directive ids that no longer exist.",
          "Adding unnecessary kit overrides that duplicate defaults.",
          "Saving before reviewing dependency mini-map resolution.",
        ],
        examples: [
          "Example session draft: id \"ios-bugfix\", persona \"senior-swiftui-engineer\", directive \"apply-style\"."
        ],
        nextStepText:
          "After save, review Preview output, inspect Map health, and run Validation Results if references fail.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Personas", destination: .personas, searchText: nil),
          StudioHelpLink(label: "Go to Directives", destination: .directives, searchText: nil),
          StudioHelpLink(label: "Go to Kits", destination: .kits, searchText: nil),
          StudioHelpLink(label: "Go to Validation Results", destination: .validationResults, searchText: nil),
        ]
      )

    case .sessions:
      return StudioHelpTopic(
        id: .sessions,
        title: "Sessions Help",
        shortHint: "Sessions create reusable context packages for AI sessions.",
        purpose:
          "A session bundles persona, directive, and optional kit overrides into one named context package for an AI session. Preview and export are the concrete context payload you can paste into an assistant, and because PersonaKit is deterministic, the same session id resolves to the same context again later.",
        keyFields: [
          "List view shows id, persona, directive, and scope.",
          "Preview mode shows the exact context text you provide to an AI assistant.",
          "Map mode shows dependency resolution and missing reference issues.",
          "If a directive carries workstream routing, the session shows where that directive phase sits in the larger stream.",
        ],
        commonMistakes: [
          "Treating sessions like executable workflows instead of context definitions.",
          "Ignoring map resolution issues before exporting.",
          "Editing global-scope sessions instead of copying to project scope.",
          "Assuming workstream visibility means PersonaKit will auto-switch sessions for you.",
        ],
        examples: [
          "Example usage: export markdown from one session and paste it into a fresh AI chat as starting context."
        ],
        nextStepText:
          "Create or edit a session, confirm preview/map health, then export markdown for your active agent context.",
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
          "Use the id as the stable capability name referenced by personas, kits, directives, and intents.",
          "Use providedBy to name the external tool or environment associated with the capability.",
          "Document risk so the agent can translate authorization into ordinary operating judgment.",
          "Personas allow or forbid skills; kits, directives, and intents can require them.",
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
          "Confirm the selected skill reads like a capability boundary, then verify references resolve in map/validation before exporting session context.",
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
          "Use validation to catch invalid json/markdown structure and broken cross-entity references before exporting sessions.",
        keyFields: [
          "Summary indicates current workspace validation status.",
          "Issue list can search by id, file path, and message text.",
          "Issue actions navigate directly to the affected section.",
        ],
        commonMistakes: [
          "Ignoring warnings/errors and exporting anyway.",
          "Fixing one issue without re-validating workspace.",
          "Searching manually instead of navigating from issue links.",
        ],
        examples: [
          "Example workflow: fix one missing persona id, rerun validation, then verify zero unresolved issues."
        ],
        nextStepText: "Resolve listed issues, re-run validation, and return to Sessions when the workspace is clean.",
        relatedLinks: [
          StudioHelpLink(label: "Go to Relationship Map", destination: .relationshipMap, searchText: nil),
          StudioHelpLink(label: "Go to Sessions", destination: .sessions, searchText: nil),
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
    case .essentials:
      return .essentials
    case .references:
      return .references
    case .skills:
      return .skills
    case .intents:
      return .intents
    case .relationshipMap:
      return .relationshipMap
    case .validationResults:
      return .validationResults
    }
  }
}
