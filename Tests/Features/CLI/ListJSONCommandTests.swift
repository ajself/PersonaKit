import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct ListJSONCommandTests {
  @Test
  func allKindsProjectOnly() throws {
    let projectRoot = try makeInitializedRoot()
    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: nil)

    let result = ListJSONCommand.render(scopes: scopes, entityType: .all)
    let document = try parse(result.output)

    #expect(result.exitCode == 0)

    let scopesObject = try #require(document["scopes"] as? [String: String])
    #expect(scopesObject["project"] == projectRoot.path)
    #expect(scopesObject["global"] == nil)

    for key in ["sessions", "personas", "directives", "kits", "skills"] {
      #expect(document[key] is [[String: Any]])
    }

    let personas = try objects(document, "personas")
    #expect(personas.count == 1)
    #expect(personas[0]["id"] as? String == "solo-developer")
    #expect(personas[0]["scope"] as? String == "project")
    #expect(personas[0]["shadows"] is NSNull)
    #expect(personas[0]["shadowedPath"] is NSNull)

    let entity = try #require(personas[0]["entity"] as? [String: Any])
    #expect(entity["id"] as? String == "solo-developer")
    #expect(entity["name"] as? String == "Solo Developer")

    let sessions = try objects(document, "sessions")
    #expect(sessions.map { $0["id"] as? String } == ["solo-dev"])
    #expect(sessions[0]["personaId"] as? String == "solo-developer")
    #expect(sessions[0]["directiveId"] as? String == "small-cli-change")
    #expect(sessions[0]["kitOverrides"] as? [String] == [])
    #expect(sessions[0]["shadows"] is NSNull)
    #expect(sessions[0]["shadowedPath"] is NSNull)
  }

  @Test
  func globalOnlyReportsGlobalScope() throws {
    let globalRoot = try makeInitializedRoot()
    let scopes = ScopeSet(projectScopeURL: nil, globalScopeURL: globalRoot)

    let result = ListJSONCommand.render(scopes: scopes, entityType: .all)
    let document = try parse(result.output)

    #expect(result.exitCode == 0)

    let scopesObject = try #require(document["scopes"] as? [String: String])
    #expect(scopesObject["global"] == globalRoot.path)
    #expect(scopesObject["project"] == nil)

    let personas = try objects(document, "personas")
    #expect(personas[0]["scope"] as? String == "global")
    #expect(personas[0]["shadows"] is NSNull)
  }

  @Test
  func sharedRootReportsAsGlobalOnly() throws {
    let root = try makeInitializedRoot()
    try writeSession(id: "extra", root: root)
    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: root)

    let result = ListJSONCommand.render(scopes: scopes, entityType: .all)
    let document = try parse(result.output)

    #expect(result.exitCode == 0)
    #expect(try #require(document["scopes"] as? [String: String]) == ["global": root.path])

    for key in ["sessions", "personas", "directives", "kits", "skills"] {
      let items = try objects(document, key)
      #expect(!items.isEmpty || key == "kits" || key == "skills")
      #expect(items.allSatisfy { $0["scope"] as? String == "global" })
      #expect(items.allSatisfy { $0["shadows"] is NSNull })
      #expect(items.allSatisfy { $0["shadowedPath"] is NSNull })
    }
  }

  @Test
  func sharedRootSpelledDifferentlyStillCollapses() throws {
    let root = try makeInitializedRoot()
    let respelled = try #require(URL(string: root.absoluteString + "/"))
      .appendingPathComponent("Packs/..")
    let scopes = ScopeSet(projectScopeURL: respelled, globalScopeURL: root)

    let document = try parse(ListJSONCommand.render(scopes: scopes, entityType: .personas).output)

    #expect(try #require(document["scopes"] as? [String: String]).keys.sorted() == ["global"])
    #expect(try objects(document, "personas").allSatisfy { $0["scope"] as? String == "global" })
  }

  @Test
  func sharedRootViaSymlinkCollapses() throws {
    let root = try makeInitializedRoot()
    let link = try makeTempDirectory().appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
    let scopes = ScopeSet(projectScopeURL: link, globalScopeURL: root)

    let document = try parse(ListJSONCommand.render(scopes: scopes, entityType: .personas).output)

    #expect(try #require(document["scopes"] as? [String: String]).keys.sorted() == ["global"])
    #expect(try objects(document, "personas").allSatisfy { $0["scope"] as? String == "global" })
  }

  @Test
  func allKindsMergedWithShadow() throws {
    let (projectRoot, globalRoot) = try makeTwoRoots()
    try writePersona(id: "global-only", name: "Global Only", root: globalRoot)

    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: globalRoot)
    let document = try parse(ListJSONCommand.render(scopes: scopes, entityType: .all).output)

    let personas = try objects(document, "personas")
    #expect(personas.map { $0["id"] as? String } == ["global-only", "solo-developer"])

    let shared = try #require(personas.first { $0["id"] as? String == "solo-developer" })
    #expect(shared["scope"] as? String == "project")
    #expect(shared["shadows"] as? String == "global")
    #expect(shared["shadowedPath"] as? String == "Packs/personas/solo-developer.persona.json")

    let globalOnly = try #require(personas.first { $0["id"] as? String == "global-only" })
    #expect(globalOnly["shadowedPath"] is NSNull)
    #expect(globalOnly["scope"] as? String == "global")
    #expect(globalOnly["shadows"] is NSNull)
    #expect(globalOnly["path"] as? String == "Packs/personas/global-only.persona.json")
  }

  @Test
  func sessionShadowedAcrossRoots() throws {
    let (projectRoot, globalRoot) = try makeTwoRoots()
    try writeSession(id: "shared-review", root: globalRoot)
    try writeSession(id: "shared-review", root: projectRoot)
    try writeSession(id: "global-review", root: globalRoot)

    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: globalRoot)
    let document = try parse(ListJSONCommand.render(scopes: scopes, entityType: .sessions).output)
    let sessions = try objects(document, "sessions")

    #expect(sessions.map { $0["id"] as? String } == ["global-review", "shared-review", "solo-dev"])

    let shared = try #require(sessions.first { $0["id"] as? String == "shared-review" })
    #expect(shared["scope"] as? String == "project")
    #expect(shared["shadows"] as? String == "global")
    #expect(shared["path"] as? String == "Sessions/shared-review.session.json")
    #expect(shared["shadowedPath"] as? String == "Sessions/shared-review.session.json")

    let globalOnly = try #require(sessions.first { $0["id"] as? String == "global-review" })
    #expect(globalOnly["scope"] as? String == "global")
    #expect(globalOnly["shadows"] is NSNull)
    #expect(globalOnly["shadowedPath"] is NSNull)
  }

  @Test
  func shadowedPathNamesTheHiddenFileWhenFilenamesDiffer() throws {
    let (projectRoot, globalRoot) = try makeTwoRoots()
    try writePersona(id: "p", name: "Winner", root: projectRoot, filename: "a")
    try writePersona(id: "p", name: "Hidden", root: globalRoot, filename: "b")

    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: globalRoot)
    let document = try parse(ListJSONCommand.render(scopes: scopes, entityType: .personas).output)
    let winner = try #require(try objects(document, "personas").first { $0["id"] as? String == "p" })

    #expect(winner["scope"] as? String == "project")
    #expect(winner["path"] as? String == "Packs/personas/a.persona.json")
    #expect(winner["shadows"] as? String == "global")
    #expect(winner["shadowedPath"] as? String == "Packs/personas/b.persona.json")
  }

  @Test
  func singleKindOmitsOtherArrays() throws {
    let projectRoot = try makeInitializedRoot()
    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: nil)

    let document = try parse(ListJSONCommand.render(scopes: scopes, entityType: .personas).output)

    #expect(Set(document.keys) == ["scopes", "personas"])
  }

  @Test
  func pathIsRelativeToScopeRoot() throws {
    let projectRoot = try makeInitializedRoot()
    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: nil)
    let document = try parse(ListJSONCommand.render(scopes: scopes, entityType: .all).output)

    let personas = try objects(document, "personas")
    #expect(personas[0]["path"] as? String == "Packs/personas/solo-developer.persona.json")

    let sessions = try objects(document, "sessions")
    #expect(sessions[0]["path"] as? String == "Sessions/solo-dev.session.json")
  }

  @Test
  func kitOverridesAreSorted() throws {
    let projectRoot = try makeInitializedRoot()
    try writeSession(id: "with-kits", root: projectRoot, kitOverrides: ["zeta-kit", "alpha-kit"])
    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: nil)

    let document = try parse(ListJSONCommand.render(scopes: scopes, entityType: .sessions).output)
    let session = try #require(try objects(document, "sessions").first { $0["id"] as? String == "with-kits" })

    #expect(session["kitOverrides"] as? [String] == ["alpha-kit", "zeta-kit"])
  }

  @Test
  func outputIsSortedAndStable() throws {
    let (projectRoot, globalRoot) = try makeTwoRoots()
    try writePersona(id: "zulu", name: "Zulu", root: projectRoot)
    try writePersona(id: "alpha", name: "Alpha", root: globalRoot)
    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: globalRoot)

    let first = ListJSONCommand.render(scopes: scopes, entityType: .all)
    let second = ListJSONCommand.render(scopes: scopes, entityType: .all)

    #expect(first.output == second.output)

    let document = try parse(first.output)
    for key in ["sessions", "personas", "directives", "kits", "skills"] {
      let ids = try objects(document, key).compactMap { $0["id"] as? String }
      #expect(ids == ids.sorted())
    }
    #expect(try objects(document, "personas").map { $0["id"] as? String } == ["alpha", "solo-developer", "zulu"])
  }

  @Test
  func registryErrorCarriesScope() throws {
    let (projectRoot, globalRoot) = try makeTwoRoots()
    try writeRaw("{", to: globalRoot.appendingPathComponent("Packs/personas/broken.persona.json"))

    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: globalRoot)
    let result = ListJSONCommand.render(scopes: scopes, entityType: .all)
    let document = try parse(result.output)
    let errors = try objects(document, "errors")

    #expect(result.exitCode == 1)
    #expect(document["personas"] == nil)
    #expect(errors.count == 1)
    #expect(errors[0]["scope"] as? String == "global")
    #expect(errors[0]["path"] as? String == "Packs/personas/broken.persona.json")
    #expect(errors[0]["entityType"] as? String == "persona")
    #expect(errors[0]["id"] is NSNull)
    #expect((errors[0]["message"] as? String)?.isEmpty == false)
  }

  @Test
  func sessionErrorsAreAllCollected() throws {
    let projectRoot = try makeInitializedRoot()
    try writeRaw("{", to: projectRoot.appendingPathComponent("Sessions/broken.session.json"))
    try writeRaw(
      #"{"id":"other","personaId":"solo-developer","directiveId":"small-cli-change"}"#,
      to: projectRoot.appendingPathComponent("Sessions/mismatch.session.json")
    )

    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: nil)
    let result = ListJSONCommand.render(scopes: scopes, entityType: .sessions)
    let errors = try objects(try parse(result.output), "errors")

    #expect(result.exitCode == 1)
    #expect(errors.count == 2)
    #expect(errors.map { $0["scope"] as? String } == ["project", "project"])
    #expect(errors.map { $0["entityType"] as? String } == ["session", "session"])
    #expect(
      errors.map { $0["path"] as? String }
        == ["Sessions/broken.session.json", "Sessions/mismatch.session.json"]
    )

    let mismatch = try #require(errors.last?["message"] as? String)
    #expect(mismatch.contains("Sessions/mismatch.session.json"))
    #expect(!mismatch.contains(projectRoot.path))
  }

  @Test
  func errorsAreSortedByScopeThenPath() throws {
    let (projectRoot, globalRoot) = try makeTwoRoots()
    try writeRaw("{", to: projectRoot.appendingPathComponent("Packs/personas/b.persona.json"))
    try writeRaw("{", to: projectRoot.appendingPathComponent("Packs/personas/a.persona.json"))
    try writeRaw("{", to: globalRoot.appendingPathComponent("Packs/kits/z.kit.json"))

    let scopes = ScopeSet(projectScopeURL: projectRoot, globalScopeURL: globalRoot)
    let errors = try objects(try parse(ListJSONCommand.render(scopes: scopes, entityType: .all).output), "errors")

    #expect(
      errors.map { "\($0["scope"] as? String ?? "")|\($0["path"] as? String ?? "")" } == [
        "global|Packs/kits/z.kit.json",
        "project|Packs/personas/a.persona.json",
        "project|Packs/personas/b.persona.json",
      ]
    )
  }

  @Test
  func noScopeIsNoLibrary() throws {
    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit", "list", "all", "--json", "--no-project", "--no-global",
      ])
    }

    #expect(status == 0)
    #expect(output == ListJSONCommand.noLibraryDocument + "\n")

    let document = try parse(output)
    #expect(document["noLibrary"] as? Bool == true)
    #expect((document["errors"] as? [Any])?.isEmpty == true)
  }

  @Test
  func cliJSONListsThroughRoot() throws {
    let root = try makeInitializedRoot()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit", "list", "--root", root.path, "--json", "personas",
      ])
    }

    #expect(status == 0)
    #expect(try objects(try parse(output), "personas").map { $0["id"] as? String } == ["solo-developer"])
  }

  @Test
  func cliJSONFailureExitsOne() throws {
    let root = try makeInitializedRoot()
    try writeRaw("{", to: root.appendingPathComponent("Packs/kits/bad.kit.json"))

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit", "list", "--root", root.path, "--json", "kits",
      ])
    }

    #expect(status == 1)
    #expect(try objects(try parse(output), "errors").count == 1)
  }

  @Test
  func allKindRequiresJSON() throws {
    let root = try makeInitializedRoot()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: ["personakit", "list", "--root", root.path, "all"])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("--json"))
  }

  @Test
  func textOutputUnchanged() throws {
    let root = try makeInitializedRoot()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: ["personakit", "list", "--root", root.path, "personas"])
    }

    #expect(status == 0)
    #expect(output == "solo-developer — Solo Developer\n")
  }
}

// MARK: - Helpers

private func makeInitializedRoot() throws -> URL {
  let root = try makeTempDirectory().appendingPathComponent("Project/.personakit")
  try PersonaKitInitializer().run(destination: root.path)
  return root.standardizedFileURL
}

private func makeTwoRoots() throws -> (project: URL, global: URL) {
  let base = try makeTempDirectory()
  let project = base.appendingPathComponent("Project/.personakit")
  let global = base.appendingPathComponent("Global/.personakit")
  try PersonaKitInitializer().run(destination: project.path)
  try PersonaKitInitializer().run(destination: global.path)
  return (project.standardizedFileURL, global.standardizedFileURL)
}

private func parse(_ output: String) throws -> [String: Any] {
  let object = try JSONSerialization.jsonObject(with: Data(output.utf8))
  return try #require(object as? [String: Any])
}

private func objects(_ document: [String: Any], _ key: String) throws -> [[String: Any]] {
  try #require(document[key] as? [[String: Any]])
}

private func writeRaw(_ text: String, to url: URL) throws {
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try Data(text.utf8).write(to: url)
}

private func writeSession(id: String, root: URL, kitOverrides: [String]? = nil) throws {
  let session = SessionFile(
    id: id,
    personaId: "solo-developer",
    directiveId: "small-cli-change",
    kitOverrides: kitOverrides
  )
  try writeRaw(
    try jsonText(session),
    to: root.appendingPathComponent("Sessions/\(id).session.json")
  )
}

private func writePersona(id: String, name: String, root: URL, filename: String? = nil) throws {
  let persona = Persona(
    id: id,
    version: "1.0",
    name: name,
    summary: "Fixture persona.",
    responsibilities: [],
    values: [],
    nonGoals: [],
    defaultKitIds: [],
    allowedSkillIds: [],
    forbiddenSkillIds: []
  )
  try writeRaw(
    try jsonText(persona),
    to: root.appendingPathComponent("Packs/personas/\(filename ?? id).persona.json")
  )
}

private func jsonText<Value: Encodable>(_ value: Value) throws -> String {
  try #require(String(bytes: try JSONEncoder().encode(value), encoding: .utf8))
}
