import Foundation
import Testing

@testable import StudioFeatures

private enum OrbitWorkspaceTestPersistenceError: Error {
  case writeFailed
}

private func orbitRepositoryRootURL() -> URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}

struct OrbitWorkspaceTests {
  @Test
  func workspaceRoundTripPreservesMessagesAndActivationTrace() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.appendConversationTurn(
      body: "Founding group, lock the next command-center pass.",
      addressedParticipantID: OrbitAddressTargetID.foundingGroup.rawValue
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(workspace)
    let decoded = try JSONDecoder().decode(OrbitWorkspace.self, from: data)

    #expect(decoded == workspace)
    #expect(decoded.activeThread?.messages.count == workspace.activeThread?.messages.count)
    #expect(decoded.activationRecords.count == workspace.activationRecords.count)
    #expect(decoded.activationContractSnapshots.count == workspace.activationContractSnapshots.count)
    #expect(decoded.activationFailureRecords.count == workspace.activationFailureRecords.count)
  }

  @Test
  func legacyWorkspacePayloadMigratesIdentityAndContractSnapshotFields() throws {
    let legacyJSON = #"""
    {
      "schemaVersion": 1,
      "id": "orbit",
      "displayName": "Orbit",
      "purpose": "Command center for persistent AI collaborators working with AJ.",
      "participants": [
        {
          "id": "aj",
          "workspacePersonaID": null,
          "displayName": "AJ",
          "roleLabel": "Founder",
          "participantType": "human",
          "personaID": null,
          "defaultDirectiveID": null,
          "availability": "active",
          "sortOrder": 1
        },
        {
          "id": "samwise",
          "workspacePersonaID": "workspace-persona-orbit-samwise",
          "displayName": "Samwise",
          "roleLabel": "Trusted Partner",
          "participantType": "ai",
          "personaID": "samwise",
          "defaultDirectiveID": "maintain-partner-sync-and-handoffs",
          "availability": "available",
          "sortOrder": 2
        }
      ],
      "activeThreadID": "thread-0001",
      "threads": [
        {
          "id": "thread-0001",
          "title": "Orbit MVP Checkpoint",
          "interactionMode": "lightweightMeeting",
          "createdSequence": 1,
          "updatedSequence": 1,
          "messages": [
            {
              "id": "msg-0001",
              "speakerParticipantID": "samwise",
              "addressedParticipantID": null,
              "body": "Orbit is ready for the first checkpoint.",
              "order": 1,
              "kind": "participantResponse"
            }
          ]
        }
      ],
      "activationRecords": [
        {
          "id": "act-0001",
          "responseMessageID": "msg-0001",
          "participantID": "samwise",
          "personaID": "samwise",
          "directiveID": "maintain-partner-sync-and-handoffs",
          "triggerSource": "generalThreadReply",
          "triggerMessageID": null,
          "memoryInfluenced": false
        }
      ],
      "nextMessageSequence": 2,
      "nextActivationSequence": 2
    }
    """#

    let workspace = try JSONDecoder().decode(OrbitWorkspace.self, from: Data(legacyJSON.utf8))
    let activation = try #require(workspace.activationRecord(for: "msg-0001"))
    let contractSnapshot = try #require(workspace.activationContractSnapshot(for: activation.id))
    let samwise = try #require(
      workspace.participants.first { $0.id == OrbitParticipantID.samwise.rawValue }
    )

    #expect(workspace.schemaVersion == OrbitWorkspace.currentSchemaVersion)
    #expect(samwise.personaTemplateID == "samwise")
    #expect(samwise.requiredSkillIDs == [])
    #expect(samwise.authorizedSkillIDs == [])
    #expect(activation.workspaceID == "orbit")
    #expect(activation.workspacePersonaID == "workspace-persona-orbit-samwise")
    #expect(activation.personaTemplateID == "samwise")
    #expect(activation.responseMode == .lightweightMeeting)
    #expect(activation.memorySourceRefs == [])
    #expect(contractSnapshot.id == "act-0001-contract")
    #expect(contractSnapshot.directiveSource == .participantDefault)
    #expect(workspace.activationFailureRecords == [])
  }

  @Test
  func directAddressCreatesParticipantResponseAndActivationTrace() throws {
    var workspace = OrbitWorkspace.defaultWorkspace

    let createdMessages = try workspace.appendConversationTurnIfPersisted(
      body: "Samwise, line up the next checkpoint step.",
      addressedParticipantID: OrbitParticipantID.samwise.rawValue,
      resolveContract: { participant in
        try OrbitContractResolver.resolve(
          participant: participant,
          workspaceURL: orbitRepositoryRootURL()
        )
      },
      persist: { _ in }
    )

    #expect(createdMessages.count == 2)

    let userMessage = try #require(createdMessages.first)
    let responseMessage = try #require(createdMessages.last)
    let activation = try #require(workspace.activationRecord(for: responseMessage.id))
    let contractSnapshot = try #require(workspace.activationContractSnapshot(for: activation.id))
    let traceLines = activation.traceSummaryLines(contractSnapshot: contractSnapshot)

    #expect(userMessage.kind == .user)
    #expect(responseMessage.kind == .participantResponse)
    #expect(responseMessage.speakerParticipantID == OrbitParticipantID.samwise.rawValue)
    #expect(responseMessage.addressedParticipantID == OrbitParticipantID.aj.rawValue)
    #expect(activation.participantID == OrbitParticipantID.samwise.rawValue)
    #expect(activation.workspaceID == "orbit")
    #expect(activation.workspacePersonaID == "workspace-persona-orbit-samwise")
    #expect(activation.personaTemplateID == "samwise")
    #expect(activation.directiveID == "maintain-partner-sync-and-handoffs")
    #expect(activation.responseMode == .directMessage)
    #expect(activation.triggerSource == .directAddress)
    #expect(activation.triggerMessageID == userMessage.id)
    #expect(activation.memorySourceRefs == [])
    #expect(contractSnapshot.id == "\(activation.id)-contract")
    #expect(contractSnapshot.directiveSource == .participantDefault)
    #expect(contractSnapshot.kitIDs == ["trusted-partner-core"])
    #expect(contractSnapshot.authorizedSkillIDs == ["codex-cli"])
    #expect(contractSnapshot.stopPointIDs == [])
    #expect(contractSnapshot.reviewGateIDs == ["intent:partner-sync-review"])
    #expect(contractSnapshot.memoryScopeIDs == [])
    #expect(traceLines.count == 3)
    #expect(traceLines[0].contains("workspace persona: workspace-persona-orbit-samwise"))
    #expect(traceLines[1].contains("directive: maintain-partner-sync-and-handoffs"))
    #expect(traceLines[2].contains("contract: kits trusted-partner-core | skills codex-cli"))
    #expect(workspace.activationFailureRecords == [])
    #expect(workspace.activeThread?.interactionMode == .directMessage)
  }

  @Test
  func currentThreadReplyUsesSingleVisibleStewardPath() throws {
    var workspace = OrbitWorkspace.defaultWorkspace

    let createdMessages = try workspace.appendConversationTurnIfPersisted(
      body: "Keep the active Orbit thread moving.",
      addressedParticipantID: nil,
      resolveContract: { participant in
        try OrbitContractResolver.resolve(
          participant: participant,
          workspaceURL: orbitRepositoryRootURL()
        )
      },
      persist: { _ in }
    )

    #expect(createdMessages.count == 2)

    let responseMessage = try #require(createdMessages.last)
    let activation = try #require(workspace.activationRecord(for: responseMessage.id))

    #expect(responseMessage.kind == .participantResponse)
    #expect(responseMessage.speakerParticipantID == OrbitParticipantID.samwise.rawValue)
    #expect(activation.triggerSource == .generalThreadReply)
    #expect(activation.responseMode == .directMessage)
    #expect(workspace.activeThread?.messages.contains { $0.kind == .systemEvent } == false)
  }

  @Test
  func persistenceFailureDoesNotPublishConversationTurn() throws {
    let originalWorkspace = OrbitWorkspace.defaultWorkspace
    var workspace = originalWorkspace

    do {
      _ = try workspace.appendConversationTurnIfPersisted(
        body: "Samwise, checkpoint this write path.",
        addressedParticipantID: OrbitParticipantID.samwise.rawValue,
        persist: { _ in throw OrbitWorkspaceTestPersistenceError.writeFailed }
      )
      Issue.record("Expected persistence failure")
    } catch OrbitWorkspaceTestPersistenceError.writeFailed {
      #expect(workspace == originalWorkspace)
      #expect(workspace.threads == originalWorkspace.threads)
      #expect(workspace.activationRecords == originalWorkspace.activationRecords)
      #expect(workspace.activationContractSnapshots == originalWorkspace.activationContractSnapshots)
      #expect(workspace.activationFailureRecords == originalWorkspace.activationFailureRecords)
    }
  }

  @Test
  func foundingGroupInvitationCreatesMeetingEventAndMultipleResponses() throws {
    var workspace = OrbitWorkspace.defaultWorkspace

    let createdMessages = try workspace.appendConversationTurnIfPersisted(
      body: "Founding group, align on the next Orbit checkpoint.",
      addressedParticipantID: OrbitAddressTargetID.foundingGroup.rawValue,
      resolveContract: { participant in
        try OrbitContractResolver.resolve(
          participant: participant,
          workspaceURL: orbitRepositoryRootURL()
        )
      },
      persist: { _ in }
    )

    #expect(createdMessages.count == 4)

    let systemEvent = try #require(
      createdMessages.first(where: { $0.kind == .systemEvent })
    )
    let responseMessages = createdMessages.filter { $0.kind == .participantResponse }
    let activationRecords = workspace.activationRecords.filter {
      responseMessages.map(\.id).contains($0.responseMessageID)
    }
    let contractSnapshots = activationRecords.compactMap {
      workspace.activationContractSnapshot(for: $0.id)
    }

    #expect(systemEvent.body.contains("lightweight meeting"))
    #expect(responseMessages.count == 2)
    #expect(
      Set(responseMessages.map(\.speakerParticipantID)) == [
        OrbitParticipantID.samwise.rawValue,
        OrbitParticipantID.prodDoc.rawValue,
      ]
    )
    #expect(activationRecords.count == 2)
    #expect(activationRecords.allSatisfy { $0.triggerSource == .meetingInvocation })
    #expect(activationRecords.allSatisfy { $0.workspaceID == "orbit" })
    #expect(activationRecords.allSatisfy { $0.responseMode == .lightweightMeeting })
    #expect(activationRecords.allSatisfy { $0.memorySourceRefs == [] })
    #expect(contractSnapshots.count == 2)
    #expect(contractSnapshots.allSatisfy { $0.directiveSource == .participantDefault })
    #expect(contractSnapshots.allSatisfy { $0.authorizedSkillIDs == ["codex-cli"] })
    #expect(contractSnapshots.allSatisfy { $0.memoryScopeIDs == [] })

    let snapshotsByActivationID = Dictionary(uniqueKeysWithValues: contractSnapshots.map { ($0.activationID, $0) })

    for activation in activationRecords {
      let contractSnapshot = try #require(snapshotsByActivationID[activation.id])

      if activation.participantID == OrbitParticipantID.samwise.rawValue {
        #expect(contractSnapshot.kitIDs == ["trusted-partner-core"])
        #expect(contractSnapshot.stopPointIDs == [])
        #expect(contractSnapshot.reviewGateIDs == ["intent:partner-sync-review"])
      }

      if activation.participantID == OrbitParticipantID.prodDoc.rawValue {
        #expect(contractSnapshot.kitIDs == ["venture-product-core"])
        #expect(contractSnapshot.stopPointIDs == ["Pause for AJ review before execution handoff."])
        #expect(contractSnapshot.reviewGateIDs == ["intent:plan-macos-feature-delivery"])
      }
    }

    #expect(workspace.activationFailureRecords == [])
    #expect(workspace.activeThread?.interactionMode == .lightweightMeeting)
  }

  @Test
  func unknownCollaboratorTargetBlocksActivationAndPersistsFailure() throws {
    var workspace = OrbitWorkspace.defaultWorkspace

    let createdMessages = workspace.appendConversationTurn(
      body: "Ghost, weigh in on the Orbit checkpoint.",
      addressedParticipantID: "ghost"
    )

    #expect(createdMessages.count == 2)

    let userMessage = try #require(createdMessages.first)
    let blockedEvent = try #require(createdMessages.last)
    let failure = try #require(workspace.activationFailureRecord(for: userMessage.id))
    let failureByEvent = try #require(
      workspace.activationFailureRecordForSystemEvent(blockedEvent.id)
    )

    #expect(blockedEvent.kind == .systemEvent)
    #expect(blockedEvent.body.contains("blocked the activation"))
    #expect(workspace.activationRecords.count == 1)
    #expect(workspace.activationContractSnapshots.count == 1)
    #expect(failure.failureReason == .unknownCollaboratorTarget)
    #expect(failure.addressedTargetID == "ghost")
    #expect(failure.triggerMessageID == userMessage.id)
    #expect(failure.systemEventMessageID == blockedEvent.id)
    #expect(failure.participantID == nil)
    #expect(failure.traceSummaryLines[0].contains("unknown collaborator target"))
    #expect(failure.traceSummaryLines[1].contains("target: ghost"))
    #expect(failureByEvent == failure)
    #expect(workspace.activeThread?.interactionMode == .lightweightMeeting)
  }

  @Test
  func missingDirectiveBlocksActivationAndPersistsFailure() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.participants = workspace.participants.map { participant in
      guard participant.id == OrbitParticipantID.prodDoc.rawValue else {
        return participant
      }

      return OrbitParticipant(
        id: participant.id,
        workspacePersonaID: participant.workspacePersonaID,
        displayName: participant.displayName,
        roleLabel: participant.roleLabel,
        participantType: participant.participantType,
        personaTemplateID: participant.personaTemplateID,
        defaultDirectiveID: nil,
        requiredSkillIDs: participant.requiredSkillIDs,
        authorizedSkillIDs: participant.authorizedSkillIDs,
        availability: participant.availability,
        sortOrder: participant.sortOrder
      )
    }

    let createdMessages = workspace.appendConversationTurn(
      body: "ProdDoc, pressure-test the checkpoint.",
      addressedParticipantID: OrbitParticipantID.prodDoc.rawValue
    )

    #expect(createdMessages.count == 2)

    let userMessage = try #require(createdMessages.first)
    let blockedEvent = try #require(createdMessages.last)
    let failure = try #require(workspace.activationFailureRecord(for: userMessage.id))

    #expect(blockedEvent.kind == .systemEvent)
    #expect(blockedEvent.body.contains("no resolved directive"))
    #expect(workspace.activationRecords.count == 1)
    #expect(workspace.activationContractSnapshots.count == 1)
    #expect(failure.failureReason == .missingDirective)
    #expect(failure.participantID == OrbitParticipantID.prodDoc.rawValue)
    #expect(failure.workspacePersonaID == "workspace-persona-orbit-proddoc")
    #expect(failure.personaTemplateID == "venture-product-steward")
    #expect(failure.systemEventMessageID == blockedEvent.id)
  }

  @Test
  func frozenProdDocAliasContradictionBlocksActivation() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.participants = workspace.participants.map { participant in
      guard participant.id == OrbitParticipantID.prodDoc.rawValue else {
        return participant
      }

      return OrbitParticipant(
        id: participant.id,
        workspacePersonaID: participant.workspacePersonaID,
        displayName: participant.displayName,
        roleLabel: participant.roleLabel,
        participantType: participant.participantType,
        personaTemplateID: "samwise",
        defaultDirectiveID: participant.defaultDirectiveID,
        requiredSkillIDs: participant.requiredSkillIDs,
        authorizedSkillIDs: participant.authorizedSkillIDs,
        availability: participant.availability,
        sortOrder: participant.sortOrder
      )
    }

    let createdMessages = workspace.appendConversationTurn(
      body: "ProdDoc, review the room model.",
      addressedParticipantID: OrbitParticipantID.prodDoc.rawValue
    )

    #expect(createdMessages.count == 2)

    let userMessage = try #require(createdMessages.first)
    let blockedEvent = try #require(createdMessages.last)
    let failure = try #require(workspace.activationFailureRecord(for: userMessage.id))

    #expect(blockedEvent.kind == .systemEvent)
    #expect(blockedEvent.body.contains("ProdDoc identity mapping"))
    #expect(workspace.activationRecords.count == 1)
    #expect(workspace.activationContractSnapshots.count == 1)
    #expect(failure.failureReason == .frozenProdDocAliasContradiction)
    #expect(failure.participantID == OrbitParticipantID.prodDoc.rawValue)
    #expect(failure.personaTemplateID == "samwise")
    #expect(failure.systemEventMessageID == blockedEvent.id)
  }

  @Test
  func unauthorizedSkillPostureBlocksActivationAndPersistsSkillDetail() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.participants = workspace.participants.map { participant in
      guard participant.id == OrbitParticipantID.samwise.rawValue else {
        return participant
      }

      return OrbitParticipant(
        id: participant.id,
        workspacePersonaID: participant.workspacePersonaID,
        displayName: participant.displayName,
        roleLabel: participant.roleLabel,
        participantType: participant.participantType,
        personaTemplateID: participant.personaTemplateID,
        defaultDirectiveID: participant.defaultDirectiveID,
        requiredSkillIDs: ["codex-cli"],
        authorizedSkillIDs: [],
        availability: participant.availability,
        sortOrder: participant.sortOrder
      )
    }

    let createdMessages = workspace.appendConversationTurn(
      body: "Samwise, use the tool lane for this checkpoint.",
      addressedParticipantID: OrbitParticipantID.samwise.rawValue
    )

    #expect(createdMessages.count == 2)

    let userMessage = try #require(createdMessages.first)
    let blockedEvent = try #require(createdMessages.last)
    let failure = try #require(workspace.activationFailureRecord(for: userMessage.id))

    #expect(blockedEvent.kind == .systemEvent)
    #expect(blockedEvent.body.contains("required skill posture is not authorized"))
    #expect(workspace.activationRecords.count == 1)
    #expect(workspace.activationContractSnapshots.count == 1)
    #expect(failure.failureReason == .unauthorizedSkillPosture)
    #expect(failure.participantID == OrbitParticipantID.samwise.rawValue)
    #expect(failure.requiredSkillIDs == ["codex-cli"])
    #expect(failure.authorizedSkillIDs == [])
    #expect(failure.systemEventMessageID == blockedEvent.id)
    #expect(failure.traceSummaryLines.last?.contains("required codex-cli | authorized none") == true)
  }

  @Test
  func aiCollaboratorsKeepStableWorkspacePersonaAndTemplateAnchors() {
    let workspace = OrbitWorkspace.defaultWorkspace

    let aiParticipants = workspace.participants.filter { $0.participantType == .ai }

    #expect(aiParticipants.count == 2)
    #expect(aiParticipants.allSatisfy { $0.workspacePersonaID != nil })
    #expect(aiParticipants.allSatisfy { $0.personaTemplateID != nil })
    #expect(aiParticipants.allSatisfy { $0.requiredSkillIDs == ["codex-cli"] })
    #expect(aiParticipants.allSatisfy { $0.authorizedSkillIDs == ["codex-cli"] })

    let prodDoc = aiParticipants.first { $0.id == OrbitParticipantID.prodDoc.rawValue }

    #expect(prodDoc?.displayName == "ProdDoc")
    #expect(prodDoc?.workspacePersonaID == "workspace-persona-orbit-proddoc")
    #expect(prodDoc?.personaTemplateID == "venture-product-steward")
  }

  @Test
  func contractResolverUsesLivePersonakitContractForSamwise() throws {
    let participant = try #require(
      OrbitWorkspace.defaultWorkspace.participants.first { $0.id == OrbitParticipantID.samwise.rawValue }
    )

    let contract = try OrbitContractResolver.resolve(
      participant: participant,
      workspaceURL: orbitRepositoryRootURL()
    )

    #expect(contract.directiveID == "maintain-partner-sync-and-handoffs")
    #expect(contract.kitIDs == ["trusted-partner-core"])
    #expect(contract.authorizedSkillIDs == ["codex-cli"])
    #expect(contract.requiredSkillIDs == ["codex-cli"])
    #expect(contract.reviewGateIDs == ["intent:partner-sync-review"])
    #expect(contract.stopPointIDs == [])
    #expect(contract.memoryScopeIDs == [])
    #expect(contract.failureReasons == [])
  }

  @Test
  func contractResolverUsesLivePersonakitContractForProdDocAlias() throws {
    let participant = try #require(
      OrbitWorkspace.defaultWorkspace.participants.first { $0.id == OrbitParticipantID.prodDoc.rawValue }
    )

    let contract = try OrbitContractResolver.resolve(
      participant: participant,
      workspaceURL: orbitRepositoryRootURL()
    )

    #expect(contract.directiveID == "run-venture-product-planning")
    #expect(contract.kitIDs == ["venture-product-core"])
    #expect(contract.authorizedSkillIDs == ["codex-cli"])
    #expect(contract.requiredSkillIDs == ["codex-cli"])
    #expect(contract.stopPointIDs == ["Pause for AJ review before execution handoff."])
    #expect(contract.reviewGateIDs == ["intent:plan-macos-feature-delivery"])
    #expect(contract.memoryScopeIDs == [])
    #expect(contract.failureReasons == [])
  }

  @Test
  func contractResolverFailsCleanlyWhenProjectScopeIsMissing() {
    let participant = OrbitWorkspace.defaultWorkspace.participants[1]

    let tempWorkspaceURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "orbit-m1-missing-scope",
      isDirectory: true
    )

    do {
      _ = try OrbitContractResolver.resolve(
        participant: participant,
        workspaceURL: tempWorkspaceURL
      )
      Issue.record("Expected missing project scope error")
    } catch let error as OrbitContractResolutionError {
      #expect(error == .missingProjectScope)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
