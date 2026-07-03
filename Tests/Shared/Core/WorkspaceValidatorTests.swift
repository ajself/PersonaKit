import ContextWorkspaceCore
import Foundation
import Testing

@testable import ContextCore

/// Coverage for workspace validation mapping and project-root preconditions.
struct WorkspaceValidatorTests {
  @Test
  func validateMapsIssuesAndResolvesFilePaths() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")
    let globalScopeURL = URL(fileURLWithPath: "/Global/.personakit")
    let projectPersonaPath = "Packs/personas/senior-swiftui-engineer.persona.json"
    let globalKitPath = "Packs/kits/swift-style.kit.json"
    let ambiguousPath = "Packs/skills/shared-note.skill.json"
    let projectPersonaURL = projectScopeURL.appendingPathComponent(projectPersonaPath)
    let globalKitURL = globalScopeURL.appendingPathComponent(globalKitPath)
    let projectAmbiguousURL = projectScopeURL.appendingPathComponent(ambiguousPath)
    let globalAmbiguousURL = globalScopeURL.appendingPathComponent(ambiguousPath)
    let projectPacksURL = PersonaKitDirectory.packsURL(root: projectScopeURL)

    let dependencies = WorkspaceValidatorDependencies(
      directoryExists: { url in
        url.standardizedFileURL == projectPacksURL.standardizedFileURL
      },
      fileExists: { url in
        let normalizedURL = url.standardizedFileURL

        return normalizedURL == projectPersonaURL.standardizedFileURL
          || normalizedURL == globalKitURL.standardizedFileURL
          || normalizedURL == projectAmbiguousURL.standardizedFileURL
          || normalizedURL == globalAmbiguousURL.standardizedFileURL
      },
      defaultGlobalScopeURL: {
        globalScopeURL
      },
      validateScopes: { _ in
        ValidationResult(
          counts: ValidationCounts(
            personas: 1,
            kits: 1,
            directives: 0,
            skills: 0
          ),
          errors: [
            ValidationError(
              entityType: .persona,
              entityId: "senior-swiftui-engineer",
              field: "schema",
              missingId: nil,
              expectedPath: projectPersonaPath,
              message: "Missing required property \"id\""
            ),
            ValidationError(
              entityType: .kit,
              entityId: "swift-style",
              field: "skillIds",
              missingId: "swift-style-guide",
              expectedPath: globalKitPath,
              message: "Missing skill id"
            ),
            ValidationError(
              entityType: .skill,
              entityId: "shared-note",
              field: "schema",
              missingId: nil,
              expectedPath: ambiguousPath,
              message: "Ambiguous skill path"
            ),
          ]
        )
      }
    )

    let validator = WorkspaceValidator(
      globalScopeURL: globalScopeURL,
      dependencies: dependencies
    )
    let snapshot = try validator.validate(workspaceURL: workspaceURL)

    #expect(snapshot.summary.contains("errors=3"))
    #expect(snapshot.issues.count == 3)
    #expect(snapshot.issues[0].entityType == WorkspaceValidationEntityType.persona)
    #expect(snapshot.issues[0].filePath == projectPersonaURL.path())
    #expect(snapshot.issues[0].severity == WorkspaceValidationSeverity.error)
    #expect(snapshot.issues[1].entityType == WorkspaceValidationEntityType.kit)
    #expect(snapshot.issues[1].filePath == globalKitURL.path())
    #expect(snapshot.issues[2].entityType == WorkspaceValidationEntityType.skill)
    #expect(snapshot.issues[2].filePath == ambiguousPath)
  }

  @Test
  func validatePropagatesUnresolvedReferenceDiscriminator() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let projectPacksURL = PersonaKitDirectory.packsURL(
      root: workspaceURL.appendingPathComponent(".personakit")
    )

    let dependencies = WorkspaceValidatorDependencies(
      directoryExists: { url in
        url.standardizedFileURL == projectPacksURL.standardizedFileURL
      },
      fileExists: { _ in false },
      defaultGlobalScopeURL: { nil },
      validateScopes: { _ in
        ValidationResult(
          counts: .zero,
          errors: [
            ValidationError(
              entityType: .persona,
              entityId: "p",
              field: "defaultKitIds",
              missingId: "missing-kit",
              expectedPath: nil,
              message: "Missing kit id \"missing-kit\".",
              referencesUnresolvedID: true
            ),
            ValidationError(
              entityType: .persona,
              entityId: "p",
              field: "schema",
              missingId: nil,
              expectedPath: nil,
              message: "Malformed persona JSON."
            ),
          ]
        )
      }
    )

    let validator = WorkspaceValidator(globalScopeURL: nil, dependencies: dependencies)
    let snapshot = try validator.validate(workspaceURL: workspaceURL)

    let byField = Dictionary(
      uniqueKeysWithValues: snapshot.issues.map { ($0.field, $0.referencesUnresolvedID) }
    )
    #expect(byField["defaultKitIds"] == true)
    #expect(byField["schema"] == false)
  }

  @Test
  func validateFailsWhenProjectPersonaKitDirectoryIsMissing() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")

    let dependencies = WorkspaceValidatorDependencies(
      directoryExists: { _ in false },
      fileExists: { _ in false },
      defaultGlobalScopeURL: { nil },
      validateScopes: { _ in
        ValidationResult(counts: .zero, errors: [])
      }
    )

    let validator = WorkspaceValidator(
      globalScopeURL: nil,
      dependencies: dependencies
    )

    do {
      _ = try validator.validate(workspaceURL: workspaceURL)
      #expect(Bool(false))
    } catch let error as MissingPersonaKitDirectoryError {
      #expect(error.projectScopeURL.path().contains("/Workspace/.personakit"))
    }
  }
}
