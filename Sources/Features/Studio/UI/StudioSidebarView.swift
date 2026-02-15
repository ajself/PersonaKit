import SwiftUI

/// Sidebar navigation used by the Studio root split view.
struct StudioSidebarView: View {
  @Binding var selection: SidebarItem?

  var body: some View {
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
  }

  private func sidebarRow(for item: SidebarItem) -> some View {
    Label(item.title, systemImage: item.systemImage)
      .tag(item)
  }
}
