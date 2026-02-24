import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

@MainActor
struct WorkspaceStoreSmokeTests {
  @Test
  func loadPublishesSnapshotBeforeValidationCompletes() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let expectedSnapshot = makeSnapshot(id: "project-persona")
    let expectedValidation = makeValidation(entityID: "project-persona")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        expectedSnapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        Thread.sleep(forTimeInterval: 0.3)

        return expectedValidation
      }
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.first?.id == "project-persona"
    }

    #expect(store.validation.summary == "Validating workspace...")
    #expect(store.validation.issues.isEmpty)

    await waitFor {
      store.validation.issues.first?.entityId == "project-persona"
    }
  }

  @Test
  func newerLoadResultWinsWhenLoadsOverlap() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { workspaceURL in
        if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
          Thread.sleep(forTimeInterval: 0.3)
          return makeSnapshot(id: "persona-a")
        }

        return makeSnapshot(id: "persona-b")
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(
          summary: "Validation summary: personas=0 kits=0 directives=0 intents=0 skills=0 essentials=0 errors=0",
          issues: []
        )
      }
    )

    store.workspaceURL = firstWorkspaceURL
    store.loadWorkspace()

    try? await Task.sleep(for: .milliseconds(20))

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.first?.id == "persona-b"
    }

    try? await Task.sleep(for: .milliseconds(350))

    #expect(store.snapshot.personas.first?.id == "persona-b")
  }

  @Test
  func newerValidationResultWinsWhenValidationsOverlap() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { workspaceURL in
        if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
          Thread.sleep(forTimeInterval: 0.3)
          return makeValidation(entityID: "persona-a")
        }

        return makeValidation(entityID: "persona-b")
      }
    )

    store.workspaceURL = firstWorkspaceURL
    store.validateWorkspace()

    try? await Task.sleep(for: .milliseconds(20))

    store.workspaceURL = secondWorkspaceURL
    store.validateWorkspace()

    await waitFor {
      store.validation.issues.first?.entityId == "persona-b"
    }

    try? await Task.sleep(for: .milliseconds(350))

    #expect(store.validation.issues.first?.entityId == "persona-b")
  }

  @Test
  func workspaceURLAssignmentStandardizesValue() {
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        .empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      }
    )

    store.workspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")

    #expect(store.workspaceURL?.path() == "/Workspace")
  }

  @Test
  func loadWorkspaceRestoresPreviewForSameSessionID() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")

    let firstSnapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a-first.session.json"
    )
    let secondSnapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a-second.session.json"
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { workspaceURL in
        if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
          return firstSnapshot
        }

        return secondSnapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
        loadPreviewHandler: { _, session in
          session.fileURL.lastPathComponent
        },
        exportPreviewHandler: { _, _ in }
      )
    )

    store.workspaceURL = firstWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.fileURL.lastPathComponent == "session-a-first.session.json"
    }

    store.refreshSessionPreview(for: store.snapshot.sessions.first)

    await waitFor {
      store.sessionPreview == "session-a-first.session.json"
    }

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.fileURL.lastPathComponent == "session-a-second.session.json"
    }

    await waitFor {
      store.sessionPreview == "session-a-second.session.json"
        && !store.isLoadingSessionPreview
    }
  }
}
