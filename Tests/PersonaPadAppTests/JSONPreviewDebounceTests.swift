import Clocks
import Dependencies
import Foundation
import XCTest

@testable import PersonaPadApp

final class JSONPreviewDebounceTests: XCTestCase {
  @MainActor
  func testJSONPreviewFormattingDebounces() async {
    let clock = TestClock()
    let store = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppStore()
    }

    let unformatted = "{\"b\":2,\"a\":1}"
    store.send(.setJSONPreview(unformatted))
    XCTAssertEqual(store.state.jsonPreview, unformatted)

    await clock.advance(by: .milliseconds(399))
    await Task.yield()
    XCTAssertEqual(store.state.jsonPreview, unformatted)

    await clock.advance(by: .milliseconds(1))
    await Task.yield()
    XCTAssertEqual(store.state.jsonPreview, prettyPrintedJSON(from: unformatted))
  }

  @MainActor
  func testJSONPreviewFormattingUsesLatestEdit() async {
    let clock = TestClock()
    let store = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppStore()
    }

    let first = "{\"z\":1}"
    let second = "{\"a\":2}"
    store.send(.setJSONPreview(first))

    await clock.advance(by: .milliseconds(200))
    await Task.yield()
    store.send(.setJSONPreview(second))

    await clock.advance(by: .milliseconds(400))
    await Task.yield()

    XCTAssertEqual(store.state.jsonPreview, prettyPrintedJSON(from: second))
    XCTAssertNotEqual(store.state.jsonPreview, prettyPrintedJSON(from: first))
  }

  @MainActor
  func testJSONPreviewDoesNotFormatInvalidJSON() async {
    let clock = TestClock()
    let store = withDependencies {
      $0.continuousClock = clock
    } operation: {
      AppStore()
    }

    let invalidJSON = "{invalid"
    store.send(.setJSONPreview(invalidJSON))

    await clock.advance(by: .milliseconds(400))
    await Task.yield()

    XCTAssertEqual(store.state.jsonPreview, invalidJSON)
  }

  private func prettyPrintedJSON(from text: String) -> String {
    let data = text.data(using: .utf8) ?? Data()
    let object = (try? JSONSerialization.jsonObject(with: data)) ?? [:]
    let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
    let prettyData = (try? JSONSerialization.data(withJSONObject: object, options: options)) ?? Data()
    return String(decoding: prettyData, as: UTF8.self)
  }
}
