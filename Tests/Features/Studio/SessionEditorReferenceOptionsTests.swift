import Testing

@testable import StudioFeatures

struct SessionEditorReferenceOptionsTests {
  @Test
  func loadedIDIsSelectedWithNoUnloadedOption() {
    let options = SessionEditorReferenceOptions(requestedID: "b", loadedIDs: ["a", "b"])

    #expect(options.initialSelection == "b")
    #expect(options.unloadedID == nil)
  }

  @Test
  func unloadedIDStaysSelectedInsteadOfFallingBackToFirst() {
    let options = SessionEditorReferenceOptions(requestedID: "missing", loadedIDs: ["a", "b"])

    #expect(options.initialSelection == "missing")
    #expect(options.unloadedID == "missing")
    #expect(!options.isLoaded("missing"))
    #expect(SessionEditorReferenceOptions.unloadedTitle(for: "missing") == "missing (not loaded)")
  }

  @Test
  func newSessionStartsOnFirstLoadedID() {
    let options = SessionEditorReferenceOptions(requestedID: "", loadedIDs: ["a", "b"])

    #expect(options.initialSelection == "a")
    #expect(options.unloadedID == nil)
  }
}
