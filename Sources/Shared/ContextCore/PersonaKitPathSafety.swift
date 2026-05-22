import Foundation

enum PersonaKitPathSafety {
  static func isSafePathSegment(_ value: String) -> Bool {
    guard !value.isEmpty else {
      return false
    }

    guard value != ".", value != ".." else {
      return false
    }

    return !value.contains("/") && !value.contains("\\")
  }

  static func expectedPath(
    baseRelativePath: String,
    segment: String,
    suffix: String
  ) -> String {
    guard isSafePathSegment(segment) else {
      return "\(baseRelativePath)/<invalid>\(suffix)"
    }

    return "\(baseRelativePath)/\(segment)\(suffix)"
  }

  static func fileURL(
    root: URL,
    baseRelativePath: String,
    segment: String,
    suffix: String
  ) -> URL? {
    guard isSafePathSegment(segment) else {
      return nil
    }

    let baseURL = root.appendingPathComponent(baseRelativePath, isDirectory: true)
    let fileURL = baseURL.appendingPathComponent(segment + suffix, isDirectory: false).standardizedFileURL

    guard contains(fileURL, in: baseURL) else {
      return nil
    }

    return fileURL
  }

  static func containedFileURL(
    root: URL,
    baseRelativePath: String,
    segment: String,
    suffix: String
  ) -> URL? {
    guard
      let fileURL = fileURL(
        root: root,
        baseRelativePath: baseRelativePath,
        segment: segment,
        suffix: suffix
      )
    else {
      return nil
    }

    let baseURL = root.appendingPathComponent(baseRelativePath, isDirectory: true)

    guard canonicalContains(baseURL, in: root) else {
      return nil
    }

    guard canonicalContains(fileURL, in: baseURL) else {
      return nil
    }

    return fileURL.standardizedFileURL
  }

  static func canonicalContains(
    _ fileURL: URL,
    in baseURL: URL
  ) -> Bool {
    let canonicalFileURL = fileURL.resolvingSymlinksInPath().standardizedFileURL
    let canonicalBaseURL = baseURL.resolvingSymlinksInPath().standardizedFileURL

    return contains(canonicalFileURL, in: canonicalBaseURL)
  }

  private static func contains(
    _ fileURL: URL,
    in baseURL: URL
  ) -> Bool {
    let filePath = fileURL.standardizedFileURL.path
    let basePath = baseURL.standardizedFileURL.path

    return filePath == basePath || filePath.hasPrefix(basePath + "/")
  }
}
