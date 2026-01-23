import SwiftUI
import Foundation
import PersonaPadCore

struct PreviewView: View {
  @EnvironmentObject private var store: AppStore
  @State private var selectedPanel: Panel = .prompt
  @State private var jsonText: String = ""
  @State private var jsonIsPrettyPrinted = false

  private enum Panel: String, CaseIterable, Identifiable {
    case prompt = "Prompt"
    case json = "JSON"

    var id: String { rawValue }
  }

  private var selectedPersona: Persona? {
    guard let id = store.selectedPersonaID else { return nil }
    return store.personaIndex[id]?.persona
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        Picker("Panel", selection: $selectedPanel) {
          ForEach(Panel.allCases) { panel in
            Text(panel.rawValue).tag(panel)
          }
        }
        .pickerStyle(.segmented)

        Spacer()

        if selectedPanel == .json {
          Button("Format JSON") { formatJSON() }
            .disabled(store.selectedPersonaID == nil)
        }
      }
      .padding([.top, .horizontal])

      switch selectedPanel {
      case .prompt:
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            if let persona = selectedPersona, let about = persona.about, !about.isEmpty {
              Text(about)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Text(store.promptPreview.isEmpty ? "Select a persona and fill fields to see the composed prompt." : store.promptPreview)
              .font(.system(.body, design: .monospaced))
              .textSelection(.enabled)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
        }
      case .json:
        if jsonText.isEmpty {
          Text("Select a persona to see JSON.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
        } else {
          JSONEditorView(text: $jsonText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .onAppear { refreshJSON() }
    .onChange(of: store.selectedPersonaID) { _ in refreshJSON() }
    .onChange(of: store.personaIndex) { _ in refreshJSON() }
  }

  private func refreshJSON() {
    jsonText = buildPersonaJSON(prettyPrinted: jsonIsPrettyPrinted)
  }

  private func formatJSON() {
    jsonIsPrettyPrinted = true
    jsonText = buildPersonaJSON(prettyPrinted: true)
  }

  private func buildPersonaJSON(prettyPrinted: Bool) -> String {
    // JSON viewer uses the resolved persona from the store (post-merge).
    guard let id = store.selectedPersonaID, let persona = store.personaIndex[id]?.persona else {
      return ""
    }

    let encoder = JSONEncoder()
    if prettyPrinted {
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    } else {
      encoder.outputFormatting = [.sortedKeys]
    }

    guard let data = try? encoder.encode(persona),
          let text = String(data: data, encoding: .utf8) else {
      return ""
    }
    return text
  }
}
