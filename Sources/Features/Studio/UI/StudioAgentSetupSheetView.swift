import StudioFoundation
import SwiftUI

/// Read-only setup steps for wiring PersonaKit into coding agents, each with a Copy button.
struct StudioAgentSetupSheetView: View {
  var pasteboardWriter: any PasteboardWriting = PasteboardClient()
  let onDone: () -> Void

  @State private var copiedCommandID: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Set Up Agents")
          .font(.title2)
          .fontWeight(.semibold)

        Text("Run these steps yourself. Studio doesn't install or change anything.")
          .foregroundStyle(.secondary)
      }
      .padding()

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          ForEach(Array(StudioAgentSetupGuide.steps.enumerated()), id: \.element.id) { index, step in
            stepView(number: index + 1, step: step)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
      }

      Divider()

      HStack {
        Link("Open GitHub Releases", destination: StudioAgentSetupGuide.releasesURL)

        Spacer()

        Button("Done", action: onDone)
          .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(minWidth: 560, idealWidth: 620, minHeight: 520, idealHeight: 640)
  }

  private func stepView(number: Int, step: StudioAgentSetupStep) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("\(number). \(step.title)")
        .font(.headline)

      Text(step.detail)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      ForEach(step.commands) { command in
        commandView(command)
      }
    }
  }

  private func commandView(_ command: StudioAgentSetupCommand) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(command.label)
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(alignment: .top, spacing: 8) {
        Text(command.text)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)

        Button(copiedCommandID == command.id ? "Copied" : "Copy") {
          if pasteboardWriter.writeString(command.text) {
            copiedCommandID = command.id
          }
        }
        .controlSize(.small)
        .accessibilityLabel("Copy \(command.label)")
      }
      .padding(10)
      .background(
        RoundedRectangle(cornerRadius: StudioDesign.Radius.card)
          .fill(.quaternary.opacity(0.4))
      )
    }
  }
}
