import ContextWorkspaceCore
import StudioFoundation
import SwiftUI

private enum PersonaHelpSection: String, Identifiable {
  case allowedSkillIDs
  case defaultKitIDs
  case forbiddenSkillIDs
  case nonGoals
  case persona
  case responsibilities
  case values

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .allowedSkillIDs:
      return "Allowed Skill IDs"
    case .defaultKitIDs:
      return "Default Kit IDs"
    case .forbiddenSkillIDs:
      return "Forbidden Skill IDs"
    case .nonGoals:
      return "Non-Goals"
    case .persona:
      return "Persona"
    case .responsibilities:
      return "Responsibilities"
    case .values:
      return "Values"
    }
  }

  var helpSummary: String {
    helpText
  }

  var helpText: String {
    switch self {
    case .allowedSkillIDs:
      return
        "Allowed skills are this persona's capability ceiling: the external help it may use when a resolved contract requires it."
    case .defaultKitIDs:
      return "Default kits provide shared standards and constraints this persona always carries."
    case .forbiddenSkillIDs:
      return
        "Forbidden skills are hard denials. They block capabilities even when a kit, directive, or intent asks for them."
    case .nonGoals:
      return "Non-goals prevent scope creep. List work this persona should explicitly avoid."
    case .persona:
      return
        "Define a concrete professional role with a stable id and clear summary. These fields shape the agent's behavior."
    case .responsibilities:
      return "Add concrete duties this persona is expected to perform. Use action-oriented lines with clear outcomes."
    case .values:
      return
        "Values are decision heuristics. Keep them short and opinionated so the persona can choose between tradeoffs consistently."
    }
  }
}

private enum PersonaReferenceType: String {
  case kit
  case skill

  var title: String {
    switch self {
    case .kit:
      return "Kit"
    case .skill:
      return "Skill"
    }
  }
}

private struct PersonaReferencePreview: Equatable, Identifiable {
  let referenceType: PersonaReferenceType
  let referenceID: String

  var id: String {
    "\(referenceType.rawValue)::\(referenceID)"
  }
}

/// Modal editor for creating a new persona without raw JSON authoring.
struct PersonaEditorView: View {
  let title: String
  let existingPersonaIDs: [String]
  let knownKits: [WorkspaceListItem]
  let knownSkills: [WorkspaceListItem]
  let knownKitIDs: [String]
  let knownSkillIDs: [String]
  let onCancel: () -> Void
  let onSave: @Sendable (WorkspacePersonaDraft) async -> String?

  @State private var id: String
  @State private var name: String
  @State private var summary: String
  @State private var responsibilitiesText: String
  @State private var valuesText: String
  @State private var nonGoalsText: String
  @State private var defaultKitIDs: [String]
  @State private var allowedSkillIDs: [String]
  @State private var forbiddenSkillIDs: [String]
  @State private var defaultKitCustomID = ""
  @State private var allowedSkillCustomID = ""
  @State private var forbiddenSkillCustomID = ""
  @State private var idWasManuallyEdited: Bool
  @State private var didAttemptSave = false
  @State private var isSaving = false
  @State private var saveErrorMessage: String?
  @State private var presentedHelpSection: PersonaHelpSection?
  @State private var presentedReferencePreview: PersonaReferencePreview?

  private let draftBuilder = WorkspacePersonaDraftBuilder()

  init(
    title: String,
    initialDraft: WorkspacePersonaDraft,
    existingPersonaIDs: [String],
    knownKits: [WorkspaceListItem],
    knownSkills: [WorkspaceListItem],
    onCancel: @escaping () -> Void,
    onSave: @escaping @Sendable (WorkspacePersonaDraft) async -> String?
  ) {
    self.title = title
    self.existingPersonaIDs = Array(Set(existingPersonaIDs)).sorted()
    self.knownKits = Self.normalizedKnownItems(knownKits)
    self.knownSkills = Self.normalizedKnownItems(knownSkills)
    self.knownKitIDs = self.knownKits.map(\.id)
    self.knownSkillIDs = self.knownSkills.map(\.id)
    self.onCancel = onCancel
    self.onSave = onSave

    _id = State(initialValue: initialDraft.id)
    _name = State(initialValue: initialDraft.name)
    _summary = State(initialValue: initialDraft.summary)
    _responsibilitiesText = State(initialValue: initialDraft.responsibilities.joined(separator: "\n"))
    _valuesText = State(initialValue: initialDraft.values.joined(separator: "\n"))
    _nonGoalsText = State(initialValue: initialDraft.nonGoals.joined(separator: "\n"))
    _defaultKitIDs = State(initialValue: Self.normalizedIDList(initialDraft.defaultKitIds))
    _allowedSkillIDs = State(initialValue: Self.normalizedIDList(initialDraft.allowedSkillIds))
    _forbiddenSkillIDs = State(initialValue: Self.normalizedIDList(initialDraft.forbiddenSkillIds))
    _idWasManuallyEdited = State(initialValue: !initialDraft.id.isEmpty)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title3)
        .fontWeight(.semibold)

      Form {
        Section {
          VStack(alignment: .leading) {
            Text("Name")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: true, vertical: false)  // force intrinsic size
            TextField(
              text: nameBinding,
              prompt: Text("Pragmatic SwiftUI Engineer, Accessibility-First Web Engineer, Quality Assurance Engineer.")
            ) {
              EmptyView()
            }
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .font(.body.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
          }

          VStack(alignment: .leading) {
            Text("ID")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: true, vertical: false)
            TextField(
              text: idBinding,
              prompt: Text("pragmatic-swiftui-engineer, ios-release-steward, technical-documentation-specialist")
            ) {
              EmptyView()
            }
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .font(.body.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Button {
              id = draftBuilder.suggestedID(from: name)
              idWasManuallyEdited = false
            } label: {
              Label("Suggest ID", systemImage: "wand.and.stars")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .fixedSize(horizontal: true, vertical: false)
            .help("Generate an id from the name field.")
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }

          multiLineListEditor(
            text: $summary,
            prompt: "Summary",
            placeholder: "Pragmatic, accessibility-first engineer focused on small, test-backed SwiftUI diffs."
          )
        } header: {
          sectionHeader(
            "Persona",
            section: .persona
          )
        }

        Section {
          multiLineListEditor(
            text: $responsibilitiesText,
            prompt: "One responsibility per line",
            placeholder:
              """
              Implement SwiftUI features
              Maintain accessibility standards
              Write regression tests for every behavior change
              """
          )
        } header: {
          sectionHeader(
            "Responsibilities",
            section: .responsibilities
          )
        }

        Section {
          multiLineListEditor(
            text: $valuesText,
            prompt: "One value per line",
            placeholder:
              """
              correctness over cleverness
              small diffs
              clarity
              """
          )
        } header: {
          sectionHeader(
            "Values",
            section: .values
          )
        }

        Section {
          multiLineListEditor(
            text: $nonGoalsText,
            prompt: "One non-goal per line",
            placeholder:
              """
              architecture rewrites
              introducing new frameworks without approval
              """
          )
        } header: {
          sectionHeader(
            "Non-Goals",
            section: .nonGoals
          )
        }

        Section {
          referenceSelectionEditor(
            knownItems: knownKits,
            selectedIDs: $defaultKitIDs,
            customID: $defaultKitCustomID,
            customPlaceholder: "my-team-style-kit, ios-quality-kit",
            referenceType: .kit
          )
        } header: {
          sectionHeader(
            "Default Kit IDs",
            section: .defaultKitIDs
          )
        }

        Section {
          referenceSelectionEditor(
            knownItems: knownSkills,
            selectedIDs: $allowedSkillIDs,
            customID: $allowedSkillCustomID,
            customPlaceholder: "safe-file-ops, ui-testing",
            referenceType: .skill
          )
        } header: {
          sectionHeader(
            "Allowed Skill IDs",
            section: .allowedSkillIDs
          )
        }

        Section {
          referenceSelectionEditor(
            knownItems: knownSkills,
            selectedIDs: $forbiddenSkillIDs,
            customID: $forbiddenSkillCustomID,
            customPlaceholder: "autonomous-exec, destructive-shell",
            referenceType: .skill
          )
        } header: {
          sectionHeader(
            "Forbidden Skill IDs",
            section: .forbiddenSkillIDs
          )
        }
      }
      .formStyle(.grouped)

      if let saveErrorMessage {
        Text(saveErrorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
      }

      if didAttemptSave,
        !validationErrors.isEmpty || !validationWarnings.isEmpty
      {
        validationSummaryView
      }

      HStack(spacing: 8) {
        Spacer()

        Button("Cancel") {
          onCancel()
        }
        .disabled(isSaving)

        Button("Save") {
          save()
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSaving)
      }
    }
    .padding()
    .frame(minWidth: 640, minHeight: 620)
    .interactiveDismissDisabled(isSaving)
  }

  private var nameBinding: Binding<String> {
    Binding(
      get: { name },
      set: { updatedName in
        name = updatedName

        if !idWasManuallyEdited {
          id = draftBuilder.suggestedID(from: updatedName)
        }
      }
    )
  }

  private var idBinding: Binding<String> {
    Binding(
      get: { id },
      set: { updatedID in
        id = updatedID
        idWasManuallyEdited = true
      }
    )
  }

  private var currentDraft: WorkspacePersonaDraft {
    WorkspacePersonaDraft(
      id: id,
      name: name,
      summary: summary,
      responsibilities: normalizedTextLines(responsibilitiesText),
      values: normalizedTextLines(valuesText),
      nonGoals: normalizedTextLines(nonGoalsText),
      defaultKitIds: Self.normalizedIDList(defaultKitIDs),
      allowedSkillIds: Self.normalizedIDList(allowedSkillIDs),
      forbiddenSkillIds: Self.normalizedIDList(forbiddenSkillIDs)
    )
  }

  private var normalizedID: String {
    WorkspaceEntityIDPolicy.normalized(id)
  }

  private var nameErrorMessage: String? {
    let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

    if normalizedName.isEmpty {
      return "Persona name is required."
    }

    return nil
  }

  private var idErrorMessage: String? {
    if normalizedID.isEmpty {
      return "Persona id is required."
    }

    if !WorkspaceEntityIDPolicy.isValid(normalizedID) {
      return "Use letters, numbers, hyphen, underscore, or period for persona id."
    }

    if Set(existingPersonaIDs).contains(normalizedID) {
      return "Persona id already exists."
    }

    return nil
  }

  private var summaryErrorMessage: String? {
    let normalizedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)

    if normalizedSummary.isEmpty {
      return "Persona summary is required."
    }

    return nil
  }

  private var allowedForbiddenSkillOverlapError: String? {
    let overlap = Set(defaultNormalizedAllowedSkillIDs).intersection(defaultNormalizedForbiddenSkillIDs).sorted()

    if overlap.isEmpty {
      return nil
    }

    return "Allowed and forbidden skills cannot overlap: \(overlap.joined(separator: ", "))."
  }

  private var unknownDefaultKitIDsWarning: String? {
    warningForUnknownIDs(
      selectedIDs: defaultNormalizedKitIDs,
      knownIDs: knownKitIDs,
      label: "Unknown kit ids"
    )
  }

  private var unknownAllowedSkillIDsWarning: String? {
    warningForUnknownIDs(
      selectedIDs: defaultNormalizedAllowedSkillIDs,
      knownIDs: knownSkillIDs,
      label: "Unknown allowed skill ids"
    )
  }

  private var unknownForbiddenSkillIDsWarning: String? {
    warningForUnknownIDs(
      selectedIDs: defaultNormalizedForbiddenSkillIDs,
      knownIDs: knownSkillIDs,
      label: "Unknown forbidden skill ids"
    )
  }

  private var validationErrors: [String] {
    [
      idErrorMessage,
      nameErrorMessage,
      summaryErrorMessage,
      allowedForbiddenSkillOverlapError,
    ]
    .compactMap { $0 }
  }

  private var validationWarnings: [String] {
    [
      unknownDefaultKitIDsWarning,
      unknownAllowedSkillIDsWarning,
      unknownForbiddenSkillIDsWarning,
    ]
    .compactMap { $0 }
  }

  private var defaultNormalizedKitIDs: [String] {
    Self.normalizedIDList(defaultKitIDs)
  }

  private var defaultNormalizedAllowedSkillIDs: [String] {
    Self.normalizedIDList(allowedSkillIDs)
  }

  private var defaultNormalizedForbiddenSkillIDs: [String] {
    Self.normalizedIDList(forbiddenSkillIDs)
  }

  private func multiLineListEditor(
    text: Binding<String>,
    prompt: String,
    placeholder: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(prompt)
        .font(.caption)
        .foregroundStyle(.secondary)

      multilineEditor(
        text: text,
        placeholder: placeholder
      )
    }
  }

  private func sectionHeader(
    _ title: String,
    section: PersonaHelpSection
  ) -> some View {
    HStack(alignment: .center, spacing: 6) {
      Text(title)

      Button {
        presentedHelpSection = section
      } label: {
        Image(systemName: "questionmark.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help(section.helpSummary)
      .popover(
        isPresented: helpPopoverBinding(for: section),
        attachmentAnchor: .rect(.bounds),
        arrowEdge: .top
      ) {
        helpPopover(section: section)
      }
    }
  }

  private func helpPopoverBinding(
    for section: PersonaHelpSection
  ) -> Binding<Bool> {
    Binding(
      get: {
        presentedHelpSection == section
      },
      set: { isPresented in
        if isPresented {
          presentedHelpSection = section
        } else if presentedHelpSection == section {
          presentedHelpSection = nil
        }
      }
    )
  }

  private func referencePreviewBinding(
    referenceType: PersonaReferenceType,
    referenceID: String
  ) -> Binding<Bool> {
    Binding(
      get: {
        presentedReferencePreview?.referenceType == referenceType
          && presentedReferencePreview?.referenceID == referenceID
      },
      set: { isPresented in
        if isPresented {
          presentedReferencePreview = PersonaReferencePreview(
            referenceType: referenceType,
            referenceID: referenceID
          )
        } else if presentedReferencePreview?.referenceType == referenceType,
          presentedReferencePreview?.referenceID == referenceID
        {
          presentedReferencePreview = nil
        }
      }
    )
  }

  private func referencePreviewPopover(
    knownItem: WorkspaceListItem?,
    referenceID: String,
    referenceType: PersonaReferenceType
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("\(referenceType.title) Preview")
        .font(.headline)

      Text(referenceID)
        .font(.callout.monospaced())

      if let knownItem {
        if knownItem.displayName != referenceID {
          Text(knownItem.displayName)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Text("Source: \(knownItem.sourceScope.displayName)")
          .font(.caption)
          .foregroundStyle(.secondary)

        Text(knownItem.fileURL.path())
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(3)
          .truncationMode(.middle)
      } else {
        Text("No loaded metadata found for this id.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(width: 360, alignment: .leading)
  }

  private var validationSummaryView: some View {
    VStack(alignment: .leading, spacing: 8) {
      if !validationErrors.isEmpty {
        Label("Please fix these before saving:", systemImage: "exclamationmark.triangle.fill")
          .font(.footnote)
          .foregroundStyle(.red)

        ForEach(validationErrors, id: \.self) { message in
          Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
        }
      }

      if !validationWarnings.isEmpty {
        Label("Warnings:", systemImage: "exclamationmark.circle")
          .font(.footnote)
          .foregroundStyle(.orange)

        ForEach(validationWarnings, id: \.self) { message in
          Text(message)
            .font(.footnote)
            .foregroundStyle(.orange)
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(.quaternary.opacity(0.14))
    )
  }

  private func multilineEditor(
    text: Binding<String>,
    placeholder: String
  ) -> some View {
    return StudioMultilineTextInput(
      text: text,
      placeholder: placeholder,
      horizontalInset: 12,
      verticalInset: 10
    )
    .frame(minHeight: 96)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(.quaternary.opacity(0.15))
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(.quaternary.opacity(0.45), lineWidth: 1)
    )
  }

  private func referenceSelectionEditor(
    knownItems: [WorkspaceListItem],
    selectedIDs: Binding<[String]>,
    customID: Binding<String>,
    customPlaceholder: String,
    referenceType: PersonaReferenceType
  ) -> some View {
    let knownIDs = knownItems.map(\.id)
    let knownItemsByID = Dictionary(uniqueKeysWithValues: knownItems.map { ($0.id, $0) })

    return VStack(alignment: .leading, spacing: 8) {
      if knownIDs.isEmpty {
        Text("No known ids available in this workspace yet.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ForEach(knownIDs, id: \.self) { knownID in
          HStack(spacing: 8) {
            Button {
              presentedReferencePreview = PersonaReferencePreview(
                referenceType: referenceType,
                referenceID: knownID
              )
            } label: {
              Text(knownID)
                .font(.body.monospaced())
                .foregroundStyle(.tint)
                .underline()
            }
            .buttonStyle(.plain)
            .popover(
              isPresented: referencePreviewBinding(
                referenceType: referenceType,
                referenceID: knownID
              ),
              attachmentAnchor: .rect(.bounds),
              arrowEdge: .leading
            ) {
              referencePreviewPopover(
                knownItem: knownItemsByID[knownID],
                referenceID: knownID,
                referenceType: referenceType
              )
            }

            Spacer()

            Toggle(
              "",
              isOn: Binding(
                get: {
                  selectedIDs.wrappedValue.contains(knownID)
                },
                set: { isSelected in
                  selectedIDs.wrappedValue = updatedIDSelection(
                    selectedIDs.wrappedValue,
                    id: knownID,
                    isSelected: isSelected
                  )
                }
              )
            )
            .labelsHidden()
          }
        }
      }

      HStack(spacing: 8) {
        TextField(
          text: maskedCustomIDBinding(customID),
          prompt: Text(customPlaceholder)
        ) {
          EmptyView()
        }
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .font(.body.monospaced())
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
        .onSubmit {
          addCustomReferenceID(
            selectedIDs: selectedIDs,
            customID: customID
          )
        }

        Button("Add") {
          addCustomReferenceID(
            selectedIDs: selectedIDs,
            customID: customID
          )
        }
        .buttonStyle(.bordered)
        .fixedSize(horizontal: true, vertical: false)
        .disabled(
          WorkspaceEntityIDPolicy.normalized(customID.wrappedValue).isEmpty
        )
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      let customIDs = customIDsForSelection(
        selectedIDs.wrappedValue,
        knownIDs: knownIDs
      )

      if !customIDs.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(customIDs, id: \.self) { customSelectionID in
            HStack(spacing: 8) {
              Image(systemName: "tag")
                .font(.caption2)
                .foregroundStyle(.secondary)

              Text(customSelectionID)
                .font(.caption.monospaced())

              Spacer()

              Button {
                selectedIDs.wrappedValue = updatedIDSelection(
                  selectedIDs.wrappedValue,
                  id: customSelectionID,
                  isSelected: false
                )
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.caption)
              }
              .buttonStyle(.plain)
              .help("Remove custom id")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
              RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.2))
            )
          }
        }
      }
    }
  }

  private func maskedCustomIDBinding(
    _ customID: Binding<String>
  ) -> Binding<String> {
    Binding(
      get: {
        customID.wrappedValue
      },
      set: { updatedValue in
        customID.wrappedValue = updatedValue.replacingOccurrences(
          of: " ",
          with: "-"
        )
      }
    )
  }

  private func addCustomReferenceID(
    selectedIDs: Binding<[String]>,
    customID: Binding<String>
  ) {
    let candidateIDs = normalizedCustomIDCandidates(customID.wrappedValue)

    guard !candidateIDs.isEmpty else {
      return
    }

    var updatedIDs = selectedIDs.wrappedValue

    for candidateID in candidateIDs {
      updatedIDs = updatedIDSelection(
        updatedIDs,
        id: candidateID,
        isSelected: true
      )
    }

    selectedIDs.wrappedValue = updatedIDs
    customID.wrappedValue = ""
  }

  private func normalizedCustomIDCandidates(
    _ rawInput: String
  ) -> [String] {
    rawInput
      .split(separator: ",")
      .map { segment in
        WorkspaceEntityIDPolicy.normalized(
          segment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
      }
      .filter { !$0.isEmpty }
  }

  private func normalizedTextLines(_ text: String) -> [String] {
    text.split(whereSeparator: \.isNewline).map { line in
      line.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    .filter { !$0.isEmpty }
  }

  private static func normalizedIDList(_ values: [String]) -> [String] {
    Array(
      Set(
        values.map {
          WorkspaceEntityIDPolicy.normalized($0)
        }
        .filter { !$0.isEmpty }
      )
    )
    .sorted()
  }

  private static func normalizedKnownItems(
    _ items: [WorkspaceListItem]
  ) -> [WorkspaceListItem] {
    var itemsByID: [String: WorkspaceListItem] = [:]

    for item in items {
      itemsByID[item.id] = item
    }

    return itemsByID.keys.sorted().compactMap { itemsByID[$0] }
  }

  private func updatedIDSelection(
    _ values: [String],
    id: String,
    isSelected: Bool
  ) -> [String] {
    var updated = Set(Self.normalizedIDList(values))

    if isSelected {
      updated.insert(id)
    } else {
      updated.remove(id)
    }

    return Array(updated).sorted()
  }

  private func customIDsForSelection(
    _ selectedIDs: [String],
    knownIDs: [String]
  ) -> [String] {
    let knownIDSet = Set(knownIDs)

    return selectedIDs.filter { selectedID in
      !knownIDSet.contains(selectedID)
    }
  }

  private func warningForUnknownIDs(
    selectedIDs: [String],
    knownIDs: [String],
    label: String
  ) -> String? {
    let unknownIDs = customIDsForSelection(
      selectedIDs,
      knownIDs: knownIDs
    )

    if unknownIDs.isEmpty {
      return nil
    }

    return "\(label): \(unknownIDs.joined(separator: ", "))."
  }

  private func helpPopover(
    section: PersonaHelpSection
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(section.title)
        .font(.headline)

      Text(section.helpText)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(width: 320, alignment: .leading)
  }

  private func save() {
    didAttemptSave = true
    saveErrorMessage = nil
    let blockingErrors = validationErrors

    guard blockingErrors.isEmpty else {
      return
    }

    isSaving = true
    let draft = currentDraft

    Task {
      let saveErrorMessage = await onSave(draft)

      await MainActor.run {
        isSaving = false

        if let saveErrorMessage {
          self.saveErrorMessage = saveErrorMessage
        } else {
          onCancel()
        }
      }
    }
  }
}
