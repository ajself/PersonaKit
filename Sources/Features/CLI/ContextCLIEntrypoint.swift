/// Feature-module entrypoint that delegates to the ArgumentParser command tree.
public enum ContextCLIEntrypoint {
  /// Executes the PersonaKit CLI process.
  public static func main() {
    PersonaKitCommand.main()
  }
}
