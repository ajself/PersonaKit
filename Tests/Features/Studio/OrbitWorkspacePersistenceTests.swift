import Foundation
import Testing

@testable import StudioFeatures

private func orbitRepositoryRootURL() -> URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}

struct OrbitWorkspacePersistenceTests {
  @Test
  func persistenceUsesWorkspaceLocalOrbitPath() {
    let persistence = OrbitWorkspacePersistence()
    let workspaceURL = URL(fileURLWithPath: "/tmp/orbit-checkpoint/../orbit-room", isDirectory: true)

    let directoryURL = persistence.directoryURL(for: workspaceURL)
    let fileURL = persistence.fileURL(for: workspaceURL)

    #expect(directoryURL.lastPathComponent == "Orbit")
    #expect(directoryURL.deletingLastPathComponent().lastPathComponent == ".personakit")
    #expect(fileURL.lastPathComponent == "orbit-workspace.json")
    #expect(fileURL.deletingLastPathComponent() == directoryURL)
  }

  @Test
  func persistenceRoundTripsWorkspaceThroughOrbitStoreFile() throws {
    let persistence = OrbitWorkspacePersistence()
    let fileManager = FileManager.default
    let workspaceURL = fileManager.temporaryDirectory
      .appendingPathComponent("orbit-runtime-roundtrip", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: workspaceURL) }

    let workspace = OrbitWorkspace.defaultWorkspace

    try persistence.persist(workspace, to: workspaceURL)

    let loadedWorkspace = try persistence.loadWorkspace(from: workspaceURL)

    #expect(fileManager.fileExists(atPath: persistence.fileURL(for: workspaceURL).path()))
    #expect(loadedWorkspace == workspace)
  }

  @Test
  func persistenceReturnsNilWhenOrbitStoreFileIsMissing() throws {
    let persistence = OrbitWorkspacePersistence()
    let fileManager = FileManager.default
    let workspaceURL = fileManager.temporaryDirectory
      .appendingPathComponent("orbit-runtime-missing", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: workspaceURL) }

    let loadedWorkspace = try persistence.loadWorkspace(from: workspaceURL)

    #expect(loadedWorkspace == nil)
  }

  @Test
  func defaultWorkspaceFitsFirstCheckpointRuntimeSlice() throws {
    let workspace = OrbitWorkspace.defaultWorkspace
    let participantIDs = workspace.participants.map(\.id).sorted()

    #expect(workspace.id == "orbit")
    #expect(workspace.displayName == "Orbit")
    #expect(!workspace.purpose.isEmpty)
    #expect(participantIDs == ["aj", "proddoc", "samwise"])
    #expect(workspace.threads.count == 1)
    #expect(workspace.activeThread?.id == workspace.activeThreadID)
    #expect(workspace.activationRecords.count == workspace.activationContractSnapshots.count)
    #expect(workspace.activationFailureRecords == [])
    #expect(workspace.participants.filter { $0.participantType == .ai }.count == 2)
  }

  @Test
  func directAddressRoundTripsAcrossReloadWithAttribution() throws {
    let persistence = OrbitWorkspacePersistence()
    let fileManager = FileManager.default
    let workspaceURL = fileManager.temporaryDirectory
      .appendingPathComponent("orbit-direct-restart", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: workspaceURL) }

    var workspace = OrbitWorkspace.defaultWorkspace

    _ = try workspace.appendConversationTurnIfPersisted(
      body: "Samwise, make the restart proof legible.",
      addressedParticipantID: OrbitParticipantID.samwise.rawValue,
      resolveContract: { participant in
        try OrbitContractResolver.resolve(
          participant: participant,
          workspaceURL: orbitRepositoryRootURL()
        )
      },
      persist: { stagedWorkspace in
        try persistence.persist(stagedWorkspace, to: workspaceURL)
      }
    )

    let loadedWorkspace = try persistence.loadWorkspace(from: workspaceURL)
    let reloadedWorkspace = try #require(loadedWorkspace)
    let activeThread = try #require(reloadedWorkspace.activeThread)
    let responseMessage = try #require(
      activeThread.messages.last(where: { $0.kind == .participantResponse })
    )
    let activation = try #require(reloadedWorkspace.activationRecord(for: responseMessage.id))
    let contractSnapshot = try #require(
      reloadedWorkspace.activationContractSnapshot(for: activation.id)
    )

    #expect(activeThread.messages.count == workspace.activeThread?.messages.count)
    #expect(responseMessage.speakerParticipantID == OrbitParticipantID.samwise.rawValue)
    #expect(activation.participantID == OrbitParticipantID.samwise.rawValue)
    #expect(activation.workspacePersonaID == "workspace-persona-orbit-samwise")
    #expect(contractSnapshot.kitIDs == ["trusted-partner-core"])
    #expect(contractSnapshot.authorizedSkillIDs == ["codex-cli"])
    #expect(contractSnapshot.reviewGateIDs == ["intent:partner-sync-review"])
  }

  @Test
  func lightweightMeetingRoundTripsAcrossReloadWithAttribution() throws {
    let persistence = OrbitWorkspacePersistence()
    let fileManager = FileManager.default
    let workspaceURL = fileManager.temporaryDirectory
      .appendingPathComponent("orbit-meeting-restart", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: workspaceURL) }

    var workspace = OrbitWorkspace.defaultWorkspace

    _ = try workspace.appendConversationTurnIfPersisted(
      body: "Founding group, prove the room survives restart.",
      addressedParticipantID: OrbitAddressTargetID.foundingGroup.rawValue,
      resolveContract: { participant in
        try OrbitContractResolver.resolve(
          participant: participant,
          workspaceURL: orbitRepositoryRootURL()
        )
      },
      persist: { stagedWorkspace in
        try persistence.persist(stagedWorkspace, to: workspaceURL)
      }
    )

    let loadedWorkspace = try persistence.loadWorkspace(from: workspaceURL)
    let reloadedWorkspace = try #require(loadedWorkspace)
    let activeThread = try #require(reloadedWorkspace.activeThread)
    let meetingResponses = activeThread.messages.filter { $0.kind == .participantResponse }.suffix(2)
    let systemEvents = activeThread.messages.filter { $0.kind == .systemEvent }

    #expect(activeThread.interactionMode == .directMessage)
    #expect(meetingResponses.count == 2)
    #expect(systemEvents.count == 2)
    #expect(Set(meetingResponses.map(\.speakerParticipantID)) == [
      OrbitParticipantID.samwise.rawValue,
      OrbitParticipantID.prodDoc.rawValue,
    ])
    #expect(
      meetingResponses.allSatisfy {
        $0.addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue
      }
    )
    #expect(systemEvents.first?.body.contains("exchange state: active") == true)
    #expect(systemEvents.last?.body.contains("state=completed") == true)
    #expect(reloadedWorkspace.activationRecords.suffix(2).allSatisfy { $0.triggerSource == .generalThreadReply })
    #expect(reloadedWorkspace.activationFailureRecords == [])
  }

  @Test
  func meetingPromotionEvidenceRoundTripsAcrossReload() throws {
    let persistence = OrbitWorkspacePersistence()
    let fileManager = FileManager.default
    let workspaceURL = fileManager.temporaryDirectory
      .appendingPathComponent("orbit-meeting-promotion-restart", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: workspaceURL) }

    var workspace = OrbitWorkspace.defaultWorkspace
    let expectedRecord = OrbitMeetingPromotionRecord(
      id: "promotion-failure-thread-0001-0001",
      workspaceID: workspace.id,
      initiatedByParticipantID: OrbitParticipantID.aj.rawValue,
      addressedTargetKind: .team,
      addressedTargetReferenceID: OrbitAddressTargetID.foundingGroup.rawValue,
      targetDisplayName: OrbitAddressTargetID.foundingGroup.displayText,
      meetingType: .team,
      title: "Founding Group Sync",
      memberWorkspacePersonaIDs: [
        "workspace-persona-orbit-proddoc",
        "workspace-persona-orbit-samwise",
      ],
      outcome: .failed,
      systemEventMessageID: "msg-0099",
      systemEventBody: "Meeting promotion failed; staying inline.",
      detail: "Meeting room creation returned no room projection."
    )
    workspace.meetingPromotionRecords = [expectedRecord]

    try persistence.persist(workspace, to: workspaceURL)

    let loadedWorkspace = try persistence.loadWorkspace(from: workspaceURL)
    let reloadedWorkspace = try #require(loadedWorkspace)

    #expect(reloadedWorkspace.meetingPromotionRecords == [expectedRecord])
    #expect(
      reloadedWorkspace.meetingPromotionFailureRecordForSystemEvent("msg-0099") == expectedRecord
    )
  }

  @Test
  func meetingContinuityEvidenceRoundTripsAcrossReload() throws {
    let persistence = OrbitWorkspacePersistence()
    let fileManager = FileManager.default
    let workspaceURL = fileManager.temporaryDirectory
      .appendingPathComponent("orbit-meeting-continuity-restart", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: workspaceURL) }

    var workspace = OrbitWorkspace.defaultWorkspace
    let expectedRecord = OrbitMeetingContinuityRecord(
      id: "promotion-link-0001",
      currentPerspective: .promotedMeeting,
      originPostID: "post-origin-0001",
      promotedMeetingPostID: "post-meeting-0001"
    )
    workspace.meetingContinuityRecords = [expectedRecord]

    try persistence.persist(workspace, to: workspaceURL)

    let loadedWorkspace = try persistence.loadWorkspace(from: workspaceURL)
    let reloadedWorkspace = try #require(loadedWorkspace)

    #expect(reloadedWorkspace.meetingContinuityRecords == [expectedRecord])
    #expect(reloadedWorkspace.meetingContinuityRecords.first?.linkedPostID == "post-origin-0001")
  }

  @Test
  func emptyWorkspaceRoundTripsWithoutInventingDiscussion() throws {
    let persistence = OrbitWorkspacePersistence()
    let fileManager = FileManager.default
    let workspaceURL = fileManager.temporaryDirectory
      .appendingPathComponent("orbit-empty-restart", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: workspaceURL) }

    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.threads = workspace.threads.map { thread in
      OrbitConversationThread(
        id: thread.id,
        title: thread.title,
        interactionMode: thread.interactionMode,
        createdSequence: thread.createdSequence,
        updatedSequence: thread.updatedSequence,
        messages: []
      )
    }
    workspace.activationRecords = []
    workspace.activationContractSnapshots = []
    workspace.activationFailureRecords = []
    workspace.nextMessageSequence = 1
    workspace.nextActivationSequence = 1
    workspace.nextActivationFailureSequence = 1

    try persistence.persist(workspace, to: workspaceURL)

    let loadedWorkspace = try persistence.loadWorkspace(from: workspaceURL)
    let reloadedWorkspace = try #require(loadedWorkspace)

    #expect(reloadedWorkspace.activeThread?.messages == [])
    #expect(reloadedWorkspace.activationRecords == [])
    #expect(reloadedWorkspace.activationContractSnapshots == [])
    #expect(reloadedWorkspace.activationFailureRecords == [])
  }
}
