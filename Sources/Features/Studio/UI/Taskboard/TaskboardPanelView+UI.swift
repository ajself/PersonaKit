import Foundation
import SwiftUI

extension TaskboardPanelView {
  var sortedLanes: [TaskboardLane] {
    board.lanes.sorted {
      if $0.order == $1.order {
        return $0.id < $1.id
      }

      return $0.order < $1.order
    }
  }

  var totalTicketCount: Int {
    board.lanes.reduce(0) { partialResult, lane in
      partialResult + lane.tickets.count
    }
  }

  var filteredTicketCount: Int {
    board.lanes.reduce(0) { partialResult, lane in
      partialResult + filteredTickets(in: lane).count
    }
  }

  var allTicketLabels: [String] {
    Set(
      board.lanes
        .flatMap(\.tickets)
        .flatMap(\.labels)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    )
    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  var isFilteringActive: Bool {
    activeLabelFilter != nil
      || dueDateFilter != .all
      || !ownerFilterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !keywordFilterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var headerBar: some View {
    HStack(alignment: .center, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(board.name)
          .font(.title3)
          .fontWeight(.semibold)
        Text("Admin planning board")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      Menu {
        Section("Lane Templates") {
          ForEach(TaskboardLaneTemplate.defaults) { template in
            Button {
              createLane(from: template)
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(template.title)
                Text(template.detail)
                  .font(.caption)
              }
            }
          }
        }

        Divider()

        Button("Custom Lane…") {
          laneEditorDraft = LaneEditorDraft.create()
        }
      } label: {
        Label("Add Lane", systemImage: "plus")
      }

      Button {
        openTicketComposerForSelectedLane()
      } label: {
        Label("New Ticket", systemImage: "plus.rectangle.on.rectangle")
      }
      .help("Create ticket in selected lane (Shift-Command-T)")
      .keyboardShortcut("t", modifiers: [.shift, .command])
      .disabled(selectedLaneID == nil)

      Button {
        focusKeywordSearch()
      } label: {
        Label("Search", systemImage: "magnifyingglass")
      }
      .help("Focus board search (Command-F)")
      .keyboardShortcut("f", modifiers: [.command])

      Menu {
        Section("Lane") {
          Button("Custom Lane…") {
            laneEditorDraft = LaneEditorDraft.create()
          }
          .keyboardShortcut("l", modifiers: [.shift, .command])

          Button("Edit Selected Lane") {
            editSelectedLane()
          }
          .keyboardShortcut("e", modifiers: [.shift, .command])
          .disabled(selectedLaneID == nil)

          Button("Select Previous Lane") {
            selectAdjacentLane(direction: -1)
          }
          .keyboardShortcut(.leftArrow, modifiers: [.option, .command])
          .disabled(sortedLanes.isEmpty)

          Button("Select Next Lane") {
            selectAdjacentLane(direction: 1)
          }
          .keyboardShortcut(.rightArrow, modifiers: [.option, .command])
          .disabled(sortedLanes.isEmpty)
        }

        Section("Selected Ticket") {
          Button("Select Previous Ticket") {
            selectAdjacentTicket(direction: -1)
          }
          .keyboardShortcut(.upArrow, modifiers: [.shift, .option, .command])
          .disabled(visibleTicketsInSelectedLane().isEmpty)

          Button("Select Next Ticket") {
            selectAdjacentTicket(direction: 1)
          }
          .keyboardShortcut(.downArrow, modifiers: [.shift, .option, .command])
          .disabled(visibleTicketsInSelectedLane().isEmpty)

          Button("Quick Edit Selected Ticket") {
            openInlineQuickEditForSelectedTicket()
          }
          .keyboardShortcut(.return, modifiers: [.command])
          .disabled(selectedTicketID == nil)

          Divider()

          Button("Reorder Up") {
            moveSelectedTicketWithinLane(direction: -1)
          }
          .keyboardShortcut(.upArrow, modifiers: [.control, .command])
          .disabled(!canMoveSelectedTicketWithinLane(direction: -1))

          Button("Reorder Down") {
            moveSelectedTicketWithinLane(direction: 1)
          }
          .keyboardShortcut(.downArrow, modifiers: [.control, .command])
          .disabled(!canMoveSelectedTicketWithinLane(direction: 1))

          Button("Handoff Left") {
            moveSelectedTicketBetweenLanes(direction: -1)
          }
          .keyboardShortcut(.leftArrow, modifiers: [.control, .command])
          .disabled(!canMoveSelectedTicketBetweenLanes(direction: -1))

          Button("Handoff Right") {
            moveSelectedTicketBetweenLanes(direction: 1)
          }
          .keyboardShortcut(.rightArrow, modifiers: [.control, .command])
          .disabled(!canMoveSelectedTicketBetweenLanes(direction: 1))
        }

        Section("Board") {
          Button("Reset Board") {
            resetBoard()
          }

          Button("Generate Night Report") {
            generateNightShiftReport()
          }
        }
      } label: {
        Label("Actions", systemImage: "ellipsis.circle")
      }
      .help("Open board actions, selection controls, and keyboard-driven movement shortcuts.")
    }
    .padding(.horizontal, 16)
  }

  var filterBar: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        TextField("Search tickets and lanes", text: $keywordFilterText)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 260)
          .focused($focusedField, equals: .keywordSearch)

        TextField("Assignee", text: $ownerFilterText)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 180)

        Picker("Due", selection: $dueDateFilter) {
          ForEach(DueDateFilter.allCases) { option in
            Text(option.title).tag(option)
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)

        Menu {
          Button("All Labels") {
            activeLabelFilter = nil
          }

          if allTicketLabels.isEmpty {
            Text("No labels yet")
          } else {
            ForEach(allTicketLabels, id: \.self) { label in
              Button(label) {
                activeLabelFilter = label
              }
            }
          }
        } label: {
          Label(activeLabelFilter ?? "All Labels", systemImage: "tag")
        }

        Button("Clear Filters") {
          clearFilters()
        }
        .disabled(!isFilteringActive)

        Spacer(minLength: 0)
      }

      if let keywordSearchResult {
        Text(
          "Search matched \(keywordSearchResult.matchingLaneIDs.count) lanes and \(keywordSearchResult.matchingTicketIDs.count) tickets"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      if isFilteringActive {
        Text("Showing \(filteredTicketCount) of \(totalTicketCount) tickets")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 16)
  }

  func laneCard(
    _ lane: TaskboardLane,
    laneIndex: Int,
    laneCount: Int
  ) -> some View {
    let visibleTickets = filteredTickets(in: lane)

    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 8) {
        Text(lane.title)
          .font(.headline)

        Spacer(minLength: 4)

        Text(ticketCountLabel(for: lane, visibleCount: visibleTickets.count))
          .font(.caption)
          .foregroundStyle(
            laneIsOverWIPLimit(lane) ? .red : .secondary
          )
      }

      HStack(spacing: 8) {
        Button {
          ticketEditorDraft = TicketEditorDraft.create(laneID: lane.id)
        } label: {
          Label("Add Ticket", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Menu {
          Button("Edit Lane…") {
            laneEditorDraft = LaneEditorDraft.edit(lane: lane)
          }

          Button(lane.isCollapsed ? "Expand Lane" : "Collapse Lane") {
            toggleLaneCollapsed(laneID: lane.id)
          }

          Button("Move Left") {
            moveLane(laneID: lane.id, direction: -1)
          }
          .disabled(laneIndex == 0)

          Button("Move Right") {
            moveLane(laneID: lane.id, direction: 1)
          }
          .disabled(laneIndex >= laneCount - 1)

          Divider()

          Button("Delete Lane", role: .destructive) {
            pendingLaneDeletion = lane
          }
        } label: {
          Label("Lane Actions", systemImage: "ellipsis.circle")
        }
        .controlSize(.small)
      }

      if lane.isCollapsed {
        Text("Lane collapsed")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.vertical, 8)
      } else {
        ForEach(visibleTickets) { ticket in
          ticketCard(
            ticket,
            lane: lane
          )
        }

        if visibleTickets.isEmpty {
          Text(isFilteringActive && !lane.tickets.isEmpty ? "No matching tickets" : "No tickets yet")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(width: 280, alignment: .topLeading)
    .frame(minHeight: 260, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(
          laneOutlineColor(for: lane.id),
          lineWidth: 2
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(activeDropLaneID == lane.id ? Color.accentColor.opacity(0.08) : .clear)
    )
    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .onTapGesture {
      selectedLaneID = lane.id
      if !lane.tickets.contains(where: { $0.id == selectedTicketID }) {
        selectedTicketID = nil
      }
    }
    .dropDestination(
      for: String.self,
      action: { items, _ in
        handleTicketDrop(items, destinationLaneID: lane.id)
      },
      isTargeted: { isTargeted in
        if isTargeted {
          activeDropLaneID = lane.id
          activeDropTicketID = nil
        } else if activeDropLaneID == lane.id {
          activeDropLaneID = nil
        }
      }
    )
  }

  func ticketCard(
    _ ticket: TaskboardTicket,
    lane: TaskboardLane
  ) -> some View {
    let isInlineEditorOpen = isInlineEditing(
      ticketID: ticket.id,
      laneID: lane.id
    )

    return VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top, spacing: 8) {
        if isInlineEditorOpen {
          TextField(
            "Ticket title",
            text: inlineTicketTitleBinding(
              fallback: ticket,
              laneID: lane.id
            )
          )
          .textFieldStyle(.roundedBorder)
          .font(.subheadline.weight(.medium))
          .onSubmit {
            applyInlineTicketEditorDraft()
          }
        } else {
          Text(ticket.title)
            .font(.subheadline)
            .fontWeight(.medium)
        }

        Spacer(minLength: 4)

        Button {
          if isInlineEditorOpen {
            cancelInlineTicketEditor()
          } else {
            openInlineTicketEditor(
              ticket: ticket,
              laneID: lane.id
            )
          }
        } label: {
          Image(systemName: isInlineEditorOpen ? "xmark.circle.fill" : "pencil.circle")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isInlineEditorOpen ? "Cancel quick edit" : "Quick edit ticket")
        .help(isInlineEditorOpen ? "Cancel inline quick edit" : "Quick edit title, assignees, and labels")

        Menu {
          Button("Quick Edit") {
            openInlineTicketEditor(
              ticket: ticket,
              laneID: lane.id
            )
          }

          Divider()

          Button("Edit Ticket…") {
            inlineTicketEditorDraft = nil
            ticketEditorDraft = TicketEditorDraft.edit(
              ticket: ticket,
              laneID: lane.id
            )
          }

          Button("Move Up") {
            moveTicketWithinLane(
              ticketID: ticket.id,
              laneID: lane.id,
              direction: -1
            )
          }
          .disabled(!canMoveTicketWithinLane(ticketID: ticket.id, laneID: lane.id, direction: -1))

          Button("Move Down") {
            moveTicketWithinLane(
              ticketID: ticket.id,
              laneID: lane.id,
              direction: 1
            )
          }
          .disabled(!canMoveTicketWithinLane(ticketID: ticket.id, laneID: lane.id, direction: 1))

          Divider()

          Button("Move Left") {
            moveTicketRelative(
              ticketID: ticket.id,
              fromLaneID: lane.id,
              direction: -1
            )
          }
          .disabled(!canMoveTicketBetweenLanes(fromLaneID: lane.id, direction: -1))

          Button("Move Right") {
            moveTicketRelative(
              ticketID: ticket.id,
              fromLaneID: lane.id,
              direction: 1
            )
          }
          .disabled(!canMoveTicketBetweenLanes(fromLaneID: lane.id, direction: 1))

          Menu("Move To Lane") {
            ForEach(laneDestinations(excludingLaneID: lane.id)) { destination in
              Button(destination.title) {
                moveTicket(
                  ticketID: ticket.id,
                  fromLaneID: lane.id,
                  toLaneID: destination.id
                )
              }
            }
          }
          .disabled(sortedLanes.count <= 1)

          Divider()

          Button("Delete Ticket", role: .destructive) {
            pendingTicketDeletion = PendingTicketDeletion(
              laneID: lane.id,
              ticketID: ticket.id,
              ticketTitle: ticket.title
            )
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .controlSize(.small)

        Button {
          moveTicketToPreviousLane(
            ticketID: ticket.id,
            fromLaneID: lane.id
          )
        } label: {
          Image(systemName: "arrow.left.circle")
        }
        .buttonStyle(.plain)
        .help("Move to previous lane")
        .disabled(!canMoveTicketBetweenLanes(fromLaneID: lane.id, direction: -1))

        Button {
          moveTicketToNextLane(
            ticketID: ticket.id,
            fromLaneID: lane.id
          )
        } label: {
          Image(systemName: "arrow.right.circle.fill")
        }
        .buttonStyle(.plain)
        .help("Advance to next lane")
        .disabled(!canMoveTicketBetweenLanes(fromLaneID: lane.id, direction: 1))
      }

      HStack(spacing: 6) {
        Text(ticket.priority.label)
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(.regularMaterial, in: Capsule())

        if !ticket.assignees.isEmpty {
          Text(assigneeSummary(for: ticket))
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text(ticket.owner)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if let dueDateText = dueDateText(for: ticket.dueDateISO8601) {
          Text(dueDateText)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.regularMaterial, in: Capsule())
        }
      }

      if isInlineEditorOpen {
        VStack(alignment: .leading, spacing: 8) {
          TextField(
            "Assignees (comma-separated)",
            text: inlineTicketAssigneesBinding(
              fallback: ticket,
              laneID: lane.id
            )
          )
          .textFieldStyle(.roundedBorder)
          .font(.caption)
          .onSubmit {
            applyInlineTicketEditorDraft()
          }

          TextField(
            "Labels (comma-separated)",
            text: inlineTicketLabelsBinding(
              fallback: ticket,
              laneID: lane.id
            )
          )
          .textFieldStyle(.roundedBorder)
          .font(.caption)
          .onSubmit {
            applyInlineTicketEditorDraft()
          }

          HStack(spacing: 8) {
            Button("Cancel") {
              cancelInlineTicketEditor()
            }

            Button("Save") {
              applyInlineTicketEditorDraft()
            }
            .disabled(
              (inlineTicketEditorDraft?.title ?? ticket.title)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            )
          }
          .font(.caption)
        }
      }

      if !ticket.labels.isEmpty {
        Text(ticket.labels.joined(separator: ", "))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if !ticket.checklist.isEmpty {
        Text(checklistSummary(for: ticket))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if !ticket.descriptionMarkdown.isEmpty {
        Text(ticket.descriptionMarkdown)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      if !ticket.comments.isEmpty {
        Text("\(ticket.comments.count) comments")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(
          ticketOutlineColor(
            ticketID: ticket.id
          ),
          lineWidth: selectedTicketID == ticket.id || activeDropTicketID == ticket.id ? 2 : 0
        )
    )
    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .onTapGesture {
      selectTicket(
        ticketID: ticket.id,
        laneID: lane.id
      )
    }
    .draggable(ticketDragPayload(ticketID: ticket.id, laneID: lane.id))
    .dropDestination(
      for: String.self,
      action: { items, _ in
        handleTicketDrop(
          items,
          destinationLaneID: lane.id,
          destinationTicketID: ticket.id
        )
      },
      isTargeted: { isTargeted in
        if isTargeted {
          activeDropLaneID = lane.id
          activeDropTicketID = ticket.id
        } else if activeDropTicketID == ticket.id {
          activeDropTicketID = nil
        }
      }
    )
  }

  func laneEditorSheet(
    _ draft: LaneEditorDraft
  ) -> some View {
    NavigationStack {
      Form {
        TextField(
          "Lane title",
          text: Binding(
            get: {
              laneEditorDraft?.title ?? draft.title
            },
            set: { newValue in
              laneEditorDraft?.title = newValue
            }
          )
        )

        Picker(
          "Template",
          selection: Binding(
            get: {
              laneEditorDraft?.templateID ?? draft.templateID
            },
            set: { newValue in
              laneEditorDraft?.templateID = newValue
            }
          )
        ) {
          Text("None").tag(Optional<String>.none)
          ForEach(TaskboardLaneTemplate.defaults) { template in
            Text(template.title).tag(Optional(template.id))
          }
        }

        Toggle(
          "Set WIP limit",
          isOn: Binding(
            get: {
              laneEditorDraft?.hasWIPLimit ?? draft.hasWIPLimit
            },
            set: { newValue in
              laneEditorDraft?.hasWIPLimit = newValue
            }
          )
        )

        if laneEditorDraft?.hasWIPLimit ?? draft.hasWIPLimit {
          Stepper(
            "WIP limit: \(laneEditorDraft?.wipLimit ?? draft.wipLimit)",
            value: Binding(
              get: {
                max(1, laneEditorDraft?.wipLimit ?? draft.wipLimit)
              },
              set: { newValue in
                laneEditorDraft?.wipLimit = max(1, newValue)
              }
            ),
            in: 1...99
          )
        }
      }
      .formStyle(.grouped)
      .navigationTitle(draft.mode == .create ? "New Lane" : "Edit Lane")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            laneEditorDraft = nil
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            applyLaneEditorDraft()
          }
          .disabled((laneEditorDraft?.title ?? draft.title).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  func ticketEditorSheet(
    _ draft: TicketEditorDraft
  ) -> some View {
    NavigationStack {
      Form {
        Section("Details") {
          TextField(
            "Ticket title",
            text: Binding(
              get: {
                ticketEditorDraft?.title ?? draft.title
              },
              set: { newValue in
                ticketEditorDraft?.title = newValue
              }
            )
          )

          TextField(
            "Assignees (comma-separated)",
            text: Binding(
              get: {
                ticketEditorDraft?.assigneesText ?? draft.assigneesText
              },
              set: { newValue in
                ticketEditorDraft?.assigneesText = newValue
              }
            )
          )

          TextField(
            "Owner fallback",
            text: Binding(
              get: {
                ticketEditorDraft?.owner ?? draft.owner
              },
              set: { newValue in
                ticketEditorDraft?.owner = newValue
              }
            )
          )

          TextField(
            "Labels (comma-separated)",
            text: Binding(
              get: {
                ticketEditorDraft?.labelsText ?? draft.labelsText
              },
              set: { newValue in
                ticketEditorDraft?.labelsText = newValue
              }
            )
          )

          Picker(
            "Priority",
            selection: Binding(
              get: {
                ticketEditorDraft?.priority ?? draft.priority
              },
              set: { newValue in
                ticketEditorDraft?.priority = newValue
              }
            )
          ) {
            ForEach(TaskboardTicketPriority.allCases) { priority in
              Text(priority.label).tag(priority)
            }
          }
        }

        Section("Description") {
          TextEditor(
            text: Binding(
              get: {
                ticketEditorDraft?.descriptionMarkdown ?? draft.descriptionMarkdown
              },
              set: { newValue in
                ticketEditorDraft?.descriptionMarkdown = newValue
              }
            )
          )
          .font(.body)
          .frame(minHeight: 120)
        }

        Section("Due Date") {
          Toggle(
            "Has due date",
            isOn: Binding(
              get: {
                ticketEditorDraft?.hasDueDate ?? draft.hasDueDate
              },
              set: { newValue in
                ticketEditorDraft?.hasDueDate = newValue
              }
            )
          )

          if ticketEditorDraft?.hasDueDate ?? draft.hasDueDate {
            DatePicker(
              "Due",
              selection: Binding(
                get: {
                  ticketEditorDraft?.dueDate ?? draft.dueDate
                },
                set: { newValue in
                  ticketEditorDraft?.dueDate = newValue
                }
              ),
              displayedComponents: .date
            )
          }
        }

        Section("Checklist") {
          if (ticketEditorDraft?.checklistItems ?? draft.checklistItems).isEmpty {
            Text("No checklist items yet")
              .foregroundStyle(.secondary)
          } else {
            ForEach(Array((ticketEditorDraft?.checklistItems ?? draft.checklistItems).indices), id: \.self) { index in
              HStack(spacing: 8) {
                Toggle(
                  "",
                  isOn: checklistCompletionBinding(
                    index: index,
                    fallbackDraft: draft
                  )
                )
                .labelsHidden()

                TextField(
                  "Checklist item",
                  text: checklistTitleBinding(
                    index: index,
                    fallbackDraft: draft
                  )
                )

                Button(role: .destructive) {
                  removeChecklistItem(at: index)
                } label: {
                  Image(systemName: "trash")
                }
                .buttonStyle(.plain)
              }
            }
          }

          HStack(spacing: 8) {
            TextField(
              "New checklist item",
              text: Binding(
                get: {
                  ticketEditorDraft?.pendingChecklistTitle ?? draft.pendingChecklistTitle
                },
                set: { newValue in
                  ticketEditorDraft?.pendingChecklistTitle = newValue
                }
              )
            )

            Button("Add") {
              addChecklistItem()
            }
            .disabled(
              (ticketEditorDraft?.pendingChecklistTitle ?? draft.pendingChecklistTitle).trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty
            )
          }
        }

        Section("Comments") {
          if (ticketEditorDraft?.comments ?? draft.comments).isEmpty {
            Text("No comments yet")
              .foregroundStyle(.secondary)
          } else {
            ForEach(Array((ticketEditorDraft?.comments ?? draft.comments).indices), id: \.self) { index in
              VStack(alignment: .leading, spacing: 4) {
                Text((ticketEditorDraft?.comments ?? draft.comments)[index].author)
                  .font(.caption)
                  .foregroundStyle(.secondary)

                Text((ticketEditorDraft?.comments ?? draft.comments)[index].bodyMarkdown)
                  .font(.body)

                HStack {
                  Spacer()

                  Button(role: .destructive) {
                    removeCommentFromDraft(at: index)
                  } label: {
                    Image(systemName: "trash")
                  }
                  .buttonStyle(.plain)
                }
              }
              .padding(.vertical, 4)
            }
          }

          TextField(
            "Comment author",
            text: Binding(
              get: {
                ticketEditorDraft?.pendingCommentAuthor ?? draft.pendingCommentAuthor
              },
              set: { newValue in
                ticketEditorDraft?.pendingCommentAuthor = newValue
              }
            )
          )

          TextEditor(
            text: Binding(
              get: {
                ticketEditorDraft?.pendingCommentBody ?? draft.pendingCommentBody
              },
              set: { newValue in
                ticketEditorDraft?.pendingCommentBody = newValue
              }
            )
          )
          .font(.body)
          .frame(minHeight: 90)

          HStack {
            Spacer()

            Button("Add Comment") {
              addCommentToDraft()
            }
            .disabled(
              (ticketEditorDraft?.pendingCommentBody ?? draft.pendingCommentBody).trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty
            )
          }
        }
      }
      .formStyle(.grouped)
      .navigationTitle(draft.mode.isCreate ? "New Ticket" : "Edit Ticket")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            ticketEditorDraft = nil
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            applyTicketEditorDraft()
          }
          .disabled((ticketEditorDraft?.title ?? draft.title).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

}
