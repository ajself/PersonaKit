import ContextCLI

/// Compatibility entrypoint preserved in PersonaKitCore while CLI code migrates.
package enum PersonaKitEntrypoint {
  /// Executes the PersonaKit CLI process.
  package static func main() {
    ContextCLIEntrypoint.main()
  }
}
