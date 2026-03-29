import SwiftUI

/// Stable help-topic identifiers used by Studio panels and editors.
enum StudioHelpTopicID: String, CaseIterable, Sendable {
  case directives
  case essentials
  case intents
  case kits
  case orbit
  case personas
  case references
  case relationshipMap
  case sessionEditor
  case sessions
  case skills
  case taskboard
  case validationResults
}

/// Contextual navigation affordance presented from help cards.
struct StudioHelpLink: Equatable, Sendable {
  let label: String
  let destination: SidebarItem
  let searchText: String?
}

/// Structured contextual help content for a panel or editor flow.
struct StudioHelpTopic: Equatable, Sendable {
  let id: StudioHelpTopicID
  let title: String
  let shortHint: String
  let purpose: String
  let keyFields: [String]
  let commonMistakes: [String]
  let examples: [String]
  let nextStepText: String
  let relatedLinks: [StudioHelpLink]
}
