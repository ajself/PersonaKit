import SwiftUI
import PersonaPadCore

@main
struct PersonaPadAppMain: App {
  @StateObject private var store = AppStore()
  @State private var showPersonaSwitcher = false

  var body: some Scene {
    WindowGroup("PersonaPad") {
      ContentView(showPersonaSwitcher: $showPersonaSwitcher)
        .environmentObject(store)
        .frame(minWidth: 1100, minHeight: 700)
    }
    .commands {
      CommandGroup(replacing: .newItem) { }
      PersonaPadCommands(store: store, showPersonaSwitcher: $showPersonaSwitcher)
    }
  }
}
