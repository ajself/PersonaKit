import Foundation
import Testing

@testable import StudioFeatures

struct StudioHelpCatalogTests {
  @Test
  func everySidebarItemMapsToHelpTopic() throws {
    let sidebarItems: [SidebarItem] = [
      .sessions,
      .personas,
      .directives,
      .kits,
      .essentials,
      .references,
      .skills,
      .relationshipMap,
      .validationResults,
    ]

    for item in sidebarItems {
      let topic = try #require(StudioHelpCatalog.topic(for: item))
      #expect(topic.id == item.helpTopicID)
    }
  }

  @Test
  func everyTopicContainsRequiredContent() throws {
    for topicID in StudioHelpTopicID.allCases {
      let topic = try #require(StudioHelpCatalog.topic(for: topicID))

      #expect(!trimmed(topic.title).isEmpty)
      #expect(!trimmed(topic.shortHint).isEmpty)
      #expect(!trimmed(topic.purpose).isEmpty)
      #expect(!trimmed(topic.nextStepText).isEmpty)
      #expect(!topic.keyFields.isEmpty)
      #expect(!topic.commonMistakes.isEmpty)
      #expect(!topic.examples.isEmpty)
      #expect(!topic.relatedLinks.isEmpty)

      for field in topic.keyFields {
        #expect(!trimmed(field).isEmpty)
      }

      for commonMistake in topic.commonMistakes {
        #expect(!trimmed(commonMistake).isEmpty)
      }

      for example in topic.examples {
        #expect(!trimmed(example).isEmpty)
      }

      for relatedLink in topic.relatedLinks {
        #expect(!trimmed(relatedLink.label).isEmpty)
      }
    }
  }

  @Test
  func relatedLinkOrderingIsDeterministic() throws {
    for topicID in StudioHelpTopicID.allCases {
      let first = try #require(StudioHelpCatalog.topic(for: topicID))
      let second = try #require(StudioHelpCatalog.topic(for: topicID))

      #expect(first.relatedLinks == second.relatedLinks)
      #expect(Set(first.relatedLinks.map(\.label)).count == first.relatedLinks.count)
    }
  }

  @Test
  func everySidebarHelpTopicCanUseInspector() {
    let sidebarItems: [SidebarItem] = [
      .sessions,
      .personas,
      .directives,
      .kits,
      .essentials,
      .references,
      .skills,
      .relationshipMap,
      .validationResults,
    ]

    for item in sidebarItems {
      #expect(StudioHelpCatalog.topic(for: item) != nil)
      #expect(item.supportsInspector)
    }
  }

  @Test
  func inspectorModeHasStableStorageAndFallback() {
    #expect(StudioInspectorMode.storageKey == "studio.inspector.mode")
    #expect(StudioInspectorMode.primary.rawValue == "primary")
    #expect(StudioInspectorMode.help.rawValue == "help")
    #expect(StudioInspectorMode.resolved(rawValue: "help") == .help)
    #expect(StudioInspectorMode.resolved(rawValue: "unexpected") == .primary)
  }

  @Test
  func inspectorModeOrderingMatchesSegmentOrder() {
    #expect(StudioInspectorMode.allCases == [.primary, .help])
  }

  @Test
  func sessionsAndDirectivesHelpExplainWorkstreamAsRoutingMetadata() throws {
    let directives = try #require(StudioHelpCatalog.topic(for: StudioHelpTopicID.directives))
    let sessions = try #require(StudioHelpCatalog.topic(for: StudioHelpTopicID.sessions))
    let sessionEditor = try #require(StudioHelpCatalog.topic(for: StudioHelpTopicID.sessionEditor))

    #expect(directives.keyFields.contains { $0.contains("routing context only") })
    #expect(sessions.keyFields.contains { $0.contains("workstream routing") })
    #expect(sessionEditor.keyFields.contains { $0.contains("read-only context") })
  }

  @Test
  func skillsHelpExplainsCapabilityBoundaryModel() throws {
    let skills = try #require(StudioHelpCatalog.topic(for: StudioHelpTopicID.skills))

    #expect(skills.shortHint.contains("capability boundaries"))
    #expect(skills.purpose.contains("not a runnable command"))
    #expect(skills.keyFields.contains { $0.contains("providedBy") })
    #expect(skills.commonMistakes.contains { $0.contains("slash commands") })
    #expect(skills.commonMistakes.contains { $0.contains("unauthorized by default") })
  }

  @Test
  func relationshipMapHelpDocumentsRetainedFocusMode() throws {
    let relationshipMap = try #require(StudioHelpCatalog.topic(for: StudioHelpTopicID.relationshipMap))

    #expect(relationshipMap.keyFields.contains { $0.contains("Focus Selected Session") })
    #expect(relationshipMap.examples.contains { $0.contains("enable focus mode") })
  }

  private func trimmed(
    _ value: String
  ) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
