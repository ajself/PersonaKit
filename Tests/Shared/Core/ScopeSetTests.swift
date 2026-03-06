import Foundation
import Testing

@testable import ContextCore

struct ScopeSetTests {
  @Test
  func emptyWhenBothScopesMissing() {
    let scopes = ScopeSet(projectScopeURL: nil, globalScopeURL: nil)

    #expect(scopes.isEmpty)
    #expect(scopes.loadOrder.isEmpty)
    #expect(scopes.resolutionOrder.isEmpty)
  }

  @Test
  func loadAndResolutionOrderFollowExpectedPriority() throws {
    let root = try makeTempDirectory()
    let project = root.appendingPathComponent("project/.personakit")
    let global = root.appendingPathComponent("global/.personakit")
    let expectedLoadOrder = [global.standardizedFileURL.path, project.standardizedFileURL.path]
    let expectedResolutionOrder = [project.standardizedFileURL.path, global.standardizedFileURL.path]

    let scopes = ScopeSet(projectScopeURL: project, globalScopeURL: global)

    #expect(scopes.loadOrder.map(\.path) == expectedLoadOrder)
    #expect(scopes.resolutionOrder.map(\.path) == expectedResolutionOrder)
  }

  @Test
  func dedupesSameDirectoryAcrossProjectAndGlobal() throws {
    let root = try makeTempDirectory()
    let shared = root.appendingPathComponent(".personakit")
    let scopes = ScopeSet(projectScopeURL: shared, globalScopeURL: shared)

    #expect(scopes.loadOrder.count == 1)
    #expect(scopes.resolutionOrder.count == 1)
    #expect(scopes.loadOrder.first?.path == shared.standardizedFileURL.path)
    #expect(scopes.resolutionOrder.first?.path == shared.standardizedFileURL.path)
  }

  @Test
  func dedupesSymlinkAliases() throws {
    let root = try makeTempDirectory()
    let real = root.appendingPathComponent("real/.personakit")
    let alias = root.appendingPathComponent("alias/.personakit")
    let aliasParent = alias.deletingLastPathComponent()

    try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: aliasParent, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: real)

    let scopes = ScopeSet(projectScopeURL: real, globalScopeURL: alias)

    #expect(scopes.loadOrder.count == 1)
    #expect(scopes.resolutionOrder.count == 1)
  }

  @Test
  func normalizesDotSegmentsBeforeDeduping() throws {
    let root = try makeTempDirectory()
    let canonical = root.appendingPathComponent("pk/.personakit")
    let nonCanonical = root.appendingPathComponent("pk/./.personakit")
    let scopes = ScopeSet(projectScopeURL: nonCanonical, globalScopeURL: canonical)

    #expect(scopes.projectScopeURL?.path == canonical.standardizedFileURL.path)
    #expect(scopes.globalScopeURL?.path == canonical.standardizedFileURL.path)
    #expect(scopes.loadOrder.map(\.path) == [canonical.standardizedFileURL.path])
    #expect(scopes.resolutionOrder.map(\.path) == [canonical.standardizedFileURL.path])
  }
}
