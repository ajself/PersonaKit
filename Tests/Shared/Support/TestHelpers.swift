import Darwin
import Foundation

// A single shared lock guards BOTH stdout and stderr capture. Capture redirects
// the process-global STDOUT/STDERR file descriptors via dup2, so two overlapping
// captures would race on the shared fds. This lock prevents that.
//
// Note: the lock alone does NOT make capture safe under a parallel test run — the
// swift-testing runner writes per-test progress to stdout, and that output (from
// *other* tests, not under this lock) lands in a capture's pipe and corrupts it.
// The actual fix for that is running tests serially; see `--no-parallel` in the
// Makefile's SWIFT_TEST_FLAGS. This lock remains as defense-in-depth for anyone
// who runs the suite in parallel anyway.
//
// It must be recursive: some tests legitimately nest a capture inside another
// (e.g. captureStderr { captureStdout { ... } } to swallow stdout while capturing
// stderr). A plain NSLock would self-deadlock on the inner acquire; a recursive
// lock lets the same thread re-enter while still excluding all other threads.
private let captureLock = NSRecursiveLock()

func makeTempDirectory() throws -> URL {
  let base = FileManager.default.temporaryDirectory
  let destination = base.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
  return destination
}

func snapshotFiles(at root: URL) throws -> [String: Data] {
  let fileManager = FileManager.default
  let rootComponents = root.standardizedFileURL.pathComponents
  var results: [String: Data] = [:]

  guard
    let enumerator = fileManager.enumerator(
      at: root,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
  else {
    return results
  }

  for case let fileURL as URL in enumerator {
    let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
    if values.isDirectory == true {
      continue
    }
    let fileComponents = fileURL.standardizedFileURL.pathComponents
    let relativeComponents = fileComponents.dropFirst(rootComponents.count)
    let relativePath = relativeComponents.joined(separator: "/")
    results[relativePath] = try Data(contentsOf: fileURL)
  }

  return results
}

func repoRootURL() -> URL {
  let fileManager = FileManager.default
  var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

  while candidate.path != "/" {
    let packageURL = candidate.appendingPathComponent("Package.swift")
    if fileManager.fileExists(atPath: packageURL.path) {
      return candidate
    }

    candidate.deleteLastPathComponent()
  }

  preconditionFailure("Unable to locate repo root from \(#filePath)")
}

func fixturesRootURL() -> URL {
  repoRootURL().appendingPathComponent("Fixtures")
}

func fixtureKitRootURL() -> URL {
  fixturesRootURL().appendingPathComponent("kit-root")
}

func internalAgentRootURL() -> URL {
  fixturesRootURL().appendingPathComponent("internal-agent-root/.personakit")
}

func readOnlyFixtureRootURL() -> URL {
  fixturesRootURL().appendingPathComponent("read-only-root")
}

func publicStarterRootURL() -> URL {
  repoRootURL().appendingPathComponent("Examples/public-starter/.personakit")
}

func copyFixtureKit(to destination: URL) throws {
  try FileManager.default.copyItem(at: fixtureKitRootURL(), to: destination)
}

/// Builds a project workspace whose session references a persona and directive that
/// live **only** in a separate global scope (the project copy of each is removed).
///
/// Project-scope-only validation reports both references as missing — the exact
/// false-positive Studio shows when sandboxed away from `~/.personakit`. Merged with
/// the returned global scope, the references resolve and validation is clean.
func makeGlobalOnlyReferenceWorkspace() throws -> (
  workspaceURL: URL,
  projectScopeURL: URL,
  globalScopeURL: URL
) {
  let workspaceURL = try makeTempDirectory().appendingPathComponent("Workspace")
  let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")

  try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
  try copyFixtureKit(to: projectScopeURL)
  try FileManager.default.removeItem(
    at: projectScopeURL.appendingPathComponent(
      "Packs/personas/senior-swiftui-engineer.persona.json"
    )
  )
  try FileManager.default.removeItem(
    at: projectScopeURL.appendingPathComponent(
      "Packs/directives/apply-style.directive.json"
    )
  )

  let globalScopeURL = try makeTempDirectory().appendingPathComponent(".personakit")
  try copyFixtureKit(to: globalScopeURL)

  return (workspaceURL, projectScopeURL, globalScopeURL)
}

func normalizedTrailingNewline(_ value: String) -> String {
  var trimmed = value
  while trimmed.last == "\n" {
    trimmed.removeLast()
  }
  return trimmed + "\n"
}

func captureStdout(_ work: () -> Void) -> String {
  captureLock.lock()
  defer { captureLock.unlock() }

  let pipe = Pipe()
  let stdoutFd = dup(STDOUT_FILENO)
  dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

  work()
  fflush(stdout)
  pipe.fileHandleForWriting.closeFile()
  dup2(stdoutFd, STDOUT_FILENO)
  close(stdoutFd)

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8) ?? ""
}

func captureStderr(_ work: () -> Void) -> String {
  captureLock.lock()
  defer { captureLock.unlock() }

  let pipe = Pipe()
  let stderrFd = dup(STDERR_FILENO)
  dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

  work()
  fflush(stderr)
  pipe.fileHandleForWriting.closeFile()
  dup2(stderrFd, STDERR_FILENO)
  close(stderrFd)

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8) ?? ""
}
