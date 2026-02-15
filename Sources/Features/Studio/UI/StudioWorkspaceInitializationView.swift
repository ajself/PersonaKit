import SwiftUI

/// Workspace-missing state with initialization and folder-picking actions.
struct StudioWorkspaceInitializationView: View {
  let loadErrorMessage: String
  let onInitialize: () -> Void
  let onChooseAnotherFolder: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      ContentUnavailableView(
        "Workspace Missing PersonaKit",
        systemImage: "folder.badge.plus",
        description: Text(loadErrorMessage)
      )

      HStack(spacing: 10) {
        Button("Initialize PersonaKit Structure") {
          onInitialize()
        }
        .buttonStyle(.borderedProminent)

        Button("Choose another folder") {
          onChooseAnotherFolder()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
