import AppKit
import SwiftUI

extension OrbitPanelView {
  var sortedParticipants: [OrbitParticipant] {
    orbitWorkspace.participants.sorted { $0.sortOrder < $1.sortOrder }
  }

  var activeParticipantIDs: Set<String> {
    guard let activeThread else {
      return []
    }

    let recentParticipantIDs = activeThread.messages
      .suffix(3)
      .filter { $0.kind == .participantResponse }
      .map(\.speakerParticipantID)

    return Set(recentParticipantIDs)
  }

  var addressedParticipantIDs: Set<String> {
    if addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue {
      return Set(
        sortedParticipants
          .filter { $0.participantType == .ai }
          .map(\.id)
      )
    }

    return [addressedParticipantID]
  }

  var activeThread: OrbitConversationThread? {
    orbitWorkspace.activeThread
  }

  var workspaceHeaderCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(orbitWorkspace.displayName)
        .font(.system(size: 28, weight: .semibold))

      Text(orbitWorkspace.purpose)
        .font(.body)
        .foregroundStyle(.secondary)

      if let activeThread {
        HStack(spacing: 10) {
          Label(activeThread.title, systemImage: "bubble.left.and.bubble.right")
            .font(.subheadline.weight(.medium))

          Text(activeThread.interactionMode.displayText)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal, 16)
    .padding(.top, 12)
  }

  var rosterCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Founding Group")
        .font(.headline)

      HStack(alignment: .top, spacing: 12) {
        ForEach(sortedParticipants) { participant in
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              Circle()
                .fill(color(for: participant))
                .frame(width: 10, height: 10)

              Text(participant.displayName)
                .font(.subheadline.weight(.semibold))
            }

            Text(participant.roleLabel)
              .font(.caption)
              .foregroundStyle(.secondary)

            Text(participant.availability.displayText)
              .font(.caption.weight(.medium))
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .stroke(
                participantHighlightColor(for: participant),
                lineWidth: participantHighlightColor(for: participant) == .clear ? 0 : 2
              )
          }
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal, 16)
  }

  var conversationCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Conversation")
        .font(.headline)

      if let activeThread {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(activeThread.messages.sorted { $0.order < $1.order }) { message in
              messageCard(message)
            }
          }
        }
      } else {
        ContentUnavailableView(
          "No Active Thread",
          systemImage: "bubble.left.and.exclamationmark.bubble.right",
          description: Text("Orbit needs one active conversation thread for the first checkpoint.")
        )
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal, 16)
  }

  @ViewBuilder
  func messageCard(
    _ message: OrbitMessage
  ) -> some View {
    let speaker = orbitWorkspace.participant(id: message.speakerParticipantID)
    let activation = orbitWorkspace.activationRecord(for: message.id)
    let contractSnapshot = activation.flatMap {
      orbitWorkspace.activationContractSnapshot(for: $0.id)
    }
    let activationFailure = orbitWorkspace.activationFailureRecordForSystemEvent(message.id)

    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(speaker?.displayName ?? message.speakerParticipantID)
          .font(.subheadline.weight(.semibold))

        Text(message.kind.displayText)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Color.secondary.opacity(0.12), in: Capsule())

        if let addressLabel = addressLabel(for: message.addressedParticipantID) {
          Text("to \(addressLabel)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Text(message.body)
        .font(.body)
        .textSelection(.enabled)

      if let activation {
        VStack(alignment: .leading, spacing: 4) {
          Text("Activation Trace")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

          ForEach(activation.traceSummaryLines(contractSnapshot: contractSnapshot), id: \.self) { line in
            Text(line)
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
          }
        }
      }

      if let activationFailure {
        VStack(alignment: .leading, spacing: 4) {
          Text("Blocked Activation")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

          ForEach(activationFailure.traceSummaryLines, id: \.self) { line in
            Text(line)
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
  }

  var composerCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("New Message")
        .font(.headline)

      Picker(
        "Address",
        selection: $addressedParticipantID
      ) {
        Text(OrbitAddressTargetID.foundingGroup.displayText)
          .tag(OrbitAddressTargetID.foundingGroup.rawValue)

        ForEach(
          sortedParticipants.filter { $0.id != OrbitParticipantID.aj.rawValue }
        ) { participant in
          Text(participant.displayName)
            .tag(participant.id)
        }
      }
      .pickerStyle(.segmented)

      TextField(
        "Message AJ wants to send into Orbit",
        text: $draftMessageBody,
        axis: .vertical
      )
      .textFieldStyle(.roundedBorder)
      .lineLimit(3...6)

      HStack {
        Spacer()

        Button {
          sendMessage()
        } label: {
          Label(sendButtonTitle, systemImage: sendButtonSystemImage)
        }
        .buttonStyle(.borderedProminent)
        .disabled(draftMessageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }

  func color(
    for participant: OrbitParticipant
  ) -> Color {
    switch participant.id {
    case OrbitParticipantID.aj.rawValue:
      return .orange
    case OrbitParticipantID.samwise.rawValue:
      return .blue
    case OrbitParticipantID.prodDoc.rawValue:
      return .green
    default:
      return .secondary
    }
  }

  func participantHighlightColor(
    for participant: OrbitParticipant
  ) -> Color {
    if addressedParticipantIDs.contains(participant.id) {
      return .accentColor
    }

    if activeParticipantIDs.contains(participant.id) {
      return color(for: participant).opacity(0.8)
    }

    return .clear
  }

  func addressLabel(
    for addressedParticipantID: String?
  ) -> String? {
    guard let addressedParticipantID else {
      return nil
    }

    if addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue {
      return OrbitAddressTargetID.foundingGroup.displayText
    }

    return orbitWorkspace.participant(id: addressedParticipantID)?.displayName
  }

  var sendButtonTitle: String {
    if addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue {
      return "Invite Group"
    }

    return "Send"
  }

  var sendButtonSystemImage: String {
    if addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue {
      return "person.3.sequence.fill"
    }

    return "arrow.up.circle.fill"
  }

  func sendMessage() {
    let messageBody = draftMessageBody
    var stagedWorkspace = orbitWorkspace

    do {
      guard let workspaceURL = workspaceStore.workspaceURL else {
        throw OrbitWorkspacePersistenceError.noWorkspaceSelected
      }

      _ = try stagedWorkspace.appendConversationTurnIfPersisted(
        body: messageBody,
        addressedParticipantID: addressedParticipantID,
        resolveContract: { participant in
          try OrbitContractResolver.resolve(
            participant: participant,
            workspaceURL: workspaceURL
          )
        },
        persist: persistOrbitWorkspace
      )
      orbitWorkspace = stagedWorkspace
      draftMessageBody = ""
      persistenceMessage = nil
      persistenceIsError = false
    } catch let error as OrbitContractResolutionError {
      persistenceMessage =
        "Orbit blocked the send because the collaborator contract could not be resolved: \(error.localizedDescription)"
      persistenceIsError = true
    } catch {
      persistenceMessage =
        "Orbit blocked the send because workspace data could not be written durably: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }
}
