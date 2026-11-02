import Foundation
import Testing

@testable import ContextCore

struct OpenCodeEnforcementTests {
  private static let allDenied = ["edit-files", "run-commands", "network-access"]

  private func manifest(forbiddenCapabilities: [String]) -> ChecksManifest {
    ChecksManifestDeriver.derive(
      sessionId: "s",
      persona: Persona(
        id: "read-only-auditor",
        version: "1.0",
        name: "Read-Only Auditor",
        summary: "s",
        responsibilities: [],
        values: [],
        nonGoals: [],
        defaultKitIds: [],
        allowedSkillIds: [],
        forbiddenSkillIds: [],
        forbiddenCapabilities: forbiddenCapabilities
      ),
      directive: nil
    )
  }

  private func call(
    _ tool: String,
    paths: [String] = [],
    mcpServers: [String] = [],
    directory: String = "/p",
    worktree: String? = nil
  ) -> OpenCodeToolCall {
    OpenCodeToolCall(
      tool: tool,
      paths: paths,
      mcpServers: mcpServers,
      directory: directory,
      worktree: worktree ?? directory
    )
  }

  private func evaluate(
    _ call: OpenCodeToolCall,
    forbiddenCapabilities: [String],
    globalConfigPaths: [String] = []
  ) -> ClaudeCodeHookCheckDecision {
    OpenCodeHookCheckEvaluator.evaluate(
      call,
      manifest: manifest(forbiddenCapabilities: forbiddenCapabilities),
      globalConfigPaths: globalConfigPaths
    )
  }

  private func isProtected(
    _ path: String,
    directory: String = "/p",
    global: [String] = OpenCodeEnforcement.globalConfigPaths(environment: ["HOME": "/h"])
  ) -> Bool {
    OpenCodeEnforcement.isProtectedPath(path, projectDirectory: directory, globalConfigPaths: global)
  }

  // MARK: - Tool map

  @Test
  func mapsBuiltInsToActionClasses() {
    let capabilities = ["edit-files", "run-commands"]
    for tool in ["edit", "write", "apply_patch", "bash"] {
      let decision = evaluate(call(tool, paths: ["/p/src/a.swift"]), forbiddenCapabilities: capabilities)
      #expect(decision.isDenied, "\(tool) should be denied")
      #expect(decision.reason?.contains("which this session forbids") == true)
      #expect(decision.reason?.hasPrefix("Blocked by PersonaKit contract:") == true)
    }
    for tool in ["read", "task", "webfetch"] {
      #expect(!evaluate(call(tool), forbiddenCapabilities: capabilities).isDenied, "\(tool) should be allowed")
    }
  }

  @Test
  func networkToolsAreDeniedWhenNetworkIsForbidden() {
    for tool in ["webfetch", "websearch"] {
      #expect(evaluate(call(tool), forbiddenCapabilities: ["network-access"]).isDenied)
    }
  }

  @Test
  func readOnlyToolsAreAllowedUnderEveryDeny() {
    for tool in OpenCodeEnforcement.readOnlyTools {
      #expect(!evaluate(call(tool), forbiddenCapabilities: Self.allDenied).isDenied, "\(tool) should be allowed")
    }
  }

  @Test
  func readOnlyListIsSortedAndFreeOfMappedTools() {
    #expect(OpenCodeEnforcement.readOnlyTools == OpenCodeEnforcement.readOnlyTools.sorted())
    let mapped = Set(OpenCodeEnforcement.toolActionClasses.flatMap(\.tools))
    #expect(mapped.isDisjoint(with: OpenCodeEnforcement.readOnlyTools))
  }

  @Test
  func unclassifiedToolFailsClosed() {
    for tool in ["repo_clone", "someplugin_tool"] {
      for capability in Self.allDenied {
        let decision = evaluate(call(tool), forbiddenCapabilities: [capability])
        #expect(decision.isDenied, "\(tool) should be denied when \(capability) is forbidden")
        #expect(decision.reason?.hasPrefix("Blocked by PersonaKit contract:") == true)
      }
      #expect(!evaluate(call(tool), forbiddenCapabilities: []).isDenied)
    }
  }

  @Test
  func policyDenialsTellTheAgentToStopRatherThanWorkAround() {
    let instruction = "Do not retry it through another tool or a workaround; stop and tell the user what you need."
    let denials = [
      evaluate(call("repo_clone"), forbiddenCapabilities: ["run-commands"]),
      evaluate(call("bash"), forbiddenCapabilities: ["run-commands"]),
      evaluate(call("edit", paths: []), forbiddenCapabilities: ["run-commands"]),
      evaluate(call("edit", paths: ["/p/opencode.json"]), forbiddenCapabilities: ["run-commands"]),
      evaluate(
        call("personakit_personakit_resolve_contract", mcpServers: ["personakit", "personakit_personakit"]),
        forbiddenCapabilities: Self.allDenied
      ),
    ]

    #expect(denials[4].reason?.contains("trust is withdrawn") == true)
    for decision in denials {
      let reason = decision.reason ?? ""
      #expect(decision.isDenied)
      #expect(reason.hasSuffix(instruction), "\(reason)")
      #expect(reason.components(separatedBy: instruction).count == 2, "appended once: \(reason)")
      // No mechanism exists to allow a single tool, so the reason never suggests one.
      #expect(!reason.contains("explicitly allow"))
    }

    // A malformed call is an internal fail-closed denial: it names the fix and still ends with the instruction.
    let malformed = evaluate(call("bash", directory: "relative"), forbiddenCapabilities: ["run-commands"])
    #expect(malformed.isDenied)
    #expect(malformed.reason?.contains("To fix it, the user can reinstall the plugin") == true)
    #expect(malformed.reason?.hasSuffix(instruction) == true)
  }

  // MARK: - MCP trust

  @Test
  func trustsPersonaKitToolOnConfiguredServer() {
    let decision = evaluate(
      call("personakit_personakit_resolve_contract", mcpServers: ["cupertino", "personakit"]),
      forbiddenCapabilities: Self.allDenied
    )
    #expect(!decision.isDenied)
  }

  @Test
  func trustFollowsTheRecordedServerName() {
    let custom = manifest(forbiddenCapabilities: Self.allDenied).withMCPServerName("pk.local")
    let key = OpenCodeEnforcement.mcpToolKey(server: "pk.local", tool: "personakit_export")
    #expect(key == "pk_local_personakit_export")
    let trusted = OpenCodeHookCheckEvaluator.evaluate(
      call(key, mcpServers: ["pk.local"]),
      manifest: custom,
      globalConfigPaths: []
    )
    #expect(!trusted.isDenied)
    let defaultName = OpenCodeHookCheckEvaluator.evaluate(
      call("personakit_personakit_export", mcpServers: ["personakit"]),
      manifest: custom,
      globalConfigPaths: []
    )
    #expect(defaultName.isDenied)
  }

  @Test
  func collidingServerWithdrawsTrust() {
    for colliding in ["personakit_personakit", "personakit.personakit"] {
      let decision = evaluate(
        call("personakit_personakit_resolve_contract", mcpServers: ["personakit", colliding]),
        forbiddenCapabilities: Self.allDenied
      )
      #expect(decision.isDenied, "\(colliding) should withdraw trust")
      #expect(decision.reason?.contains("could also come from MCP server") == true)
      #expect(decision.reason?.contains(colliding) == true)
    }
  }

  @Test
  func collisionDoesNotCountTheTrustedServerItself() {
    #expect(
      OpenCodeEnforcement.isTrustedPersonaKitMCPTool(
        "personakit_personakit_validate",
        serverName: "personakit",
        configuredServers: ["personakit", "personakit"]
      )
    )
  }

  @Test
  func untrustedWhenServerNotConfigured() {
    let decision = evaluate(
      call("personakit_personakit_resolve_contract", mcpServers: ["cupertino"]),
      forbiddenCapabilities: Self.allDenied
    )
    #expect(decision.isDenied)
    #expect(decision.reason?.contains("could also come from MCP server") == false)
  }

  @Test
  func nearMissToolsOnTheTrustedServerAreNotTrusted() {
    for tool in [
      "personakit_personakit_export_all",
      "personakit_xpersonakit_export",
      "personakit_write_file",
      "personakit_export",
    ] {
      #expect(
        evaluate(call(tool, mcpServers: ["personakit"]), forbiddenCapabilities: Self.allDenied).isDenied,
        "\(tool) should be denied"
      )
    }
  }

  /// OpenCode compares tool ids by code unit; Swift `==` treats the Kelvin sign as `K`.
  @Test
  func canonicallyEquivalentToolIdsAreNotTrusted() {
    let tool = "Persona\u{212A}it_personakit_resolve_contract"
    #expect(
      !OpenCodeEnforcement.isTrustedPersonaKitMCPTool(tool, serverName: "PersonaKit", configuredServers: ["PersonaKit"])
    )
    #expect(!OpenCodeEnforcement.isPossiblyMCPTool(tool, configuredServers: ["PersonaKit"]))
    // A server spelled with the Kelvin sign is a different server, not the trusted one.
    #expect(
      !OpenCodeEnforcement.isTrustedPersonaKitMCPTool(
        tool,
        serverName: "PersonaKit",
        configuredServers: ["Persona\u{212A}it"]
      )
    )
    #expect(
      OpenCodeEnforcement.collidingServers(
        for: "PersonaKit_personakit_validate",
        serverName: "Persona\u{212A}it",
        configuredServers: ["PersonaKit"]
      ) == ["PersonaKit"]
    )

    var manifest = manifest(forbiddenCapabilities: Self.allDenied)
    manifest = manifest.withMCPServerName("PersonaKit")
    let decision = OpenCodeHookCheckEvaluator.evaluate(
      call(tool, mcpServers: ["PersonaKit"]),
      manifest: manifest,
      globalConfigPaths: []
    )
    #expect(decision.isDenied)
  }

  @Test
  func sanitizesServerAndToolNamesLikeOpenCode() {
    #expect(OpenCodeEnforcement.sanitizeMCPName("a.b c-d_e") == "a_b_c-d_e")
    #expect(OpenCodeEnforcement.sanitizeMCPName("é") == "_")
    // OpenCode replaces per UTF-16 code unit, so an astral character becomes two underscores.
    #expect(OpenCodeEnforcement.sanitizeMCPName("a😀") == "a__")
    #expect(OpenCodeEnforcement.mcpToolKey(server: "my.server", tool: "do it") == "my_server_do_it")
  }

  // MARK: - Protected paths

  @Test
  func protectedPathsCatchMoveAndDotDot() {
    #expect(isProtected("/p/opencode.json"))
    #expect(isProtected("/p/.opencode/personakit/x.checks.json"))
    #expect(isProtected("/p/sub/../.opencode/plugins/a.ts"))
    #expect(isProtected(".opencode/tui.json"))
    #expect(!isProtected("/p/src/opencode.json.bak"))
    #expect(!isProtected("/p/src/a.swift"))
  }

  @Test
  func protectedPathsCatchCodeLoadingSurfaces() {
    #expect(isProtected("/p/.opencode/tools/read.ts"))
    #expect(isProtected("/p/.opencode/tool/x.ts"))
    #expect(isProtected("/p/.opencode/plugin/x.ts"))
    #expect(isProtected("/p/sub/.opencode/plugins/x.ts"))
    #expect(isProtected("/p/sub/opencode.json"))
    #expect(isProtected("/p/sub/tui.jsonc"))
    #expect(isProtected("/h/.config/opencode/plugins/x.ts"))
    #expect(isProtected("/h/.config/opencode/opencode.json"))
    #expect(isProtected("/h/.opencode/plugins/x.ts"))
    #expect(
      isProtected(
        "/h/.cache/opencode/packages/opencode-personakit@2.1.0/node_modules/opencode-personakit/src/server.ts"
      )
    )
    #expect(!isProtected("/elsewhere/opencode.json"))
    #expect(!isProtected("/h/.config/other/x.ts"))
  }

  @Test
  func opencodeComponentAboveTheProjectDirectoryDoesNotCount() {
    #expect(!isProtected("/w/.opencode/proj/src/a.swift", directory: "/w/.opencode/proj"))
    #expect(isProtected("/w/.opencode/proj/.opencode/x.ts", directory: "/w/.opencode/proj"))
    #expect(!isProtected("/w/opencode.json/proj/a.swift", directory: "/w/opencode.json/proj"))
  }

  @Test
  func pathsOutsideTheProjectAreNotProjectProtected() {
    #expect(!isProtected("/p2/.opencode/x.ts"))
    #expect(!isProtected("/p/../p2/opencode.json"))
  }

  @Test
  func globalDirectoryEntryProtectsEverythingUnderIt() {
    let global = ["/d/"]
    #expect(isProtected("/d", global: global))
    #expect(isProtected("/d/x/y.ts", global: global))
    #expect(!isProtected("/dd/x.ts", global: global))
  }

  @Test
  func globalFileEntryProtectsOnlyThatFile() {
    let global = ["/c/oc.json"]
    #expect(isProtected("/c/oc.json", global: global))
    #expect(isProtected("/c/../c/oc.json", global: global))
    #expect(!isProtected("/c/other.json", global: global))
    #expect(!isProtected("/c/oc.json.bak", global: global))
    #expect(!isProtected("/c/oc.json/x", global: global))
  }

  @Test
  func protectedPathsFollowSymlinks() throws {
    let root = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let fileManager = FileManager.default
    let project = root.appendingPathComponent("proj")
    let globalDirectory = root.appendingPathComponent("globalreal")
    let outside = root.appendingPathComponent("outside")
    try fileManager.createDirectory(at: project.appendingPathComponent(".opencode"), withIntermediateDirectories: true)
    try fileManager.createDirectory(at: globalDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)
    try fileManager.createSymbolicLink(
      at: root.appendingPathComponent("projlink"),
      withDestinationURL: project
    )
    try fileManager.createSymbolicLink(
      at: root.appendingPathComponent("globallink"),
      withDestinationURL: globalDirectory
    )
    try fileManager.createSymbolicLink(
      at: project.appendingPathComponent("shortcut"),
      withDestinationURL: project.appendingPathComponent(".opencode")
    )
    try fileManager.createSymbolicLink(
      at: project.appendingPathComponent("opencode.json"),
      withDestinationURL: outside.appendingPathComponent("real.json")
    )

    let proj = project.path
    let projLink = root.appendingPathComponent("projlink").path
    let global = [globalDirectory.path + "/"]
    let globalViaLink = [root.appendingPathComponent("globallink").path + "/"]

    // A symlink inside the project that points at .opencode.
    #expect(isProtected(proj + "/shortcut/plugins/x.ts", directory: proj, global: []))
    // The project directory and the path reach the same place through different spellings.
    #expect(isProtected(proj + "/.opencode/x.ts", directory: projLink, global: []))
    #expect(isProtected(projLink + "/.opencode/x.ts", directory: proj, global: []))
    #expect(!isProtected(projLink + "/src/a.swift", directory: proj, global: []))
    // Global entries and paths reach the same directory through different spellings.
    #expect(
      isProtected(root.appendingPathComponent("globallink").path + "/plugins/x.ts", directory: proj, global: global)
    )
    #expect(isProtected(globalDirectory.path + "/plugins/x.ts", directory: proj, global: globalViaLink))
    // A project config file that is itself a symlink stays protected under its project spelling.
    #expect(isProtected(proj + "/opencode.json", directory: proj, global: []))
    #expect(!isProtected(outside.path + "/other.json", directory: proj, global: []))
  }

  @Test
  func protectedPathDeniesEvenWhenMutationAllowed() {
    let decision = evaluate(
      call("edit", paths: ["/p/opencode.json"]),
      forbiddenCapabilities: ["network-access"]
    )
    #expect(decision.isDenied)
    #expect(decision.reason?.hasPrefix("Blocked by PersonaKit contract:") == true)
    #expect(decision.reason?.contains("PersonaKit enforcement files") == true)
  }

  @Test
  func protectedPathCheckAppliesToEveryMutationToolAndEveryPath() {
    for tool in ["edit", "write", "apply_patch"] {
      let decision = evaluate(
        call(tool, paths: ["/p/src/a.swift", "/p/.opencode/personakit/s.checks.json"]),
        forbiddenCapabilities: []
      )
      #expect(decision.isDenied, "\(tool) should be denied")
    }
    #expect(!evaluate(call("edit", paths: ["/p/src/a.swift"]), forbiddenCapabilities: []).isDenied)
  }

  @Test
  func protectedPathsApplyToGlobalConfigFromTheEnvironment() {
    let global = OpenCodeEnforcement.globalConfigPaths(environment: ["HOME": "/h"])
    let decision = evaluate(
      call("write", paths: ["/h/.config/opencode/plugins/x.ts"]),
      forbiddenCapabilities: [],
      globalConfigPaths: global
    )
    #expect(decision.isDenied)
  }

  @Test
  func nonMutationToolsMayReadProtectedPaths() {
    #expect(!evaluate(call("read", paths: ["/p/opencode.json"]), forbiddenCapabilities: []).isDenied)
  }

  // MARK: - Global config paths

  @Test
  func globalConfigPathsFollowEnvironment() {
    let home = ["HOME": "/h"]
    #expect(
      OpenCodeEnforcement.globalConfigPaths(environment: home)
        == ["/h/.cache/opencode/", "/h/.config/opencode/", "/h/.opencode/"]
    )
    #expect(
      OpenCodeEnforcement.globalConfigPaths(environment: home.merging(["XDG_CONFIG_HOME": "/x"]) { $1 })
        == ["/h/.cache/opencode/", "/h/.opencode/", "/x/opencode/"]
    )
    #expect(
      OpenCodeEnforcement.globalConfigPaths(environment: home.merging(["XDG_CACHE_HOME": "/y"]) { $1 })
        == ["/h/.config/opencode/", "/h/.opencode/", "/y/opencode/"]
    )
    #expect(
      OpenCodeEnforcement.globalConfigPaths(environment: home.merging(["OPENCODE_CONFIG_DIR": "/d"]) { $1 })
        == ["/d/", "/h/.cache/opencode/", "/h/.config/opencode/", "/h/.opencode/"]
    )
    #expect(
      OpenCodeEnforcement.globalConfigPaths(environment: home.merging(["OPENCODE_CONFIG": "/c/oc.json"]) { $1 })
        == ["/c/oc.json", "/h/.cache/opencode/", "/h/.config/opencode/", "/h/.opencode/"]
    )
    #expect(
      OpenCodeEnforcement.globalConfigPaths(environment: home.merging(["OPENCODE_TUI_CONFIG": "/c/tui.json"]) { $1 })
        == ["/c/tui.json", "/h/.cache/opencode/", "/h/.config/opencode/", "/h/.opencode/"]
    )
    #expect(OpenCodeEnforcement.globalConfigPaths(environment: [:]).isEmpty)
  }

  @Test
  func globalConfigPathsAreSortedDeduplicatedAndStandardized() {
    let paths = OpenCodeEnforcement.globalConfigPaths(
      environment: [
        "XDG_CONFIG_HOME": "/x/",
        "XDG_CACHE_HOME": "/z",
        "OPENCODE_CONFIG_DIR": "/x/opencode",
        "OPENCODE_CONFIG": "/c/../c/oc.json",
      ]
    )
    #expect(paths == ["/c/oc.json", "/x/opencode/", "/z/opencode/"])
  }

  @Test
  func globalConfigPathsIgnoreEmptyValues() {
    let paths = OpenCodeEnforcement.globalConfigPaths(
      environment: [
        "HOME": "/h", "XDG_CONFIG_HOME": "", "XDG_CACHE_HOME": "", "OPENCODE_CONFIG_DIR": "",
        "OPENCODE_CONFIG": "", "OPENCODE_TUI_CONFIG": "",
      ]
    )
    #expect(paths == ["/h/.cache/opencode/", "/h/.config/opencode/", "/h/.opencode/"])
  }

  // MARK: - Worktree, case, physical resolution, shadowing, malformed calls

  @Test
  func protectsAncestorsUpToWorktree() {
    for path in ["/w/.opencode/plugins/x.ts", "/w/opencode.json", "/w/other/.opencode/tools/t.ts"] {
      let decision = evaluate(
        call("edit", paths: [path], directory: "/w/sub", worktree: "/w"),
        forbiddenCapabilities: ["network-access"]
      )
      #expect(decision.isDenied, "\(path) should be protected")
      #expect(decision.reason?.contains("PersonaKit enforcement files") == true)
    }
    #expect(
      !evaluate(
        call("edit", paths: ["/w/sub/a.swift"], directory: "/w/sub", worktree: "/w"),
        forbiddenCapabilities: ["network-access"]
      ).isDenied
    )
  }

  @Test
  func protectedNamesIgnoreCase() {
    #expect(isProtected("/p/OPENCODE.JSON"))
    #expect(isProtected("/p/TUI.Json"))
    #expect(isProtected("/p/sub/.OpenCode/plugins/x.ts"))
    #expect(isProtected("/H/.Config/OpenCode/x.ts"))
    #expect(!isProtected("/p/src/OpenCode.json.bak"))
    // APFS folds U+017F to `s` and the Kelvin sign to `k`.
    #expect(isProtected("/p/opencode.j\u{17F}on"))
    #expect(isProtected("/p/.opencode/x", directory: "/P"))
    #expect(
      isProtected(
        "/U\u{17F}ers/x/.config/opencode/x.ts",
        global: OpenCodeEnforcement.globalConfigPaths(environment: ["HOME": "/Users/x"])
      )
    )
    #expect(isProtected("/\u{212A}elvin/.opencode/x.ts", directory: "/Kelvin"))
    #expect(isProtected("/p/tui.json", directory: "/P"))
  }

  @Test
  func combiningMarkAfterSlashSplitsOnByte() throws {
    let root = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let project = root.appendingPathComponent("P")
    try FileManager.default.createDirectory(
      at: project.appendingPathComponent("\u{301}"),
      withIntermediateDirectories: true
    )
    let proj = project.path
    #expect(isProtected(proj + "/\u{301}/../.opencode/plugins/x.ts", directory: proj, global: []))
    #expect(isProtected(proj + "/\u{301}/../opencode.json", directory: proj, global: []))
    #expect(!isProtected(proj + "/\u{301}/a.swift", directory: proj, global: []))
  }

  @Test
  func longLinkChainFailsClosedOrResolves() throws {
    let root = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let project = root.appendingPathComponent("P")
    try FileManager.default.createDirectory(
      at: project.appendingPathComponent(".opencode/plugins"),
      withIntermediateDirectories: true
    )
    func chain(_ letters: String) -> [String] {
      letters.map { String(repeating: String($0), count: 200) }
    }

    // The real tree is deeper than PATH_MAX, so it is built with directory file descriptors. Every link
    // target stays short of PATH_MAX, which is all the kernel checks when it follows them.
    let first = chain("abcd")
    let second = chain("efgh")
    let projectFD = try Self.openDirectory(project.path)
    defer { close(projectFD) }
    let firstFD = try Self.makeDirectories(first, under: projectFD)
    defer { close(firstFD) }
    let secondFD = try Self.makeDirectories(second, under: firstFD)
    defer { close(secondFD) }
    try Self.makeSymbolicLink("d1", to: first.joined(separator: "/"), under: projectFD)
    try Self.makeSymbolicLink("d2", to: second.joined(separator: "/"), under: firstFD)
    try Self.makeSymbolicLink("e", to: "../../../../../../../../.opencode", under: secondFD)

    let proj = project.path
    #expect(isProtected(proj + "/d1/d2/e/plugins/x.ts", directory: proj, global: []))
  }

  @Test
  func symlinkThenDotDotResolvesPhysically() throws {
    let root = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let fileManager = FileManager.default
    let project = root.appendingPathComponent("P")
    let home = root.appendingPathComponent("G")
    let ghConfig = home.appendingPathComponent(".config/gh")
    let pnpmFoo = project.appendingPathComponent("node_modules/.pnpm/foo/node_modules/foo")
    try fileManager.createDirectory(at: ghConfig, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: pnpmFoo, withIntermediateDirectories: true)
    try fileManager.createSymbolicLink(at: project.appendingPathComponent("ln"), withDestinationURL: ghConfig)
    try fileManager.createSymbolicLink(
      at: project.appendingPathComponent("node_modules/foo"),
      withDestinationURL: pnpmFoo
    )
    try fileManager.createSymbolicLink(
      at: project.appendingPathComponent("dangle"),
      withDestinationURL: home.appendingPathComponent(".config/opencode/plugins/d.ts")
    )
    try fileManager.createSymbolicLink(
      atPath: project.appendingPathComponent("rel").path,
      withDestinationPath: "../G/.config/opencode"
    )

    let proj = project.path
    let global = OpenCodeEnforcement.globalConfigPaths(environment: ["HOME": home.path])

    // `ln/..` is the link target's parent on disk (G/.config), not the project.
    #expect(isProtected(proj + "/ln/../opencode/plugins/x.ts", directory: proj, global: global))
    #expect(!isProtected(proj + "/ln/../other/x.ts", directory: proj, global: global))
    // pnpm-style link, climbing out of the target with `..`.
    #expect(
      isProtected(
        proj + "/node_modules/foo/../../../../../.opencode/plugins/x.ts",
        directory: proj,
        global: global
      )
    )
    // A dangling link is followed to its target.
    #expect(isProtected(proj + "/dangle", directory: proj, global: global))
    // A relative link target resolves against the link's parent directory.
    #expect(isProtected(proj + "/rel/plugins/x.ts", directory: proj, global: global))
  }

  @Test
  func missingComponentThenDotDotStillFollowsLinks() throws {
    let root = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let fileManager = FileManager.default
    let project = root.appendingPathComponent("P")
    let home = root.appendingPathComponent("G")
    let ghConfig = home.appendingPathComponent(".config/gh")
    let pnpmFoo = project.appendingPathComponent("node_modules/.pnpm/foo/node_modules/foo")
    try fileManager.createDirectory(
      at: project.appendingPathComponent(".opencode/plugins"),
      withIntermediateDirectories: true
    )
    try fileManager.createDirectory(at: project.appendingPathComponent("src"), withIntermediateDirectories: true)
    try fileManager.createDirectory(at: ghConfig, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: pnpmFoo, withIntermediateDirectories: true)
    try fileManager.createSymbolicLink(
      atPath: project.appendingPathComponent("src/a.ts").path,
      withDestinationPath: "../opencode.json"
    )
    try fileManager.createSymbolicLink(
      atPath: project.appendingPathComponent("foo").path,
      withDestinationPath: ".opencode"
    )
    try fileManager.createSymbolicLink(at: project.appendingPathComponent("ln"), withDestinationURL: ghConfig)
    try fileManager.createSymbolicLink(
      at: project.appendingPathComponent("node_modules/foo"),
      withDestinationURL: pnpmFoo
    )

    let proj = project.path
    let global = OpenCodeEnforcement.globalConfigPaths(environment: ["HOME": home.path])
    // OpenCode creates the missing `nx` (mkdir -p on the raw dirname) before it writes, so the kernel then
    // follows every link behind the `..`.
    #expect(isProtected(proj + "/nx/../src/a.ts", directory: proj, global: global))
    #expect(isProtected(proj + "/nx/../foo/plugins/x.ts", directory: proj, global: global))
    #expect(
      isProtected(
        proj + "/nx/../node_modules/foo/../../../../../.opencode/plugins/x.ts",
        directory: proj,
        global: global
      )
    )
    #expect(isProtected(proj + "/nx/../ln/../opencode/plugins/x.ts", directory: proj, global: global))
    #expect(!isProtected(proj + "/nx/../src/b.ts", directory: proj, global: global))
  }

  @Test
  func symlinkLoopsFailClosed() throws {
    let root = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let fileManager = FileManager.default
    let project = root.appendingPathComponent("P")
    try fileManager.createDirectory(at: project, withIntermediateDirectories: true)
    try fileManager.createSymbolicLink(
      at: project.appendingPathComponent("a"),
      withDestinationURL: project.appendingPathComponent("b")
    )
    try fileManager.createSymbolicLink(
      at: project.appendingPathComponent("b"),
      withDestinationURL: project.appendingPathComponent("a")
    )
    #expect(isProtected(project.path + "/a/x.ts", directory: project.path, global: []))
    #expect(!isProtected(project.path + "/c/x.ts", directory: project.path, global: []))
  }

  @Test
  func mcpPrefixShadowsBuiltIns() {
    let shadowedRead = evaluate(
      call("plan_exit", mcpServers: ["plan"]),
      forbiddenCapabilities: Self.allDenied
    )
    #expect(shadowedRead.isDenied)
    #expect(shadowedRead.reason?.contains("cannot classify") == true)

    let shadowedMutation = evaluate(
      call("apply_patch", paths: [], mcpServers: ["apply"]),
      forbiddenCapabilities: ["run-commands"]
    )
    #expect(shadowedMutation.isDenied)
    #expect(shadowedMutation.reason?.contains("cannot classify") == true)

    // Without a matching server the built-in behavior stands.
    #expect(!evaluate(call("plan_exit", mcpServers: ["cupertino"]), forbiddenCapabilities: Self.allDenied).isDenied)
  }

  @Test
  func malformedCallsDeny() {
    let calls = [
      call("read", directory: ""),
      call("read", directory: "relative/dir"),
      call("read", directory: "/p", worktree: "relative"),
      call("read", directory: "/p", worktree: ""),
      call("edit", paths: []),
      call("edit", paths: ["src/a.swift"]),
      call("read", paths: ["./a.swift"]),
      call("edit", paths: ["/p/ok.swift", "relative.swift"]),
    ]
    for malformed in calls {
      let decision = evaluate(malformed, forbiddenCapabilities: ["network-access"])
      #expect(decision.isDenied, "\(malformed) should be denied")
      #expect(decision.reason?.hasPrefix("Blocked by PersonaKit contract:") == true)
    }
  }

  @Test
  func denyReasonsStripControlCharacters() {
    func hasControlCharacter(_ text: String) -> Bool {
      text.unicodeScalars.contains { $0.value < 0x20 || (0x7F...0x9F).contains($0.value) }
    }
    let dirty = "\u{1b}[2J\u{9b}\u{7f}"
    let protected = evaluate(
      call("edit", paths: ["/p/.opencode/\(dirty)x.ts"]),
      forbiddenCapabilities: []
    )
    #expect(protected.isDenied)
    #expect(protected.reason?.contains("[2J") == true)
    #expect(protected.reason.map(hasControlCharacter) == false)

    let unclassified = evaluate(call("evil\(dirty)"), forbiddenCapabilities: Self.allDenied)
    #expect(unclassified.isDenied)
    #expect(unclassified.reason.map(hasControlCharacter) == false)
  }

  // MARK: - Payload

  @Test
  func callDecodesFromTheHookPayload() throws {
    let json = """
      {"tool":"edit","paths":["/p/a.swift"],"mcpServers":["personakit","cupertino"],"directory":"/p","worktree":"/p"}
      """
    let decoded = try JSONDecoder().decode(OpenCodeToolCall.self, from: Data(json.utf8))
    #expect(decoded == call("edit", paths: ["/p/a.swift"], mcpServers: ["personakit", "cupertino"]))
  }

  private struct POSIXFailure: Error {
    let name: String
    let code: Int32
  }

  private static func openDirectory(_ path: String) throws -> Int32 {
    let descriptor = open(path, O_RDONLY | O_DIRECTORY)
    guard descriptor >= 0 else { throw POSIXFailure(name: "open \(path)", code: errno) }
    return descriptor
  }

  /// Creates nested directories one `mkdirat` at a time and returns a descriptor for the innermost.
  private static func makeDirectories(_ names: [String], under parent: Int32) throws -> Int32 {
    var current = dup(parent)
    for name in names {
      guard mkdirat(current, name, 0o755) == 0 else { throw POSIXFailure(name: "mkdirat", code: errno) }
      let next = openat(current, name, O_RDONLY | O_DIRECTORY)
      close(current)
      guard next >= 0 else { throw POSIXFailure(name: "openat", code: errno) }
      current = next
    }
    return current
  }

  private static func makeSymbolicLink(_ name: String, to target: String, under parent: Int32) throws {
    guard symlinkat(target, parent, name) == 0 else { throw POSIXFailure(name: "symlinkat", code: errno) }
  }

  private static func makeTemporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("opencode-enforcement-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
