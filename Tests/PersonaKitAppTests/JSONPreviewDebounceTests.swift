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
    let store = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppStore()
    }

    let unformatted = "{\"b\":2,\"a\":1}"
    store.send(.preview(.setJSONPreview(unformatted)))
    #expect(store.state.preview.jsonPreview == unformatted)

    await clock.advance(by: .milliseconds(399))
    await Task.yield()
    #expect(store.state.preview.jsonPreview == unformatted)

    await clock.advance(by: .milliseconds(1))
    await clock.run()
    #expect(store.state.preview.jsonPreview == prettyPrintedJSON(from: unformatted))
  }

  @Test("JSON preview formatting uses latest edit")
  @MainActor
  func jsonPreviewFormattingUsesLatestEdit() async {
    let clock = TestClock()
    let store = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppStore()
    }

    let first = "{\"z\":1}"
    let second = "{\"a\":2}"
    store.send(.preview(.setJSONPreview(first)))

    await clock.advance(by: .milliseconds(200))
    await Task.yield()
    store.send(.preview(.setJSONPreview(second)))

    await clock.advance(by: .milliseconds(400))
    await clock.run()

    #expect(store.state.preview.jsonPreview == prettyPrintedJSON(from: second))
    #expect(store.state.preview.jsonPreview != prettyPrintedJSON(from: first))
  }

  @Test("JSON preview does not format invalid JSON")
  @MainActor
  func jsonPreviewDoesNotFormatInvalidJSON() async {
    let clock = TestClock()
    let store = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppStore()
    }

    let invalidJSON = "{invalid"
    store.send(.preview(.setJSONPreview(invalidJSON)))

    await clock.advance(by: .milliseconds(400))
    await clock.run()

    #expect(store.state.preview.jsonPreview == invalidJSON)
  }

  @Test("JSON preview formatting is skipped when scheduling is disabled")
  @MainActor
  func jsonPreviewFormattingIsSkippedWhenSchedulingDisabled() async {
    let clock = TestClock()
    let store = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppStore()
    }

    let unformatted = "{\"b\":2,\"a\":1}"
    store.updateJSONPreview(unformatted, scheduleFormat: false)

    await clock.advance(by: .milliseconds(400))
    await clock.run()

    #expect(store.state.preview.jsonPreview == unformatted)
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
