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
      .intents,
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
  func everySidebarItemMapsToStableHelpExpansionStorageKey() {
    #expect(SidebarItem.sessions.helpExpansionStorageKey == "studio.help.sessions.expanded")
    #expect(SidebarItem.personas.helpExpansionStorageKey == "studio.help.personas.expanded")
    #expect(SidebarItem.directives.helpExpansionStorageKey == "studio.help.directives.expanded")
    #expect(SidebarItem.kits.helpExpansionStorageKey == "studio.help.kits.expanded")
    #expect(SidebarItem.essentials.helpExpansionStorageKey == "studio.help.essentials.expanded")
    #expect(SidebarItem.references.helpExpansionStorageKey == "studio.help.references.expanded")
    #expect(SidebarItem.skills.helpExpansionStorageKey == "studio.help.skills.expanded")
    #expect(SidebarItem.intents.helpExpansionStorageKey == "studio.help.intents.expanded")
    #expect(SidebarItem.relationshipMap.helpExpansionStorageKey == "studio.help.relationshipMap.expanded")
    #expect(
      SidebarItem.validationResults.helpExpansionStorageKey == "studio.help.validationResults.expanded"
    )
  }

  @Test
  func helpExpansionStorageKeysAreUnique() {
    let keys = [
      SidebarItem.sessions.helpExpansionStorageKey,
      SidebarItem.personas.helpExpansionStorageKey,
      SidebarItem.directives.helpExpansionStorageKey,
      SidebarItem.kits.helpExpansionStorageKey,
      SidebarItem.essentials.helpExpansionStorageKey,
      SidebarItem.references.helpExpansionStorageKey,
      SidebarItem.skills.helpExpansionStorageKey,
      SidebarItem.intents.helpExpansionStorageKey,
      SidebarItem.relationshipMap.helpExpansionStorageKey,
      SidebarItem.validationResults.helpExpansionStorageKey,
    ]

    #expect(Set(keys).count == keys.count)
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

  private func trimmed(
    _ value: String
  ) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
