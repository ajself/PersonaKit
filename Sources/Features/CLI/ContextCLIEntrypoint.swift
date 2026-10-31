import ArgumentParser
import Foundation

/// Feature-module entrypoint that delegates to the ArgumentParser command tree.
public enum ContextCLIEntrypoint {
  /// Executes the PersonaKit CLI process.
  public static func main() {
    do {
      var command = try PersonaKitCommand.parseAsRoot()
      try command.run()
    } catch {
      exit(report(error))
    }
  }

  /// Reports a thrown error as ArgumentParser's `main()` would, but sends error text through the sanitizing
  /// stderr stream, since errors often quote `.personakit` content. Help, version, and completion output
  /// prints unchanged: completion candidates drop any id with control characters before they get here.
  /// Returns the exit code.
  static func report(_ error: Error) -> Int32 {
    let code = PersonaKitCommand.exitCode(for: error)
    let message = PersonaKitCommand.fullMessage(for: error)
    guard !message.isEmpty else {
      return code.rawValue
    }

    if code == .success {
      print(message)
    } else {
      var stderrStream = StandardError()
      stderrStream.write(message + "\n")
    }
    return code.rawValue
  }
}
