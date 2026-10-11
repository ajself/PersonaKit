import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

/// Coverage for persisting and resolving the app-wide global-library grant (Tranche 4, S2).
@MainActor
struct StudioGlobalLibraryAccessTests {
  @Test
  func grantRoundTripsAcrossInstances() {
    let (defaults, suite) = makeEphemeralDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let url = URL(fileURLWithPath: "/Users/test/.personakit", isDirectory: true)
    let bookmark = Data("bookmark".utf8)

    // Session 1: the user grants a folder → persist + begin access.
    let writer = GlobalLibraryBookmarkRecorder()
    writer.bookmarkDataToReturn = bookmark
    let session1 = makeAccess(writer, defaults: defaults)
    #expect(session1.persist(grantedURL: url))
    #expect(writer.startedURLs == [url])

    // Session 2: a fresh instance over the same defaults resolves the same grant.
    let reader = GlobalLibraryBookmarkRecorder()
    reader.resolutionToReturn = StudioGlobalLibraryBookmarkResolution(url: url, isStale: false)
    let session2 = makeAccess(reader, defaults: defaults)
    #expect(session2.resolveGrantedURL() == url)
    #expect(reader.resolvedData == [bookmark])
    #expect(reader.startedURLs == [url])
  }

  @Test
  func staleBookmarkIsRePersistedOnResolve() {
    let (defaults, suite) = makeEphemeralDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let url = URL(fileURLWithPath: "/Users/test/.personakit", isDirectory: true)

    let writer = GlobalLibraryBookmarkRecorder()
    writer.bookmarkDataToReturn = Data("v1".utf8)
    makeAccess(writer, defaults: defaults)
      .persist(grantedURL: url)

    // Resolving a stale bookmark re-mints and re-persists a fresh one.
    let staleReader = GlobalLibraryBookmarkRecorder()
    staleReader.resolutionToReturn = StudioGlobalLibraryBookmarkResolution(url: url, isStale: true)
    staleReader.bookmarkDataToReturn = Data("v2".utf8)
    let staleAccess = makeAccess(staleReader, defaults: defaults)
    #expect(staleAccess.resolveGrantedURL() == url)
    #expect(staleReader.resolvedData == [Data("v1".utf8)])
    #expect(staleReader.bookmarkedURLs == [url])

    // The refreshed bookmark (v2) is what a later resolve reads back.
    let laterReader = GlobalLibraryBookmarkRecorder()
    laterReader.resolutionToReturn = StudioGlobalLibraryBookmarkResolution(url: url, isStale: false)
    makeAccess(laterReader, defaults: defaults)
      .resolveGrantedURL()
    #expect(laterReader.resolvedData == [Data("v2".utf8)])
  }

  @Test
  func reGrantStopsPreviousAccessBeforeStartingNewAndEndAccessReleases() {
    let (defaults, suite) = makeEphemeralDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let recorder = GlobalLibraryBookmarkRecorder()
    recorder.bookmarkDataToReturn = Data("bookmark".utf8)
    let access = makeAccess(recorder, defaults: defaults)

    let urlA = URL(fileURLWithPath: "/a/.personakit", isDirectory: true)
    let urlB = URL(fileURLWithPath: "/b/.personakit", isDirectory: true)
    access.persist(grantedURL: urlA)
    access.persist(grantedURL: urlB)

    // Re-granting releases the prior scope before starting the new one.
    #expect(recorder.startedURLs == [urlA, urlB])
    #expect(recorder.stoppedURLs == [urlA])

    access.endAccess()
    #expect(recorder.stoppedURLs == [urlA, urlB])
  }

  @Test
  func resolveWithoutGrantReturnsNilAndDoesNotBeginAccess() {
    let (defaults, suite) = makeEphemeralDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let recorder = GlobalLibraryBookmarkRecorder()
    let access = makeAccess(recorder, defaults: defaults)

    #expect(access.resolveGrantedURL() == nil)
    #expect(recorder.resolvedData.isEmpty)
    #expect(recorder.startedURLs.isEmpty)
  }

  @Test
  func launchConfiguredPrefersEnvironmentOverPersistedBookmark() {
    let (defaults, suite) = makeEphemeralDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    makeAccess(bookmarkWriter(returning: Data("bookmark".utf8)), defaults: defaults)
      .persist(grantedURL: URL(fileURLWithPath: "/bookmarked/.personakit", isDirectory: true))

    let reader = GlobalLibraryBookmarkRecorder()
    reader.resolutionToReturn = StudioGlobalLibraryBookmarkResolution(
      url: URL(fileURLWithPath: "/bookmarked/.personakit", isDirectory: true),
      isStale: false
    )
    let access = makeAccess(reader, defaults: defaults)

    let envURL = "/env/.personakit"
    let store = WorkspaceStore.launchConfigured(
      environment: [StudioLaunchConfiguration.globalScopePathEnvironmentKey: envURL],
      globalLibraryAccess: access
    )

    #expect(
      store.globalScopeProvider?.current()
        == URL(fileURLWithPath: envURL, isDirectory: true).standardizedFileURL
    )
    // The bookmark must not even be consulted when the environment override wins.
    #expect(reader.resolvedData.isEmpty)
  }

  @Test
  func launchConfiguredFallsBackToPersistedBookmarkWithoutEnvironment() {
    let (defaults, suite) = makeEphemeralDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let bookmarkedURL = URL(fileURLWithPath: "/bookmarked/.personakit", isDirectory: true)
    makeAccess(bookmarkWriter(returning: Data("bookmark".utf8)), defaults: defaults)
      .persist(grantedURL: bookmarkedURL)

    let reader = GlobalLibraryBookmarkRecorder()
    reader.resolutionToReturn = StudioGlobalLibraryBookmarkResolution(
      url: bookmarkedURL,
      isStale: false
    )
    let access = makeAccess(reader, defaults: defaults)

    let store = WorkspaceStore.launchConfigured(
      environment: [:],
      globalLibraryAccess: access
    )

    #expect(store.globalScopeProvider?.current() == bookmarkedURL.standardizedFileURL)
    #expect(reader.resolvedData == [Data("bookmark".utf8)])
  }

  private func bookmarkWriter(returning data: Data) -> GlobalLibraryBookmarkRecorder {
    let recorder = GlobalLibraryBookmarkRecorder()
    recorder.bookmarkDataToReturn = data
    return recorder
  }

  @Test
  func grantIsStoredUnderTheExistingDefaultsKey() {
    let (defaults, suite) = makeEphemeralDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let bookmark = Data("bookmark".utf8)

    makeAccess(bookmarkWriter(returning: bookmark), defaults: defaults)
      .persist(grantedURL: URL(fileURLWithPath: "/Users/test/.personakit", isDirectory: true))

    // Existing users' grants live under this key; renaming it would silently drop them.
    #expect(defaults.data(forKey: "studio.globalLibraryBookmark") == bookmark)
  }

  private func makeAccess(
    _ bookmarkClient: GlobalLibraryBookmarkRecorder,
    defaults: UserDefaults
  ) -> StudioGlobalLibraryAccess {
    StudioGlobalLibraryAccess(
      bookmarkClient: bookmarkClient,
      bookmarkStore: StudioGlobalLibraryBookmarkUserDefaultsStore(userDefaults: defaults)
    )
  }

  private func makeEphemeralDefaults() -> (UserDefaults, String) {
    let suite = "test.studio.globalLibrary.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (defaults, suite)
  }
}

private final class GlobalLibraryBookmarkRecorder: StudioGlobalLibraryBookmarking {
  var bookmarkDataToReturn: Data?
  var resolutionToReturn: StudioGlobalLibraryBookmarkResolution?
  var startAccessSucceeds = true
  private(set) var bookmarkedURLs: [URL] = []
  private(set) var resolvedData: [Data] = []
  private(set) var startedURLs: [URL] = []
  private(set) var stoppedURLs: [URL] = []

  func bookmarkData(for url: URL) -> Data? {
    bookmarkedURLs.append(url)
    return bookmarkDataToReturn
  }

  func resolve(_ bookmarkData: Data) -> StudioGlobalLibraryBookmarkResolution? {
    resolvedData.append(bookmarkData)
    return resolutionToReturn
  }

  func startAccessing(_ url: URL) -> Bool {
    startedURLs.append(url)
    return startAccessSucceeds
  }

  func stopAccessing(_ url: URL) {
    stoppedURLs.append(url)
  }
}
