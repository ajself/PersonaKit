import PersonaKitCore
import Testing

struct WorkspaceEntityIDPolicyTests {
  @Test
  func validIDPassesPolicy() {
    #expect(WorkspaceEntityIDPolicy.isValid("persona-kit_1.0"))
  }

  @Test
  func unsafeIDsFailPolicy() {
    #expect(!WorkspaceEntityIDPolicy.isValid(""))
    #expect(!WorkspaceEntityIDPolicy.isValid(".hidden"))
    #expect(!WorkspaceEntityIDPolicy.isValid("../escape"))
    #expect(!WorkspaceEntityIDPolicy.isValid("contains space"))
  }

  @Test
  func normalizationTrimsWhitespace() {
    #expect(WorkspaceEntityIDPolicy.normalized("  persona-a \n") == "persona-a")
  }
}
