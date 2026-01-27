import Clocks
import Dependencies
import Foundation
import Testing

@testable import PersonaKitApp

@Suite("JSON Preview Debounce")
struct JSONPreviewDebounceTests {
  @Test("JSON preview formatting debounces")
  @MainActor
  func jsonPreviewFormattingDebounces() async {
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppModel()
    }

    let unformatted = "{\"b\":2,\"a\":1}"
    model.updatePreviewJSON(unformatted)
    #expect(model.preview.jsonPreview == unformatted)

    await clock.advance(by: .milliseconds(399))
    await Task.yield()
    #expect(model.preview.jsonPreview == unformatted)

    await clock.advance(by: .milliseconds(1))
    await clock.run()
    #expect(model.preview.jsonPreview == prettyPrintedJSON(from: unformatted))
  }

  @Test("JSON preview formatting uses latest edit")
  @MainActor
  func jsonPreviewFormattingUsesLatestEdit() async {
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppModel()
    }

    let first = "{\"z\":1}"
    let second = "{\"a\":2}"
    model.updatePreviewJSON(first)

    await clock.advance(by: .milliseconds(200))
    await Task.yield()
    model.updatePreviewJSON(second)

    await clock.advance(by: .milliseconds(400))
    await clock.run()

    #expect(model.preview.jsonPreview == prettyPrintedJSON(from: second))
    #expect(model.preview.jsonPreview != prettyPrintedJSON(from: first))
  }

  @Test("JSON preview does not format invalid JSON")
  @MainActor
  func jsonPreviewDoesNotFormatInvalidJSON() async {
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppModel()
    }

    let invalidJSON = "{invalid"
    model.updatePreviewJSON(invalidJSON)

    await clock.advance(by: .milliseconds(400))
    await clock.run()

    #expect(model.preview.jsonPreview == invalidJSON)
  }

  @Test("JSON preview formatting is skipped when scheduling is disabled")
  @MainActor
  func jsonPreviewFormattingIsSkippedWhenSchedulingDisabled() async {
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppModel()
    }

    let unformatted = "{\"b\":2,\"a\":1}"
    model.updateJSONPreview(unformatted, scheduleFormat: false)

    await clock.advance(by: .milliseconds(400))
    await clock.run()

    #expect(model.preview.jsonPreview == unformatted)
  }

  private func prettyPrintedJSON(from text: String) -> String {
    let data = text.data(using: .utf8) ?? Data()
    let object = (try? JSONSerialization.jsonObject(with: data)) ?? [:]
    let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
    let prettyData =
      (try? JSONSerialization.data(withJSONObject: object, options: options)) ?? Data()
    return String(bytes: prettyData, encoding: .utf8) ?? ""
  }
}
