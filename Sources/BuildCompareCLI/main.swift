import Foundation

@main
enum BuildCompareCLI {
  static func main() {
    do {
      try run()
    } catch {
      if let toolError = error as? ToolError {
        fputs("Error: \(toolError.description)\n", stderr)
      } else {
        fputs("Error: \(error)\n", stderr)
      }
      exit(1)
    }
  }
}
