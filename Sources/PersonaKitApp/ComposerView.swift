import SwiftUI

/// Edits the core prompt parameters for the selected persona.
struct ComposerView: View {
  @Environment(AppModel.self)
  private var model
  @FocusState private var focusedSectionKey: String?
  @State private var showContextHelp = false
  @State private var showEvidenceHelp = false
  @State private var showTaskHelp = false

  private let contextHint = "Hint: repo, files, scope, or constraints."
  private let evidenceHint = "Hint: logs, diffs, screenshots, or repros."
  private let taskHint = "Hint: desired outcome, format, and scope."

  private let contextHelpLines: [String] = {
    var lines: [String] = []
    lines.append("Repo: PersonaKit; files: ContentView.swift, PreviewView.swift")
    lines.append("App: macOS; issue: focus/shortcut conflict after 1.3.0")
    lines.append("Pack: Examples/personakit.pack.json; persona: senior-ios-engineer")
    return lines
  }()

  private let evidenceHelpLines: [String] = {
    var lines: [String] = []
    lines.append("Logs: crash at PersonaKitApp/SidebarView.swift:64")
    lines.append("Diff: git show abc123")
    lines.append("Screenshot: selection highlight missing in sidebar")
    return lines
  }()

  private let taskHelpLines: [String] = {
    var lines: [String] = []
    lines.append("Propose minimal fix and exact files to change")
    lines.append("Explain the root cause in 2–3 bullets")
    lines.append("Write tests to cover the regression")
    return lines
  }()

  /// Configuration for a single parameter field row.
  private struct ParameterFieldConfig {
    let key: String
    let label: String
    let required: Bool
    let hint: String
    let helpTitle: String
    let helpLines: [String]
  }

  /// Builds the parameter editor fields and help popovers.
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      parameterField(
        config: ParameterFieldConfig(
          key: "context",
          label: "Context",
          required: true,
          hint: contextHint,
          helpTitle: "Context examples",
          helpLines: contextHelpLines
        ),
        showHelp: $showContextHelp
      )

      parameterField(
        config: ParameterFieldConfig(
          key: "evidence",
          label: "Evidence",
          required: false,
          hint: evidenceHint,
          helpTitle: "Evidence examples",
          helpLines: evidenceHelpLines
        ),
        showHelp: $showEvidenceHelp
      )

      parameterField(
        config: ParameterFieldConfig(
          key: "task",
          label: "Task",
          required: true,
          hint: taskHint,
          helpTitle: "Task examples",
          helpLines: taskHelpLines
        ),
        showHelp: $showTaskHelp
      )
    }
    .onChange(of: model.composer.focusRequest) { _, request in
      guard let request else { return }
      focusedSectionKey = request.sectionKey
    }
  }

  /// Renders a labeled, optionally required parameter field with help content.
  @ViewBuilder
  private func parameterField(
    config: ParameterFieldConfig,
    showHelp: Binding<Bool>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(config.label).font(.headline)
        if config.required {
          Text("Required")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Button {
          showHelp.wrappedValue = true
        } label: {
          Image(systemName: "questionmark.circle")
        }
        .buttonStyle(.plain)
        .help("Examples for \(config.label).")
        .popover(isPresented: showHelp) {
          helpPopover(title: config.helpTitle, lines: config.helpLines)
        }
      }

      TextEditor(text: model.bindingForComposerValue(key: config.key))
        .font(.system(.body, design: .monospaced))
        .focused($focusedSectionKey, equals: config.key)
        .frame(minHeight: 90)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.secondary.opacity(0.25))
        )

      Text(config.hint)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  /// Renders the contextual help popover content.
  @ViewBuilder
  private func helpPopover(title: String, lines: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.headline)
      ForEach(lines, id: \.self) { line in
        Text("• \(line)")
      }
    }
    .padding()
    .frame(width: 320, alignment: .leading)
  }
}
