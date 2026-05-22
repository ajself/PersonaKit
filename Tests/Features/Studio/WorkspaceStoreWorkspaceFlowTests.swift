import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

@MainActor
struct WorkspaceStoreWorkspaceFlowTests {
  @Test
  func validateWorkspaceForwardsStandardizedWorkspaceURL() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { workspaceURL in
        #expect(workspaceURL.path() == "/Workspace")
        return makeValidation(entityID: "persona-a")
      }
    )

    store.workspaceURL = workspaceURL
    store.validateWorkspace()

    await waitFor {
      store.validation.issues.first?.entityId == "persona-a"
    }
  }

  @Test
  func validateWorkspaceIgnoresStaleResultAfterWorkspaceIsCleared() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let validationGate = BlockingCallGate()

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        _ = validationGate.markStarted()
        validationGate.waitUntilReleased()
        validationGate.markFinished()

        return makeValidation(entityID: "persona-a")
      }
    )

    store.workspaceURL = workspaceURL
    store.validateWorkspace()

    await waitFor {
      validationGate.hasStarted
    }

    store.workspaceURL = nil
    store.validateWorkspace()

    #expect(store.validation == .empty)
    #expect(store.validationErrorMessage == nil)

    validationGate.release()

    await waitFor {
      validationGate.hasFinished
    }
    await yieldTasks()

    #expect(store.validation == .empty)
    #expect(store.validationErrorMessage == nil)
  }

  @Test
  func validateWorkspaceAppendsSessionDiagnosticsIssues() async throws {
    let workspaceURL = try makeTempDirectory()
    let sessionFileURL = workspaceURL.appendingPathComponent(".personakit/Sessions/session-a.session.json")

    try FileManager.default.createDirectory(
      at: sessionFileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(
      """
      {
        "directiveId" : "directive-a",
        "id" : "session-a",
        "kitOverrides" : [
          "missing-kit"
        ],
        "personaId" : "persona-a"
      }
      """.utf8
    )
    .write(to: sessionFileURL, options: [.atomic])

    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "session-a",
          personaId: "persona-a",
          directiveId: "directive-a",
          fileURL: sessionFileURL,
          sourceScope: .project
        )
      ],
      personas: [
        WorkspaceListItem(
          id: "persona-a",
          displayName: "Persona A",
          fileURL: URL(fileURLWithPath: "/unused/persona-a.persona.json"),
          sourceScope: .project
        )
      ],
      directives: [
        WorkspaceListItem(
          id: "directive-a",
          displayName: "Directive A",
          fileURL: URL(fileURLWithPath: "/unused/directive-a.directive.json"),
          sourceScope: .project
        )
      ],
      kits: [],
      skills: [],
      intents: [],
      essentials: []
    )
    let coreValidation = WorkspaceValidationSnapshot(
      summary: "core-summary",
      issues: [
        WorkspaceValidationIssue(
          entityType: .persona,
          entityId: "persona-a",
          field: "schema",
          filePath: nil,
          message: "Core issue",
          severity: .error
        )
      ]
    )
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        coreValidation
      }
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.validation.issues.count == 2
    }

    #expect(store.validation.summary == "core-summary")
    #expect(store.validation.issues[0].entityType == .persona)
    let hasSessionKitIssue = store.validation.issues.contains(where: { issue in
      issue.entityType == .session
        && issue.entityId == "session-a"
        && issue.field == "kitOverrides"
    })
    #expect(hasSessionKitIssue)
  }

  @Test
  func openWorkspacePickerLoadsSelectedWorkspaceFromInjectedPicker() async {
    let selectedWorkspaceURL = URL(fileURLWithPath: "/PickedWorkspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { workspaceURL in
        #expect(workspaceURL.standardizedFileURL == selectedWorkspaceURL.standardizedFileURL)
        return WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspacePicker: WorkspaceStoreStubWorkspacePicker(
        selectedURL: selectedWorkspaceURL
      )
    )

    store.openWorkspacePicker()

    await waitFor {
      store.workspaceURL?.standardizedFileURL == selectedWorkspaceURL.standardizedFileURL
    }
  }

  @Test
  func initializeWorkspaceStructureCreatesFoldersAndReloadsWorkspace() async throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let state = WorkspaceStoreInitializationState()

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        if state.isInitialized {
          return WorkspaceSnapshot.empty
        }

        throw MissingPersonaKitDirectoryError(
          projectScopeURL: URL(fileURLWithPath: "/Workspace/.personakit")
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { directoryURL in
            state.appendCreatedDirectory(directoryURL.standardizedFileURL)
            state.markInitialized()
          }
        )
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.loadErrorMessage?.hasPrefix("Missing PersonaKit directory at ") == true
    }
    #expect(store.canInitializeWorkspaceStructure)

    store.initializeWorkspaceStructure()

    await waitFor {
      store.loadErrorMessage == nil
    }
    #expect(!store.canInitializeWorkspaceStructure)

    let expectedDirectories: [URL] = [
      workspaceURL.appendingPathComponent(".personakit"),
      workspaceURL.appendingPathComponent(".personakit/Packs"),
      workspaceURL.appendingPathComponent(".personakit/Packs/personas"),
      workspaceURL.appendingPathComponent(".personakit/Packs/directives"),
      workspaceURL.appendingPathComponent(".personakit/Packs/kits"),
      workspaceURL.appendingPathComponent(".personakit/Packs/intents"),
      workspaceURL.appendingPathComponent(".personakit/Packs/references"),
      workspaceURL.appendingPathComponent(".personakit/Packs/skills"),
      workspaceURL.appendingPathComponent(".personakit/Packs/essentials"),
      workspaceURL.appendingPathComponent(".personakit/Sessions"),
    ]
    .map(\.standardizedFileURL)

    #expect(state.createdDirectories == expectedDirectories)
  }

  @Test
  func loadWorkspaceDoesNotOfferInitializationForMalformedPacksPath() async throws {
    let workspaceURL = try makeTempDirectory()
    let personakitURL = workspaceURL.appendingPathComponent(".personakit")
    let packsURL = personakitURL.appendingPathComponent("Packs")

    try FileManager.default.createDirectory(
      at: personakitURL,
      withIntermediateDirectories: true
    )
    try Data("not a directory".utf8).write(to: packsURL, options: [.atomic])

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceSnapshotBuilder(globalScopeURL: nil),
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      }
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.loadErrorMessage == "PersonaKit reserved path Packs exists but is not a directory."
    }
    #expect(!store.canInitializeWorkspaceStructure)
  }

  @Test
  func installOrUpdateCLIStoresResultAndRefreshesStatus() throws {
    let homeDirectoryURL = try FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: FileManager.default.temporaryDirectory,
      create: true
    )
    let bundledCLIURL = homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI")
    let bundledSupportBundleURL = homeDirectoryURL.appendingPathComponent(
      "Bundle/PersonaKit_ContextCore.bundle"
    )
    let bundledSupportMarkerURL =
      bundledSupportBundleURL
      .appendingPathComponent("Contents/Resources/marker.txt")
    try FileManager.default.createDirectory(
      at: bundledCLIURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("bundled-cli".utf8).write(to: bundledCLIURL, options: [.atomic])
    try FileManager.default.createDirectory(
      at: bundledSupportMarkerURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("bundled-support".utf8).write(to: bundledSupportMarkerURL, options: [.atomic])
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: bundledCLIURL.path()
    )
    let store = WorkspaceStore(
      installEnvironment: WorkspaceStoreStubInstallEnvironment(
        rootHomeDirectoryURL: homeDirectoryURL,
        resolvedBundledCLIURL: bundledCLIURL,
        resolvedBundledCLISupportBundleURL: bundledSupportBundleURL
      )
    )

    store.installOrUpdateCLI()

    #expect(store.installResult?.outcome == .installed)
    #expect(
      store.installStatus.installedCLIURL?.path()
        == homeDirectoryURL.appendingPathComponent(".local/bin/personakit").path()
    )
    #expect(
      FileManager.default.fileExists(
        atPath: homeDirectoryURL.appendingPathComponent(
          ".local/bin/PersonaKit_ContextCore.bundle/Contents/Resources/marker.txt"
        )
        .path()
      )
    )
  }

  @Test
  func installOrUpdateOpenCodeMCPStoresResultAndRefreshesStatus() throws {
    let homeDirectoryURL = try FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: FileManager.default.temporaryDirectory,
      create: true
    )
    let bundledCLIURL = homeDirectoryURL.appendingPathComponent("Bundle/PersonaKitCLI")
    let bundledSupportBundleURL = homeDirectoryURL.appendingPathComponent(
      "Bundle/PersonaKit_ContextCore.bundle"
    )
    let bundledSupportMarkerURL =
      bundledSupportBundleURL
      .appendingPathComponent("Contents/Resources/marker.txt")
    try FileManager.default.createDirectory(
      at: bundledCLIURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("bundled-cli".utf8).write(to: bundledCLIURL, options: [.atomic])
    try FileManager.default.createDirectory(
      at: bundledSupportMarkerURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("bundled-support".utf8).write(to: bundledSupportMarkerURL, options: [.atomic])
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: bundledCLIURL.path()
    )
    let store = WorkspaceStore(
      installEnvironment: WorkspaceStoreStubInstallEnvironment(
        rootHomeDirectoryURL: homeDirectoryURL,
        resolvedBundledCLIURL: bundledCLIURL,
        resolvedBundledCLISupportBundleURL: bundledSupportBundleURL
      )
    )

    store.installOrUpdateOpenCodeMCP()

    #expect(store.installResult?.outcome == .installed)
    #expect(store.installStatus.openCodeMCPCommandPath == bundledCLIURL.path())
  }

  private func yieldTasks(_ iterations: Int = 50) async {
    for _ in 0..<iterations {
      await Task.yield()
    }
  }
}
