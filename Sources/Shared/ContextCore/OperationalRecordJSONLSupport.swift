import Foundation

enum OperationalRecordJSONLSupport {
  static func encodeJSONLines<T: Encodable>(
    _ values: [T]
  ) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let lines = values.map { value in
      guard
        let data = try? encoder.encode(value),
        let string = String(data: data, encoding: .utf8)
      else {
        preconditionFailure("Failed to encode operational record as UTF-8 JSON.")
      }

      return string
    }

    return lines.joined(separator: "\n") + "\n"
  }

  static func decodeJSONLines<T: Decodable>(
    relativePath: String,
    projectRoot: URL,
    as type: T.Type
  ) throws -> [T] {
    let document = try OperationalRecordMigrationSupport.readDocument(
      relativePath: relativePath,
      projectRoot: projectRoot
    )
    let decoder = JSONDecoder()
    var results: [T] = []

    for (index, line) in document.split(separator: "\n").enumerated() {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
        continue
      }

      guard let data = trimmed.data(using: .utf8) else {
        throw OperationalRecordError.invalidJSONL(
          "\(relativePath): line \(index + 1): failed to encode JSON line as UTF-8."
        )
      }

      do {
        results.append(try decoder.decode(T.self, from: data))
      } catch {
        throw OperationalRecordError.invalidJSONL(
          "\(relativePath): line \(index + 1): \(error.localizedDescription)"
        )
      }
    }

    return results
  }

  static func decodeOptionalJSONLines<T: Decodable>(
    relativePath: String,
    projectRoot: URL,
    as type: T.Type
  ) throws -> [T] {
    let url = projectRoot.appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
      return []
    }
    return try decodeJSONLines(
      relativePath: relativePath,
      projectRoot: projectRoot,
      as: type
    )
  }

  static func latestEventMap<T>(
    events: [T],
    keyPath: KeyPath<T, String>,
    entryIDKeyPath: KeyPath<T, String>
  ) -> [String: T] {
    var latestByKey: [String: T] = [:]

    for event in events {
      let key = event[keyPath: keyPath]
      let entryID = event[keyPath: entryIDKeyPath]
      if let existing = latestByKey[key] {
        if entryID > existing[keyPath: entryIDKeyPath] {
          latestByKey[key] = event
        }
      } else {
        latestByKey[key] = event
      }
    }

    return latestByKey
  }

  static func formatIDList(_ values: [String]) -> String {
    guard !values.isEmpty else {
      return ""
    }

    return values.map { "`\($0)`" }.joined(separator: ", ")
  }

  static func escapeTableCell(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "|", with: "\\|")
  }
}
