import SwiftUI

struct ComposerView: View {
  @Environment(AppStore.self)
  private var store
  @FocusState private var focusedSectionKey: String?
  @State private var showContextHelp = false
  @State private var showEvidenceHelp = false
  @State private var showTaskHelp = false

  private let contextHint = "Hint: repo, files, scope, or constraints."
  private let evidenceHint = "Hint: logs, diffs, screenshots, or repros."
  private let taskHint = "Hint: desired outcome, format, and scope."

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      parameterField(
        key: "context",
        label: "Context",
        required: true,
        hint: contextHint,
        showHelp: $showContextHelp,
        helpTitle: "Context examples",
        helpLines: [
          "Repo: PersonaPad; files: ContentView.swift, PreviewView.swift",
          "App: macOS; issue: focus/shortcut conflict after 1.3.0",
          "Pack: Examples/personapad.pack.json; persona: senior-ios-engineer",
        ]
      )

      parameterField(
        key: "evidence",
        label: "Evidence",
        required: false,
        hint: evidenceHint,
        showHelp: $showEvidenceHelp,
        helpTitle: "Evidence examples",
        helpLines: [
          "Logs: crash at PersonaPadApp/SidebarView.swift:64",
          "Diff: git show abc123",
          "Screenshot: selection highlight missing in sidebar",
        ]
      )

      parameterField(
        key: "task",
        label: "Task",
        required: true,
        hint: taskHint,
        showHelp: $showTaskHelp,
        helpTitle: "Task examples",
        helpLines: [
          "Propose minimal fix and exact files to change",
          "Explain the root cause in 2–3 bullets",
          "Write tests to cover the regression",
        ]
      )
    }
    .onChange(of: store.state.composerFocusRequest) { _, request in
      guard let request else { return }
      focusedSectionKey = request.sectionKey
    }
  }

  @ViewBuilder
  private func parameterField(
    key: String,
    label: String,
    required: Bool,
    hint: String,
    showHelp: Binding<Bool>,
    helpTitle: String,
    helpLines: [String]
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(label).font(.headline)
        if required {
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
        .help("Examples for \(label).")
        .popover(isPresented: showHelp) {
          helpPopover(title: helpTitle, lines: helpLines)
        }
      }

      TextEditor(text: store.bindingForComposerValue(key: key))
        .font(.system(.body, design: .monospaced))
        .focused($focusedSectionKey, equals: key)
        .frame(minHeight: 90)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.secondary.opacity(0.25))
        )

      Text(hint)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

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
