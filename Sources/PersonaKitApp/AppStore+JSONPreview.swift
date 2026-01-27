import Foundation
import PersonaKitCore

/// JSON preview generation and formatting for ``AppStore``.
extension AppStore {
  /// Updates the JSON preview text and optionally schedules formatting.
  func updateJSONPreview(_ text: String, scheduleFormat: Bool) {
    guard text != state.jsonPreview else { return }
    state.jsonPreview = text
    if scheduleFormat {
      scheduleJSONFormat()
    }
  }

  /// Encodes a ``Persona`` as JSON using deterministic key ordering.
  func buildPersonaJSON(persona: Persona, prettyPrinted: Bool) -> String {
    let encoder = JSONEncoder()
    if prettyPrinted {
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    } else {
      encoder.outputFormatting = [.sortedKeys]
    }

    guard let data = try? encoder.encode(persona),
      let text = String(data: data, encoding: .utf8)
    else {
      return ""
    }
    return text
  }

  private func scheduleJSONFormat() {
    jsonFormatTask?.cancel()
    jsonFormatTask = Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        try await clock.sleep(for: .milliseconds(400))
      } catch {
        return
      }
      formatJSONIfValid()
    }
  }

  private func formatJSONIfValid() {
    guard let formatted = prettyPrintedJSON(from: state.jsonPreview) else { return }
    guard formatted != state.jsonPreview else { return }
    state.jsonPreview = formatted
  }

  private func prettyPrintedJSON(from text: String) -> String? {
    guard let data = text.data(using: .utf8) else { return nil }
    guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
    guard JSONSerialization.isValidJSONObject(object) else { return nil }
    let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
    guard let prettyData = try? JSONSerialization.data(withJSONObject: object, options: options)
    else {
      return nil
    }
    return String(data: prettyData, encoding: .utf8)
  }
}
