import ArgumentParser

/// Swift package entrypoint that delegates to the ArgumentParser command tree.
package enum PersonaKitEntrypoint {
  /// Executes the PersonaKit CLI process.
  package static func main() {
    PersonaKitCommand.main()
  }
}
