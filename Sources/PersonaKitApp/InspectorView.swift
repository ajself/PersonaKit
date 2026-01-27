import PersonaKitCore
import SwiftUI

/// Inspector panel showing persona details and pack comparison tools.
struct InspectorView: View {
  @Environment(AppModel.self)
  private var model
  @State private var showPackCompare = false
  @State private var comparisonPackID: String?
  @State private var packDiff: PackDiff?
  @State private var packDiffDiagnostics: [Diagnostic] = []
  @State private var primaryPackID: String?

  private var selectedPersona: Persona? {
    guard let id = model.composer.selectedPersonaID else { return nil }
    return model.personaIndex[id]?.persona
  }

  private var selectedPersonaTags: [String] {
    selectedPersona?.sortedTags ?? []
  }

  private var selectedPackLabel: String {
    guard let persona = selectedPersona,
      let pack = model.personaPacksByID[persona.id]
    else {
      return "Unknown"
    }
    let name = pack.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let id = pack.id.trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty && !id.isEmpty && name != id {
      return "\(name) (\(id))"
    }
    if !name.isEmpty {
      return name
    }
    if !id.isEmpty {
      return id
    }
    return "Unknown"
  }

  private var selectedPackSelection: PackSelection? {
    guard let persona = selectedPersona,
      let sourceURL = model.personaSourcesByID[persona.id]?.url
    else {
      return nil
    }
    let canonical = sourceURL.resolvingSymlinksInPath().standardizedFileURL
    return model.availablePacks.first { selection in
      selection.packFile.resolvingSymlinksInPath().standardizedFileURL == canonical
    }
  }

  private var comparisonPackSelection: PackSelection? {
    guard let comparisonPackID else { return nil }
    return model.availablePacks.first { $0.id == comparisonPackID }
  }

  private var comparisonCandidates: [PackSelection] {
    guard let selectedPackSelection else { return [] }
    return model.availablePacks.filter { $0.id != selectedPackSelection.id }
  }

  private var selectedSourceLabel: String {
    guard let persona = selectedPersona else { return "Unknown" }
    let source = model.personaSourcesByID[persona.id]
    let pack = model.personaPacksByID[persona.id]
    let baseURL = PersonaKitStoragePaths.standard().root
    let label =
      PersonaDescriptor.sourceLabel(source: source, pack: pack, baseURL: baseURL) ?? "Unknown"
    if source?.kind == .builtIn {
      return "\(label) — read-only"
    }
    return label
  }

  /// Builds the inspector layout with persona metadata and diff tools.
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 12) {
          Label("Persona", systemImage: "person")
            .font(.headline)
          VStack(alignment: .leading, spacing: 4) {
            personaHeaderLine
          }
          personaAboutSection
            .padding(.top, 8)
          personaTagsSection
          personaSourceSection
            .padding(.top, 8)
          packDiffSection
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Divider()

        GroupBox {
          ComposerView()
        } label: {
          Label("Parameters", systemImage: "slider.horizontal.3")
        }
      }
      .padding()
    }
    .frame(minWidth: 260)
    .onAppear {
      updatePrimaryPackSelection()
    }
    .onChange(of: model.composer.selectedPersonaID) { _, _ in
      updatePrimaryPackSelection()
    }
    .onChange(of: model.availablePacks) { _, _ in
      updatePrimaryPackSelection()
    }
    .sheet(isPresented: $showPackCompare) {
      PackCompareSheet(
        primaryPack: selectedPackSelection,
        availablePacks: model.availablePacks,
        selectionID: $comparisonPackID
      ) { selection in
        computePackDiff(comparison: selection)
        showPackCompare = false
      }
    }
  }

  private var personaHeaderLine: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(selectedPersona?.name ?? "No persona selected")
        .font(.title3)
        .foregroundStyle(.primary)
      if let id = selectedPersona?.id {
        Text(id)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var personaAboutSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("About", systemImage: "info.circle")
        .font(.headline)
      Text(aboutText)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var personaTagsSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Persona Tags", systemImage: "tag")
        .font(.headline)
      if selectedPersonaTags.isEmpty {
        Text("No tags.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8
        ) {
          ForEach(selectedPersonaTags, id: \.self) { tag in
            TagPill(title: tag)
          }
        }
      }
    }
  }

  private var personaSourceSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("Source", systemImage: "tray.full")
        .font(.headline)
      Text(selectedPackLabel)
        .font(.callout)
        .foregroundStyle(.secondary)
      Text(selectedSourceLabel)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var packDiffSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("What Changed?", systemImage: "arrow.triangle.2.circlepath")
          .font(.headline)
        Spacer()
        Button("Compare…") {
          showPackCompare = true
        }
        .disabled(selectedPackSelection == nil || comparisonCandidates.isEmpty)
        .help("Compare the selected pack with another pack.")
      }

      Text("Pack A: \(selectedPackSelection?.displayName ?? "Unknown")")
        .font(.caption)
        .foregroundStyle(.secondary)

      if let comparisonPackSelection {
        Text("Pack B: \(comparisonPackSelection.displayName)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let packDiff {
        PackDiffSummaryView(diff: packDiff)
      } else {
        Text("No comparison yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if !packDiffDiagnostics.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Diff Diagnostics")
            .font(.caption)
            .foregroundStyle(.secondary)
          ForEach(Array(packDiffDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
            Text("• [\(diagnostic.severity.rawValue.uppercased())] \(diagnostic.userFacingMessage)")
              .font(.caption2)
              .foregroundStyle(diagnostic.severity == .error ? .red : .orange)
          }
        }
      }
    }
  }

  private var aboutText: String {
    guard let about = selectedPersona?.about?.trimmingCharacters(in: .whitespacesAndNewlines),
      !about.isEmpty
    else {
      return "No description."
    }
    return about
  }

  /// Synchronizes the primary pack selection and resets comparison state.
  private func updatePrimaryPackSelection() {
    let currentID = selectedPackSelection?.id
    if primaryPackID != currentID {
      primaryPackID = currentID
      comparisonPackID = nil
      packDiff = nil
      packDiffDiagnostics = []
      return
    }
    if let comparisonPackID {
      if !comparisonCandidates.contains(where: { $0.id == comparisonPackID }) {
        self.comparisonPackID = nil
        packDiff = nil
        packDiffDiagnostics = []
      }
    }
  }

  /// Computes a diff between the selected pack and a comparison pack.
  private func computePackDiff(comparison: PackSelection) {
    guard let selectedPackSelection else { return }
    let left = PackDiffInputBuilder.build(for: selectedPackSelection)
    let right = PackDiffInputBuilder.build(for: comparison)
    packDiffDiagnostics = left.diagnostics + right.diagnostics
    packDiff = PackDiffBuilder.diff(left: left.records, right: right.records)
  }
}

/// Compact summary of added, removed, and modified personas in a diff.
private struct PackDiffSummaryView: View {
  let diff: PackDiff

  /// Builds the diff summary sections.
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      diffSection(title: "Added", systemImage: "plus", changes: diff.added)
      diffSection(title: "Removed", systemImage: "minus", changes: diff.removed)
      diffSection(title: "Modified", systemImage: "pencil", changes: diff.modified)
    }
  }

  /// Renders a diff section for a specific change set.
  private func diffSection(
    title: String, systemImage: String, changes: [PersonaChange]
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Label(title, systemImage: systemImage)
          .font(.subheadline)
        Spacer()
        Text("\(changes.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if changes.isEmpty {
        Text("None")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
          Text(changeLabel(change))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  /// Builds a readable label for a persona change record.
  private func changeLabel(_ change: PersonaChange) -> String {
    let name = change.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let id = change.id.trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty && !id.isEmpty && name != id {
      return "\(name) (\(id))"
    }
    if !name.isEmpty {
      return name
    }
    if !id.isEmpty {
      return id
    }
    return "Unknown persona"
  }
}

/// Sheet that lets the user pick a second pack to compare against.
private struct PackCompareSheet: View {
  let primaryPack: PackSelection?
  let availablePacks: [PackSelection]
  @Binding var selectionID: String?
  let onConfirm: (PackSelection) -> Void

  @Environment(\.dismiss)
  private var dismiss

  private var candidates: [PackSelection] {
    guard let primaryPack else { return availablePacks }
    return availablePacks.filter { $0.id != primaryPack.id }
  }

  /// Builds the pack comparison picker UI.
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Compare Packs")
        .font(.headline)

      if let primaryPack {
        Text("Pack A: \(primaryPack.displayName)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Picker("Pack B", selection: $selectionID) {
        ForEach(candidates) { pack in
          Text(pack.displayName)
            .tag(Optional(pack.id))
        }
      }

      HStack {
        Spacer()
        Button("Cancel") {
          dismiss()
        }
        Button("Compare") {
          guard let selectionID,
            let selection = candidates.first(where: { $0.id == selectionID })
          else { return }
          onConfirm(selection)
          dismiss()
        }
        .disabled(selectionID == nil || candidates.isEmpty)
      }
    }
    .padding()
    .frame(minWidth: 360)
    .onAppear {
      if selectionID == nil {
        selectionID = candidates.first?.id
      }
    }
  }
}

/// A pill-styled tag chip used in the inspector.
private struct TagPill: View {
  let title: String

  /// Builds the tag pill UI.
  var body: some View {
    Text(title)
      .font(.caption2)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.secondary.opacity(0.12))
      .clipShape(Capsule())
  }
}
