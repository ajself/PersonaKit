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
      #expect(!topic.relatedLinks.isEmpty)

      for field in topic.keyFields {
        #expect(!trimmed(field).isEmpty)
      }

      for commonMistake in topic.commonMistakes {
        #expect(!trimmed(commonMistake).isEmpty)
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

  private func trimmed(
    _ value: String
  ) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
