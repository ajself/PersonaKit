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
      .skills,
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
  func everySidebarItemHasHelpTopic() {
    let sidebarItems: [SidebarItem] = [
      .sessions,
      .personas,
      .directives,
      .kits,
      .skills,
      .validationResults,
    ]

    for item in sidebarItems {
      #expect(StudioHelpCatalog.topic(for: item) != nil)
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

    #expect(directives.keyFields.contains { $0.contains("routing context only") })
    #expect(sessions.keyFields.contains { $0.contains("workstream routing") })
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
  func kitsHelpPointsToUsedByInsteadOfWorkspaceMap() throws {
    let kits = try #require(StudioHelpCatalog.topic(for: StudioHelpTopicID.kits))

    #expect(kits.nextStepText.contains("Used by"))
    #expect(kits.purpose.contains("skills"))
    #expect(kits.shortHint.contains("skill ids"))
    #expect(!kits.shortHint.contains("rules"))
    #expect(kits.keyFields.contains { $0.contains("Skill IDs") })
    #expect(!kits.commonMistakes.contains { $0.contains("standards") })
    #expect(!kits.nextStepText.localizedCaseInsensitiveContains("relationship map"))
    #expect(kits.relatedLinks.map(\.destination) == [.sessions, .validationResults])
  }

  @Test
  func helpUsesProductTermsAndCurrentBehavior() throws {
    for topicID in StudioHelpTopicID.allCases {
      let topic = try #require(StudioHelpCatalog.topic(for: topicID))
      let text =
        ([topic.shortHint, topic.purpose, topic.nextStepText]
        + topic.keyFields + topic.commonMistakes + topic.examples).joined(separator: "\n")

      #expect(!text.localizedCaseInsensitiveContains("workflow"), "\(topicID) says workflow")
    }

    let validation = try #require(StudioHelpCatalog.topic(for: StudioHelpTopicID.validationResults))
    let sessions = try #require(StudioHelpCatalog.topic(for: StudioHelpTopicID.sessions))

    #expect(!validation.nextStepText.localizedCaseInsensitiveContains("re-run"))
    #expect(validation.keyFields.contains { $0.contains("reruns on its own") })
    #expect(sessions.keyFields.contains { $0.contains("⌘1") && $0.contains("⌘2") })
  }

  @Test
  func helpTopicsCoverEverySidebarDestinationOnly() {
    #expect(
      StudioHelpTopicID.allCases == [
        .directives,
        .kits,
        .personas,
        .sessions,
        .skills,
        .validationResults,
      ]
    )
  }

  @Test
  func sidebarGroupsSkillsWithTheOtherContractItems() {
    #expect(SidebarItem.contractItems == [.personas, .directives, .kits, .skills])
  }

  private func trimmed(
    _ value: String
  ) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
