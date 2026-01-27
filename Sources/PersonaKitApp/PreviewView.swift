import SwiftUI

/// Shows the composed prompt or JSON output for the selected persona.
struct PreviewView: View {
  @Environment(AppStore.self)
  private var store
  @Binding var selectedPanel: PreviewPanel

  /// Builds the preview picker and the selected output panel.
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
              Text(
                store.state.promptPreview.isEmpty
                  ? "No prompt available." : store.state.promptPreview
              )
              .font(.system(.body, design: .monospaced))
              .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
          }
        case .json:
          let jsonText = store.state.jsonPreview
          if jsonText.isEmpty {
            Text("No JSON available.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
              .padding()
          } else {
            JSONEditorView(text: store.bindingForJSONPreview())
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
      }
    }
  }
}
