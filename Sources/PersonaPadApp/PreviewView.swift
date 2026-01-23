import SwiftUI
import Foundation

struct PreviewView: View {
  @EnvironmentObject private var store: AppStore
  @Binding var selectedPanel: PreviewPanel
  @State private var jsonText: String = ""
  @State private var jsonFormatWorkItem: DispatchWorkItem?

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Picker("Output", selection: $selectedPanel) {
          ForEach(PreviewPanel.allCases) { panel in
            Text(panel.rawValue).tag(panel)
          }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
        Spacer()
      }
      .padding([.top, .horizontal])

      Divider()
        .padding(.top, 8)

      Group {
        switch selectedPanel {
        case .prompt:
          ScrollView {
            VStack(alignment: .leading, spacing: 12) {
              Text(store.promptPreview.isEmpty ? "No prompt available." : store.promptPreview)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
          }
        case .json:
          if jsonText.isEmpty {
            Text("No JSON available.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
              .padding()
          } else {
            JSONEditorView(text: $jsonText)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
      }
    }
    .onAppear { refreshJSON() }
    .onChange(of: store.selectedPersonaID) { _, _ in refreshJSON() }
    .onChange(of: store.personaIndex) { _, _ in refreshJSON() }
    .onChange(of: jsonText) { _, _ in scheduleJSONFormat() }
  }

  private func refreshJSON() {
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

  private func scheduleJSONFormat() {
    jsonFormatWorkItem?.cancel()
    let workItem = DispatchWorkItem { formatJSONIfValid() }
    jsonFormatWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
  }

  private func formatJSONIfValid() {
    guard let formatted = prettyPrintedJSON(from: jsonText) else { return }
    if formatted != jsonText {
      jsonText = formatted
    }
  }

  private func prettyPrintedJSON(from text: String) -> String? {
    guard let data = text.data(using: .utf8) else { return nil }
    guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
    guard JSONSerialization.isValidJSONObject(object) else { return nil }
    let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
    guard let prettyData = try? JSONSerialization.data(withJSONObject: object, options: options) else {
      return nil
    }
    return String(data: prettyData, encoding: .utf8)
  }
}
