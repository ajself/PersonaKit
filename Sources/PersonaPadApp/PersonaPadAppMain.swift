import SwiftUI
import PersonaPadCore

@main
struct PersonaPadAppMain: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

private final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
