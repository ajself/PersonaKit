import Dependencies
import Foundation
import PersonaKitCore

/// JSON preview generation and formatting for ``AppModel``.
extension AppModel {
  /// Updates the JSON preview text and optionally schedules formatting.
  func updateJSONPreview(_ text: String, scheduleFormat: Bool) {
    guard text != preview.jsonPreview else { return }
    preview.jsonPreview = text
    if scheduleFormat {
      scheduleJSONFormat()
    }
  }

  private func scheduleJSONFormat() {
    @Dependency(\.continuousClock) var clock
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
    guard let formatted = prettyPrintedJSON(from: preview.jsonPreview) else { return }
    guard formatted != preview.jsonPreview else { return }
    preview.jsonPreview = formatted
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
