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
        laneEditorDraft = LaneEditorDraft.create()
      } label: {
        Label("New Lane", systemImage: "plus.square")
      }
      .help("Quick add lane (Shift-Command-L)")
      .keyboardShortcut("l", modifiers: [.shift, .command])

      Button {
        openTicketComposerForSelectedLane()
      } label: {
        Label("New Ticket", systemImage: "plus.rectangle.on.rectangle")
      }
      .help("Create ticket in selected lane (Shift-Command-T)")
      .keyboardShortcut("t", modifiers: [.shift, .command])
      .disabled(selectedLaneID == nil)

      Button {
        editSelectedLane()
      } label: {
        Label("Edit Lane", systemImage: "pencil")
      }
      .help("Edit selected lane (Shift-Command-E)")
      .keyboardShortcut("e", modifiers: [.shift, .command])
      .disabled(selectedLaneID == nil)

      Button {
        resetBoard()
      } label: {
        Label("Reset", systemImage: "arrow.clockwise")
      }
      .help("Reset lanes and tickets to defaults for this workspace.")
    }
    .padding(.horizontal, 16)
  }

  var filterBar: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        TextField("Filter by keyword", text: $keywordFilterText)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 260)

        TextField("Owner", text: $ownerFilterText)
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
          .foregroundStyle(.secondary)
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

      ForEach(visibleTickets) { ticket in
        ticketCard(
          ticket,
          lane: lane,
          laneIndex: laneIndex,
          laneCount: laneCount
        )
      }

      if visibleTickets.isEmpty {
        Text(isFilteringActive && !lane.tickets.isEmpty ? "No matching tickets" : "No tickets yet")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.vertical, 8)
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
    }
    .dropDestination(
      for: String.self,
      action: { items, _ in
        handleTicketDrop(items, destinationLaneID: lane.id)
      },
      isTargeted: { isTargeted in
        if isTargeted {
          activeDropLaneID = lane.id
        } else if activeDropLaneID == lane.id {
          activeDropLaneID = nil
        }
      }
    )
  }

  func ticketCard(
    _ ticket: TaskboardTicket,
    lane: TaskboardLane,
    laneIndex: Int,
    laneCount: Int
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top, spacing: 8) {
        Text(ticket.title)
          .font(.subheadline)
          .fontWeight(.medium)

        Spacer(minLength: 4)

        Menu {
          Button("Edit Ticket…") {
            ticketEditorDraft = TicketEditorDraft.edit(
              ticket: ticket,
              laneID: lane.id
            )
          }

          Button("Move Left") {
            moveTicketRelative(
              ticketID: ticket.id,
              fromLaneID: lane.id,
              direction: -1
            )
          }
          .disabled(laneIndex == 0 || laneCount <= 1)

          Button("Move Right") {
            moveTicketRelative(
              ticketID: ticket.id,
              fromLaneID: lane.id,
              direction: 1
            )
          }
          .disabled(laneIndex >= laneCount - 1 || laneCount <= 1)

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
          .disabled(laneCount <= 1)

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
      }

      HStack(spacing: 6) {
        Text(ticket.priority.label)
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(.regularMaterial, in: Capsule())

        Text(ticket.owner)
          .font(.caption)
          .foregroundStyle(.secondary)

        if let dueDateText = dueDateText(for: ticket.dueDateISO8601) {
          Text(dueDateText)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.regularMaterial, in: Capsule())
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
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .draggable(ticketDragPayload(ticketID: ticket.id, laneID: lane.id))
  }

  func laneEditorSheet(
    _ draft: LaneEditorDraft
  ) -> some View {
    NavigationStack {
      Form {
        TextField("Lane title", text: Binding(
          get: {
            laneEditorDraft?.title ?? draft.title
          },
          set: { newValue in
            laneEditorDraft?.title = newValue
          }
        ))

        Picker("Template", selection: Binding(
          get: {
            laneEditorDraft?.templateID ?? draft.templateID
          },
          set: { newValue in
            laneEditorDraft?.templateID = newValue
          }
        )) {
          Text("None").tag(Optional<String>.none)
          ForEach(TaskboardLaneTemplate.defaults) { template in
            Text(template.title).tag(Optional(template.id))
          }
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
          TextField("Ticket title", text: Binding(
            get: {
              ticketEditorDraft?.title ?? draft.title
            },
            set: { newValue in
              ticketEditorDraft?.title = newValue
            }
          ))

          TextField("Owner", text: Binding(
            get: {
              ticketEditorDraft?.owner ?? draft.owner
            },
            set: { newValue in
              ticketEditorDraft?.owner = newValue
            }
          ))

          TextField("Labels (comma-separated)", text: Binding(
            get: {
              ticketEditorDraft?.labelsText ?? draft.labelsText
            },
            set: { newValue in
              ticketEditorDraft?.labelsText = newValue
            }
          ))

          Picker("Priority", selection: Binding(
            get: {
              ticketEditorDraft?.priority ?? draft.priority
            },
            set: { newValue in
              ticketEditorDraft?.priority = newValue
            }
          )) {
            ForEach(TaskboardTicketPriority.allCases) { priority in
              Text(priority.label).tag(priority)
            }
          }
        }

        Section("Due Date") {
          Toggle("Has due date", isOn: Binding(
            get: {
              ticketEditorDraft?.hasDueDate ?? draft.hasDueDate
            },
            set: { newValue in
              ticketEditorDraft?.hasDueDate = newValue
            }
          ))

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
                Toggle("", isOn: checklistCompletionBinding(
                  index: index,
                  fallbackDraft: draft
                ))
                .labelsHidden()

                TextField("Checklist item", text: checklistTitleBinding(
                  index: index,
                  fallbackDraft: draft
                ))

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
            TextField("New checklist item", text: Binding(
              get: {
                ticketEditorDraft?.pendingChecklistTitle ?? draft.pendingChecklistTitle
              },
              set: { newValue in
                ticketEditorDraft?.pendingChecklistTitle = newValue
              }
            ))

            Button("Add") {
              addChecklistItem()
            }
            .disabled((ticketEditorDraft?.pendingChecklistTitle ?? draft.pendingChecklistTitle).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
