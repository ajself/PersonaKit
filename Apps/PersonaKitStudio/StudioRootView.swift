import SwiftUI

struct StudioRootView: View {
  @ObservedObject var workspaceStore: WorkspaceStore
  @State private var selection: SidebarItem? = .sessions

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Section("Sessions") {
          sidebarRow(for: .sessions)
        }
        Section("Library") {
          ForEach(SidebarItem.libraryItems, id: \.self) { item in
            sidebarRow(for: item)
          }
        }
        Section("Diagnostics") {
          sidebarRow(for: .validationResults)
        }
      }
      .navigationTitle("PersonaKit Studio")
    } detail: {
      detailView
    }
  }

  private func sidebarRow(for item: SidebarItem) -> some View {
    Label(item.title, systemImage: item.systemImage)
      .tag(item)
  }

  private var detailView: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(selection?.title ?? "PersonaKit Studio")
        .font(.title2)

      if let workspaceURL = workspaceStore.workspaceURL {
        Text(workspaceURL.path())
          .font(.body.monospaced())
          .textSelection(.enabled)
      } else {
        Text("No workspace selected.")
          .foregroundStyle(.secondary)
      }

      Text("Milestone 0: app shell")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
  }
}

private enum SidebarItem: Hashable {
  case sessions
  case personas
  case directives
  case kits
  case essentials
  case skills
  case intents
  case validationResults

  static let libraryItems: [SidebarItem] = [
    .personas,
    .directives,
    .kits,
    .essentials,
    .skills,
    .intents,
  ]

  var title: String {
    switch self {
    case .sessions:
      return "Sessions"
    case .personas:
      return "Personas"
    case .directives:
      return "Directives"
    case .kits:
      return "Kits"
    case .essentials:
      return "Essentials"
    case .skills:
      return "Skills"
    case .intents:
      return "Intents"
    case .validationResults:
      return "Validation Results"
    }
  }

  var systemImage: String {
    switch self {
    case .sessions:
      return "clock.arrow.circlepath"
    case .personas:
      return "person.2"
    case .directives:
      return "list.bullet.rectangle.portrait"
    case .kits:
      return "shippingbox"
    case .essentials:
      return "doc.text"
    case .skills:
      return "hammer"
    case .intents:
      return "scope"
    case .validationResults:
      return "checklist"
    }
  }
}
