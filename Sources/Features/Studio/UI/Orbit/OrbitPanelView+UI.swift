import AppKit
import OrbitServerRuntime
import SwiftUI

struct OrbitMeetingFollowUpReferenceParseResult: Equatable {
  let references: [OrbitPhase1MeetingReferenceSpec]
  let invalidLines: [String]
}

struct OrbitMeetingCompletionDraftSeed: Equatable {
  let meetingSummaryDraft: String
  let meetingOutcome: OrbitPhase1MeetingCompletionOutcome
  let meetingDecisionTitleDraft: String
  let meetingDecisionBodyDraft: String
  let meetingNoDecisionDetailDraft: String
  let meetingOpenQuestionsDraft: String
  let meetingFollowUpReferencesDraft: String
  let syncedMeetingDraftPostID: String?
}

extension OrbitPanelView {
  static func parseMeetingFollowUpReferencesDraft(
    _ draft: String
  ) -> OrbitMeetingFollowUpReferenceParseResult {
    var references = [OrbitPhase1MeetingReferenceSpec]()
    var invalidLines = [String]()

    for rawLine in draft.split(separator: "\n") {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !line.isEmpty else {
        continue
      }

      let parts = line.split(separator: "|", maxSplits: 1).map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      let leftPart = parts.first ?? ""
      let title = parts.count > 1 ? parts[1] : nil
      let leftTokens = leftPart.split(separator: " ", maxSplits: 1).map(String.init)

      guard
        leftTokens.count == 2,
        let referenceType = OrbitReferenceType(rawValue: leftTokens[0]),
        !leftTokens[1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        invalidLines.append(line)
        continue
      }

      references.append(
        OrbitPhase1MeetingReferenceSpec(
          referenceType: referenceType,
          target: leftTokens[1].trimmingCharacters(in: .whitespacesAndNewlines),
          title: title?.isEmpty == false ? title : nil
        )
      )
    }

    return OrbitMeetingFollowUpReferenceParseResult(
      references: references,
      invalidLines: invalidLines
    )
  }

  static func meetingFollowUpReferenceValidationMessage(
    for parseResult: OrbitMeetingFollowUpReferenceParseResult
  ) -> String? {
    guard !parseResult.invalidLines.isEmpty else {
      return nil
    }

    return
      "Each follow-up reference must use `type target | title` with a supported type such as `doc`, `file`, `url`, `issue`, `commit`, or `external_note`."
  }

  static func shouldSyncMeetingCompletionDrafts(
    force: Bool,
    meetingCompletionDraftsDirty: Bool,
    activeMeetingPostID: String?,
    syncedMeetingDraftPostID: String?
  ) -> Bool {
    force || !meetingCompletionDraftsDirty || activeMeetingPostID != syncedMeetingDraftPostID
  }

  static func meetingCompletionDraftSeed(
    from workspace: OrbitWorkspace
  ) -> OrbitMeetingCompletionDraftSeed {
    let meetingOutcome: OrbitPhase1MeetingCompletionOutcome

    switch workspace.activeMeetingOutcomeRecord?.outcomeState {
    case .noDecisionRecorded:
      meetingOutcome = .noDecision
    default:
      meetingOutcome = .decision
    }

    return OrbitMeetingCompletionDraftSeed(
      meetingSummaryDraft: workspace.activeMeetingSummaryRecord?.body ?? "",
      meetingOutcome: meetingOutcome,
      meetingDecisionTitleDraft: workspace.activeMeetingDecisionRecord?.title ?? "",
      meetingDecisionBodyDraft: workspace.activeMeetingDecisionRecord?.body ?? "",
      meetingNoDecisionDetailDraft: workspace.activeMeetingOutcomeRecord?.detail ?? "",
      meetingOpenQuestionsDraft: workspace.activeMeetingOpenQuestionRecords
        .map(\.body)
        .joined(separator: "\n"),
      meetingFollowUpReferencesDraft: workspace.activeMeetingReferenceRecords
        .map { reference in
          if let title = reference.title, !title.isEmpty {
            return "\(reference.referenceType.rawValue) \(reference.target) | \(title)"
          }

          return "\(reference.referenceType.rawValue) \(reference.target)"
        }
        .joined(separator: "\n"),
      syncedMeetingDraftPostID: workspace.activePostID
        ?? workspace.activeMeetingStatusRecord?.postID
        ?? workspace.activeMeetingSummaryRecord?.postID
        ?? workspace.activeMeetingOutcomeRecord?.postID
    )
  }

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
    guard let addressedParticipantID else {
      return []
    }

    return Set(
      OrbitParticipantResponseBridge.addressedParticipants(
        in: orbitWorkspace,
        addressedParticipantID: addressedParticipantID
      ).map(\.id)
    )
  }

  var activeThread: OrbitConversationThread? {
    orbitWorkspace.activeThread
  }

  var isMeetingRoom: Bool {
    orbitWorkspace.activeMeetingStatusRecord != nil
      || orbitWorkspace.activeMeetingSummaryRecord != nil
      || orbitWorkspace.activeMeetingOutcomeRecord != nil
  }

  var isMeetingCompletionEditable: Bool {
    guard serverBackedRoomClient != nil else {
      return false
    }

    guard let status = orbitWorkspace.activeMeetingStatusRecord?.status else {
      return false
    }

    return status == .created || status == .active || status == .summarizing
  }

  var activeMeetingPostID: String? {
    orbitWorkspace.activePostID
      ?? orbitWorkspace.activeMeetingStatusRecord?.postID
      ?? orbitWorkspace.activeMeetingSummaryRecord?.postID
      ?? orbitWorkspace.activeMeetingOutcomeRecord?.postID
  }

  var parsedMeetingOpenQuestions: [String] {
    meetingOpenQuestionsDraft
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  var meetingFollowUpReferenceParseResult: OrbitMeetingFollowUpReferenceParseResult {
    Self.parseMeetingFollowUpReferencesDraft(meetingFollowUpReferencesDraft)
  }

  var parsedMeetingFollowUpReferences: [OrbitPhase1MeetingReferenceSpec] {
    meetingFollowUpReferenceParseResult.references
  }

  var meetingFollowUpReferenceValidationMessage: String? {
    Self.meetingFollowUpReferenceValidationMessage(
      for: meetingFollowUpReferenceParseResult
    )
  }

  var canSubmitMeetingCompletion: Bool {
    let summaryBody = meetingSummaryDraft.trimmingCharacters(in: .whitespacesAndNewlines)

    guard
      isMeetingCompletionEditable,
      !isSubmittingMeetingCompletion,
      !summaryBody.isEmpty,
      meetingFollowUpReferenceValidationMessage == nil
    else {
      return false
    }

    switch meetingOutcome {
    case .decision:
      return !meetingDecisionTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !meetingDecisionBodyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .noDecision:
      return true
    }
  }

  func markMeetingCompletionDraftsDirty() {
    meetingCompletionDraftsDirty = true
  }

  var meetingSummaryDraftBinding: Binding<String> {
    Binding(
      get: { meetingSummaryDraft },
      set: { newValue in
        meetingSummaryDraft = newValue
        markMeetingCompletionDraftsDirty()
      }
    )
  }

  var meetingOutcomeBinding: Binding<OrbitPhase1MeetingCompletionOutcome> {
    Binding(
      get: { meetingOutcome },
      set: { newValue in
        meetingOutcome = newValue
        markMeetingCompletionDraftsDirty()
      }
    )
  }

  var meetingDecisionTitleDraftBinding: Binding<String> {
    Binding(
      get: { meetingDecisionTitleDraft },
      set: { newValue in
        meetingDecisionTitleDraft = newValue
        markMeetingCompletionDraftsDirty()
      }
    )
  }

  var meetingDecisionBodyDraftBinding: Binding<String> {
    Binding(
      get: { meetingDecisionBodyDraft },
      set: { newValue in
        meetingDecisionBodyDraft = newValue
        markMeetingCompletionDraftsDirty()
      }
    )
  }

  var meetingNoDecisionDetailDraftBinding: Binding<String> {
    Binding(
      get: { meetingNoDecisionDetailDraft },
      set: { newValue in
        meetingNoDecisionDetailDraft = newValue
        markMeetingCompletionDraftsDirty()
      }
    )
  }

  var meetingOpenQuestionsDraftBinding: Binding<String> {
    Binding(
      get: { meetingOpenQuestionsDraft },
      set: { newValue in
        meetingOpenQuestionsDraft = newValue
        markMeetingCompletionDraftsDirty()
      }
    )
  }

  var meetingFollowUpReferencesDraftBinding: Binding<String> {
    Binding(
      get: { meetingFollowUpReferencesDraft },
      set: { newValue in
        meetingFollowUpReferencesDraft = newValue
        markMeetingCompletionDraftsDirty()
      }
    )
  }

  var workspaceHeaderCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Orbit Command Center")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(orbitWorkspace.displayName)
          .font(.system(size: 30, weight: .semibold))

        Text("Workspace boundary")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(Color.accentColor.opacity(0.12), in: Capsule())
      }

      Text(orbitWorkspace.purpose)
        .font(.body)
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        shellSummaryPill(
          icon: "person.3.fill",
          title: "Roster",
          value: "\(sortedParticipants.count) collaborators"
        )

        shellSummaryPill(
          icon: "bubble.left.and.bubble.right.fill",
          title: "Discussion",
          value: activeThread?.interactionMode.displayText ?? "No active thread"
        )

        shellSummaryPill(
          icon: "scope",
          title: "Trace",
          value: "Inspectable"
        )

        if let meetingStatus = orbitWorkspace.activeMeetingStatusRecord {
          shellSummaryPill(
            icon: "person.2.wave.2.fill",
            title: "Meeting",
            value: meetingStatus.status.displayText
          )
        }

        if let meetingOutcome = orbitWorkspace.activeMeetingOutcomeRecord {
          shellSummaryPill(
            icon: "checklist",
            title: "Outcome",
            value: meetingOutcome.outcomeState.displayText
          )
        }

        if isMeetingRoom {
          shellSummaryPill(
            icon: "questionmark.bubble.fill",
            title: "Open Questions",
            value: "\(orbitWorkspace.activeMeetingOpenQuestionRecords.count)"
          )

          shellSummaryPill(
            icon: "link",
            title: "References",
            value: "\(orbitWorkspace.activeMeetingReferenceRecords.count)"
          )
        }
      }

      if let activeThread {
        HStack(spacing: 10) {
          Label(activeThread.title, systemImage: "bubble.left.and.bubble.right")
            .font(.subheadline.weight(.medium))

          Text("\(activeThread.messages.count) turns")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.10), in: Capsule())
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [
          Color.accentColor.opacity(0.10),
          Color(nsColor: .controlBackgroundColor),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 18)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
  }

  var rosterCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Founding Roster")
          .font(.headline)

        Text("Persistent collaborators in the Orbit workspace.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .top, spacing: 12) {
        ForEach(sortedParticipants) { participant in
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              Circle()
                .fill(color(for: participant))
                .frame(width: 10, height: 10)

              Text(participant.displayName)
                .font(.subheadline.weight(.semibold))

              Spacer(minLength: 0)

              if activeParticipantIDs.contains(participant.id) {
                shellStatusBadge(
                  title: "Recent",
                  tint: color(for: participant).opacity(0.18),
                  foreground: color(for: participant)
                )
              }
            }

            Text(participant.roleLabel)
              .font(.caption)
              .foregroundStyle(.secondary)

            HStack(spacing: 6) {
              shellStatusBadge(
                title: participant.availability.displayText,
                tint: Color.secondary.opacity(0.10),
                foreground: .secondary
              )

              if addressedParticipantIDs.contains(participant.id) {
                shellStatusBadge(
                  title: "Addressed",
                  tint: Color.accentColor.opacity(0.14),
                  foreground: .accentColor
                )
              }
            }
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

  @ViewBuilder
  var meetingOutputsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Meeting Outputs")
          .font(.headline)

        Text("Canonical meeting summary, explicit outcome, member roster, and follow-up evidence.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        if let meetingStatus = orbitWorkspace.activeMeetingStatusRecord {
          shellStatusBadge(
            title: meetingStatus.status.displayText,
            tint: Color.accentColor.opacity(0.12),
            foreground: .accentColor
          )
        }

        if let meetingOutcome = orbitWorkspace.activeMeetingOutcomeRecord {
          shellStatusBadge(
            title: meetingOutcome.outcomeState.displayText,
            tint: Color.secondary.opacity(0.10),
            foreground: .secondary
          )
        }
      }

      if isMeetingCompletionEditable {
        editableMeetingOutputsForm
      } else {
        readOnlyMeetingOutputs
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal, 16)
  }

  @ViewBuilder
  var editableMeetingOutputsForm: some View {
    VStack(alignment: .leading, spacing: 12) {
      meetingOutputSection(
        title: "Summary",
        caption: "This updates the single canonical meeting summary shell in place."
      ) {
        TextField(
          "Summarize the meeting outcome",
          text: meetingSummaryDraftBinding,
          axis: .vertical
        )
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
      }

      meetingOutputSection(
        title: "Outcome",
        caption: "Choose one explicit completion result for this meeting."
      ) {
        Picker(
          "Outcome",
          selection: meetingOutcomeBinding
        ) {
          Text("Decision")
            .tag(OrbitPhase1MeetingCompletionOutcome.decision)

          Text("No Decision")
            .tag(OrbitPhase1MeetingCompletionOutcome.noDecision)
        }
        .pickerStyle(.segmented)

        switch meetingOutcome {
        case .decision:
          TextField(
            "Decision title",
            text: meetingDecisionTitleDraftBinding
          )
          .textFieldStyle(.roundedBorder)

          TextField(
            "Decision detail",
            text: meetingDecisionBodyDraftBinding,
            axis: .vertical
          )
          .textFieldStyle(.roundedBorder)
          .lineLimit(2...5)
        case .noDecision:
          TextField(
            "Optional no-decision detail",
            text: meetingNoDecisionDetailDraftBinding,
            axis: .vertical
          )
          .textFieldStyle(.roundedBorder)
          .lineLimit(2...4)
        }
      }

      meetingParticipantsSection

      meetingOutputSection(
        title: "Open Questions",
        caption: "One question per line."
      ) {
        TextField(
          "Question one\nQuestion two",
          text: meetingOpenQuestionsDraftBinding,
          axis: .vertical
        )
        .textFieldStyle(.roundedBorder)
        .lineLimit(2...5)
      }

      meetingOutputSection(
        title: "Follow-Up References",
        caption: "Use `type target | title`. Example: `doc Docs/Orbit/README.md | Packet notes`."
      ) {
        VStack(alignment: .leading, spacing: 8) {
          TextField(
            "doc Docs/Orbit/README.md | Packet notes",
            text: meetingFollowUpReferencesDraftBinding,
            axis: .vertical
          )
          .textFieldStyle(.roundedBorder)
          .lineLimit(2...5)

          if let meetingFollowUpReferenceValidationMessage {
            Text(meetingFollowUpReferenceValidationMessage)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }
      }

      HStack {
        Spacer()

        Button {
          submitMeetingCompletion()
        } label: {
          Label(
            isSubmittingMeetingCompletion ? "Completing..." : "Complete Meeting",
            systemImage: "checkmark.circle.fill"
          )
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSubmitMeetingCompletion)
      }
    }
  }

  @ViewBuilder
  var readOnlyMeetingOutputs: some View {
    VStack(alignment: .leading, spacing: 12) {
      meetingOutputSection(
        title: "Summary",
        caption: orbitWorkspace.activeMeetingSummaryRecord?.createdAt.formatted() ?? "Inspectable after reload."
      ) {
        Text(orbitWorkspace.activeMeetingSummaryRecord?.body ?? "Summary pending.")
          .font(.body)
          .textSelection(.enabled)
      }

      meetingOutputSection(
        title: "Outcome",
        caption: orbitWorkspace.activeMeetingOutcomeRecord?.recordedAt.formatted() ?? "Pending"
      ) {
        VStack(alignment: .leading, spacing: 8) {
          if let meetingOutcome = orbitWorkspace.activeMeetingOutcomeRecord {
            Text(meetingOutcome.outcomeState.displayText)
              .font(.subheadline.weight(.semibold))

            if let detail = meetingOutcome.detail, !detail.isEmpty {
              Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
            }
          } else {
            Text("Pending")
              .font(.body)
              .foregroundStyle(.secondary)
          }

          if let decision = orbitWorkspace.activeMeetingDecisionRecord {
            VStack(alignment: .leading, spacing: 4) {
              Text(decision.title)
                .font(.subheadline.weight(.semibold))
              Text(decision.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
          }
        }
      }

      meetingParticipantsSection

      meetingOutputSection(
        title: "Open Questions",
        caption: "\(orbitWorkspace.activeMeetingOpenQuestionRecords.count) pending"
      ) {
        if orbitWorkspace.activeMeetingOpenQuestionRecords.isEmpty {
          Text("No open questions recorded.")
            .font(.body)
            .foregroundStyle(.secondary)
        } else {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(orbitWorkspace.activeMeetingOpenQuestionRecords) { question in
              Text("• \(question.body)")
                .font(.body)
                .textSelection(.enabled)
            }
          }
        }
      }

      meetingOutputSection(
        title: "Follow-Up References",
        caption: "\(orbitWorkspace.activeMeetingReferenceRecords.count) linked"
      ) {
        if orbitWorkspace.activeMeetingReferenceRecords.isEmpty {
          Text("No follow-up references recorded.")
            .font(.body)
            .foregroundStyle(.secondary)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(orbitWorkspace.activeMeetingReferenceRecords) { reference in
              VStack(alignment: .leading, spacing: 2) {
                Text(reference.title ?? reference.target)
                  .font(.subheadline.weight(.semibold))
                Text("\(reference.referenceType.rawValue): \(reference.target)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .textSelection(.enabled)
              }
            }
          }
        }
      }
    }
  }

  func meetingOutputSection<Content: View>(
    title: String,
    caption: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(caption)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      content()
    }
    .padding(12)
    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
  }

  @ViewBuilder
  var meetingParticipantsSection: some View {
    meetingOutputSection(
      title: "Participants",
      caption: "Projected meeting roster and roles."
    ) {
      if orbitWorkspace.activeMeetingMemberRecords.isEmpty {
        Text("No projected meeting participants yet.")
          .font(.body)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(orbitWorkspace.activeMeetingMemberRecords) { member in
            HStack(alignment: .top, spacing: 8) {
              Text(
                orbitWorkspace.participant(id: member.participantID ?? "")?.displayName
                  ?? member.participantID
                  ?? "Unknown collaborator"
              )
              .font(.subheadline.weight(.semibold))

              shellStatusBadge(
                title: member.participationRole.displayText,
                tint: Color.secondary.opacity(0.10),
                foreground: .secondary
              )

              Spacer(minLength: 0)
            }

            Text(member.selectedReason)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  var conversationCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Active Discussion")
          .font(.headline)

        Text("One durable room thread with visible speaker attribution and lightweight trace context.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if let activeThread {
        if activeThread.messages.isEmpty {
          emptyConversationState(activeThread: activeThread)
        } else {
          HStack(spacing: 8) {
            shellStatusBadge(
              title: activeThread.title,
              tint: Color.accentColor.opacity(0.12),
              foreground: .accentColor
            )

            shellStatusBadge(
              title: "\(activeThread.messages.count) turns",
              tint: Color.secondary.opacity(0.10),
              foreground: .secondary
            )

            shellStatusBadge(
              title: activeThread.interactionMode.displayText,
              tint: Color.secondary.opacity(0.10),
              foreground: .secondary
            )
          }

          ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
              ForEach(activeThread.messages.sorted { $0.order < $1.order }) { message in
                messageCard(message)
              }
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
    let accentColor = messageAccentColor(for: speaker, kind: message.kind)

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
          Text(message.kind == .participantResponse ? "for \(addressLabel)" : "to \(addressLabel)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if let activation {
          shellStatusBadge(
            title: activation.triggerSource.displayText,
            tint: Color.secondary.opacity(0.10),
            foreground: .secondary
          )
        }
      }

      Text(message.body)
        .font(.body)
        .textSelection(.enabled)

      if let activation {
        DisclosureGroup(
          isExpanded: traceDisclosureBinding(for: message.id)
        ) {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(activation.traceSummaryLines(contractSnapshot: contractSnapshot), id: \.self) { line in
              Text(line)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
          }
          .padding(.top, 4)
        } label: {
          traceDisclosureLabel(
            title: "Why this response?",
            subtitle: activation.triggerSource.displayText
          )
        }
      }

      if let activationFailure {
        DisclosureGroup(
          isExpanded: traceDisclosureBinding(for: message.id)
        ) {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(activationFailure.traceSummaryLines, id: \.self) { line in
              Text(line)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
          }
          .padding(.top, 4)
        } label: {
          traceDisclosureLabel(
            title: "Why blocked?",
            subtitle: activationFailure.failureReason.displayText
          )
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 12)
        .fill(accentColor)
        .frame(width: 4)
        .padding(.vertical, 6)
    }
  }

  var composerCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Send Into Orbit")
          .font(.headline)

        Text("Choose the current thread, one collaborator, or the founding group.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Picker(
        "Address",
        selection: $addressedParticipantID
      ) {
        Text("Current Thread")
          .tag(nil as String?)

        Text(OrbitAddressTargetID.foundingGroup.displayText)
          .tag(OrbitAddressTargetID.foundingGroup.rawValue as String?)

        ForEach(
          sortedParticipants.filter { $0.id != OrbitParticipantID.aj.rawValue }
        ) { participant in
          Text(participant.displayName)
            .tag(participant.id as String?)
        }
      }
      .pickerStyle(.segmented)

      Text(deliveryTargetSummary)
        .font(.caption)
        .foregroundStyle(.secondary)

      interactionRoutingCard

      if showsMeetingPromotionToggle {
        Toggle(
          isOn: $promoteToMeetingRoom
        ) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Promote into meeting room")
              .font(.subheadline.weight(.semibold))
            Text("Create a dedicated meeting room for this group target before sending the turn.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .toggleStyle(.switch)
      }

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
          Label("Send Into Orbit", systemImage: "paperplane.fill")
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

    return orbitWorkspace.displayName(forAddressedTargetID: addressedParticipantID)
  }

  var deliveryTargetSummary: String {
    if addressedParticipantID == nil {
      return "Delivery target: current thread"
    }

    if let addressedParticipantID {
      let targetResolution = OrbitParticipantResponseBridge.targetResolution(
        in: orbitWorkspace,
        addressedParticipantID: addressedParticipantID
      )
      return "Delivery target: \(targetResolution.targetDisplayName.lowercased())"
    }

    return "Delivery target: \(addressLabel(for: addressedParticipantID) ?? "selected collaborator")"
  }

  var targetResolutionForComposer: OrbitTargetResolution? {
    addressedParticipantID.map { addressedParticipantID in
      OrbitParticipantResponseBridge.targetResolution(
        in: orbitWorkspace,
        addressedParticipantID: addressedParticipantID
      )
    }
  }

  var canPromoteTargetToMeetingRoom: Bool {
    guard
      let targetResolution = targetResolutionForComposer,
      targetResolution.status == .resolved
    else {
      return false
    }

    return targetResolution.targetKind == .team
      || targetResolution.targetKind == .squad
  }

  var showsMeetingPromotionToggle: Bool {
    serverBackedRoomClient != nil && canPromoteTargetToMeetingRoom
  }

  @ViewBuilder
  var interactionRoutingCard: some View {
    let targetResolution = targetResolutionForComposer

    switch targetResolution?.targetKind {
    case nil:
      VStack(alignment: .leading, spacing: 6) {
        Text("Current thread routing")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(
          "Orbit keeps the turn in the active room and routes the next response through the current thread steward so the exchange stays visible and reviewable."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(10)
      .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    case .some(.team), .some(.squad):
      VStack(alignment: .leading, spacing: 6) {
        Text("Lightweight exchange")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(
          "Orbit resolves this target from persisted workspace membership, records a visible target-expansion summary, and then invites the included participants into the same room thread."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(10)
      .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    case .some(.collaborator):
      VStack(alignment: .leading, spacing: 6) {
        Text("Direct collaborator routing")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(
          "Orbit sends this turn only to \(addressLabel(for: addressedParticipantID) ?? "the selected collaborator") and records the activation as a direct address."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(10)
      .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
  }

  func shellSummaryPill(
    icon: String,
    title: String,
    value: String
  ) -> some View {
    Label {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(value)
          .font(.caption.weight(.medium))
      }
    } icon: {
      Image(systemName: icon)
        .font(.caption.weight(.semibold))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color(nsColor: .windowBackgroundColor).opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
  }

  func shellStatusBadge(
    title: String,
    tint: Color,
    foreground: Color
  ) -> some View {
    Text(title)
      .font(.caption.weight(.medium))
      .foregroundStyle(foreground)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(tint, in: Capsule())
  }

  @ViewBuilder
  func emptyConversationState(
    activeThread: OrbitConversationThread
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Orbit is ready for the first room discussion.")
        .font(.headline)

      Text(
        "Use the current thread for an open room turn, address one collaborator directly, or invite the founding group into a lightweight exchange."
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        shellStatusBadge(
          title: activeThread.title,
          tint: Color.accentColor.opacity(0.12),
          foreground: .accentColor
        )

        shellStatusBadge(
          title: "Current thread ready",
          tint: Color.secondary.opacity(0.10),
          foreground: .secondary
        )

        shellStatusBadge(
          title: OrbitAddressTargetID.foundingGroup.displayText,
          tint: Color.secondary.opacity(0.10),
          foreground: .secondary
        )
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
  }

  func messageAccentColor(
    for participant: OrbitParticipant?,
    kind: OrbitMessageKind
  ) -> Color {
    switch kind {
    case .user:
      return Color.orange.opacity(0.75)
    case .participantResponse:
      if let participant {
        return color(for: participant).opacity(0.85)
      }
      return Color.accentColor.opacity(0.75)
    case .systemEvent:
      return Color.secondary.opacity(0.55)
    }
  }

  func traceDisclosureBinding(
    for messageID: String
  ) -> Binding<Bool> {
    Binding(
      get: {
        expandedTraceMessageIDs.contains(messageID)
      },
      set: { isExpanded in
        if isExpanded {
          expandedTraceMessageIDs.insert(messageID)
        } else {
          expandedTraceMessageIDs.remove(messageID)
        }
      }
    )
  }

  func traceDisclosureLabel(
    title: String,
    subtitle: String
  ) -> some View {
    HStack(spacing: 8) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      shellStatusBadge(
        title: subtitle,
        tint: Color.secondary.opacity(0.10),
        foreground: .secondary
      )
    }
  }

  func syncMeetingCompletionDrafts(
    force: Bool = false
  ) {
    guard
      Self.shouldSyncMeetingCompletionDrafts(
        force: force,
        meetingCompletionDraftsDirty: meetingCompletionDraftsDirty,
        activeMeetingPostID: activeMeetingPostID,
        syncedMeetingDraftPostID: syncedMeetingDraftPostID
      )
    else {
      return
    }

    let seed = Self.meetingCompletionDraftSeed(from: orbitWorkspace)
    meetingSummaryDraft = seed.meetingSummaryDraft
    meetingOutcome = seed.meetingOutcome
    meetingDecisionTitleDraft = seed.meetingDecisionTitleDraft
    meetingDecisionBodyDraft = seed.meetingDecisionBodyDraft
    meetingNoDecisionDetailDraft = seed.meetingNoDecisionDetailDraft
    meetingOpenQuestionsDraft = seed.meetingOpenQuestionsDraft
    meetingFollowUpReferencesDraft = seed.meetingFollowUpReferencesDraft
    syncedMeetingDraftPostID = seed.syncedMeetingDraftPostID
    meetingCompletionDraftsDirty = false
  }

  func submitMeetingCompletion() {
    guard canSubmitMeetingCompletion, let serverBackedRoomClient else {
      return
    }

    Task {
      await submitMeetingCompletionThroughServer(using: serverBackedRoomClient)
    }
  }

  @MainActor
  func submitMeetingCompletionThroughServer(
    using client: OrbitServerBackedRoomClient
  ) async {
    guard canSubmitMeetingCompletion else {
      return
    }

    guard !isSubmittingMeetingCompletion else {
      return
    }

    isSubmittingMeetingCompletion = true
    defer {
      isSubmittingMeetingCompletion = false
    }

    do {
      var coordinator = serverBackedRoomCoordinator
      try await coordinator.completeMeeting(
        scope: serverBackedRoomScope,
        request: OrbitServerBackedMeetingCompletionRequest(
          summaryBody: meetingSummaryDraft,
          outcome: meetingOutcome,
          decisionTitle: meetingDecisionTitleDraft,
          decisionBody: meetingDecisionBodyDraft,
          noDecisionDetail: meetingNoDecisionDetailDraft,
          openQuestions: parsedMeetingOpenQuestions,
          followUpReferences: parsedMeetingFollowUpReferences,
          completedByParticipantType: .user,
          completedByParticipantID: OrbitParticipantID.aj.rawValue
        ),
        client: client
      )
      serverBackedRoomCoordinator = coordinator
      if let projectedWorkspace = coordinator.roomState.projectedWorkspace {
        orbitWorkspace = projectedWorkspace
      }
      meetingCompletionDraftsDirty = false
      syncMeetingCompletionDrafts(force: true)
      persistenceMessage = nil
      persistenceIsError = false
    } catch {
      persistenceMessage =
        "Orbit blocked the meeting completion because the canonical server write path failed: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }

  func sendMessage() {
    if let serverBackedRoomClient {
      Task {
        await sendMessageThroughServer(using: serverBackedRoomClient)
      }
      return
    }

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
      promoteToMeetingRoom = false
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

  @MainActor
  func sendMessageThroughServer(
    using client: OrbitServerBackedRoomClient
  ) async {
    let messageBody = draftMessageBody.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !messageBody.isEmpty else {
      return
    }

    do {
      guard let workspaceURL = workspaceStore.workspaceURL else {
        throw OrbitWorkspacePersistenceError.noWorkspaceSelected
      }

      var coordinator = serverBackedRoomCoordinator
      try await coordinator.appendConversationTurn(
        scope: serverBackedRoomScope,
        authorID: OrbitParticipantID.aj.rawValue,
        body: messageBody,
        addressedParticipantID: addressedParticipantID,
        promotion:
          promoteToMeetingRoom
          ? OrbitServerBackedRoomPromotionRequest()
          : nil,
        resolveContract: { participant in
          try OrbitContractResolver.resolve(
            participant: participant,
            workspaceURL: workspaceURL
          )
        },
        client: client
      )
      serverBackedRoomCoordinator = coordinator
      if let projectedWorkspace = coordinator.roomState.projectedWorkspace {
        orbitWorkspace = projectedWorkspace
      }
      draftMessageBody = ""
      promoteToMeetingRoom = false
      persistenceMessage = nil
      persistenceIsError = false
    } catch let error as OrbitContractResolutionError {
      persistenceMessage =
        "Orbit blocked the send because the collaborator contract could not be resolved: \(error.localizedDescription)"
      persistenceIsError = true
    } catch {
      persistenceMessage =
        "Orbit blocked the send because the canonical server write path failed: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }
}
