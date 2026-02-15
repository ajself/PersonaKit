/// Feature-module entrypoint that delegates to the ArgumentParser command tree.
package enum ContextCLIEntrypoint {
  /// Executes the PersonaKit CLI process.
  package static func main() {
    PersonaKitCommand.main()
  }
}
