import AppOpsCore
import Foundation
import PersonaKitCore

extension AppOpsCLI {
  private struct UserLoadResult {
    let sets: [PersonaSet]
    let diagnostics: [Diagnostic]
    let duration: Double
  }

  private struct ReloadMetricsInput {
    let builtIn: (sets: [PersonaSet], diagnostics: [Diagnostic])
    let builtInDuration: Double
    let userLoad: UserLoadResult
    let mergeResult: (personas: [String: Persona], diagnostics: [Diagnostic])
    let mergeDuration: Double
    let resolved: PersonaResolver.ResolutionResult
    let resolveDuration: Double
    let includeUserPacks: Bool
  }

  struct ReloadSnapshot {
    let builtInSets: [PersonaSet]
    let builtInDiagnostics: [Diagnostic]
    let userSets: [PersonaSet]
    let userDiagnostics: [Diagnostic]
    let mergeResult: (personas: [String: Persona], diagnostics: [Diagnostic])
    let resolved: PersonaResolver.ResolutionResult
    let metrics: ReloadMetrics
  }

  static func runReload(
    repoRoot: URL,
    builtInURLs: [URL],
    includeUserPacks: Bool,
    fileClient: FileClient
  ) throws -> ReloadSnapshot {
    let (builtIn, builtInDuration) = measure {
      loadBuiltInSets(urls: builtInURLs)
    }

    let userLoad = loadUserSetsIfNeeded(
      includeUserPacks: includeUserPacks,
      fileClient: fileClient
    )

    let combined = builtIn.sets + userLoad.sets
    let (mergeResult, mergeDuration) = measure {
      PersonaResolver.mergeSets(combined)
    }

    let (resolved, resolveDuration) = measure {
      PersonaResolver.resolveAll(from: mergeResult.personas)
    }

    let reloadMetrics = buildReloadMetrics(
      input: ReloadMetricsInput(
        builtIn: builtIn,
        builtInDuration: builtInDuration,
        userLoad: userLoad,
        mergeResult: mergeResult,
        mergeDuration: mergeDuration,
        resolved: resolved,
        resolveDuration: resolveDuration,
        includeUserPacks: includeUserPacks
      )
    )

    return ReloadSnapshot(
      builtInSets: builtIn.sets,
      builtInDiagnostics: builtIn.diagnostics,
      userSets: userLoad.sets,
      userDiagnostics: userLoad.diagnostics,
      mergeResult: mergeResult,
      resolved: resolved,
      metrics: reloadMetrics
    )
  }

  private static func loadBuiltInSets(
    urls: [URL]
  ) -> (sets: [PersonaSet], diagnostics: [Diagnostic]) {
    var sets: [PersonaSet] = []
    var diagnostics: [Diagnostic] = []
    for url in urls {
      switch PersonaLoader.loadDocument(from: url, sourceKind: .builtIn) {
      case .success(let set): sets.append(set)
      case .failure(let error): diagnostics.append(contentsOf: error.diagnostics)
      }
    }
    return (sets, diagnostics)
  }

  private static func loadUserSets(
    fileClient: FileClient
  ) -> (sets: [PersonaSet], diagnostics: [Diagnostic]) {
    let packsRoot = PersonaKitStoragePaths.standard(homeDirectory: fileClient.homeDirectory()).packs
    guard fileClient.fileExists(packsRoot) else {
      return ([], [])
    }
    let loaded = UserPackLoader.load(in: packsRoot, fileClient: fileClient)
    return (loaded.packs.map { $0.set }, loaded.diagnostics)
  }

  private static func loadUserSetsIfNeeded(
    includeUserPacks: Bool,
    fileClient: FileClient
  ) -> UserLoadResult {
    guard includeUserPacks else {
      return UserLoadResult(sets: [], diagnostics: [], duration: 0)
    }

    let (loaded, duration) = measure {
      loadUserSets(fileClient: fileClient)
    }
    return UserLoadResult(sets: loaded.sets, diagnostics: loaded.diagnostics, duration: duration)
  }

  private static func buildReloadMetrics(
    input: ReloadMetricsInput
  ) -> ReloadMetrics {
    let totalDiagnostics =
      input.builtIn.diagnostics.count
      + input.userLoad.diagnostics.count
      + input.mergeResult.diagnostics.count
      + input.resolved.diagnostics.count

    return ReloadMetrics(
      totalDurationSeconds:
        input.builtInDuration
        + input.userLoad.duration
        + input.mergeDuration
        + input.resolveDuration,
      builtIn: LoadMetrics(
        durationSeconds: input.builtInDuration,
        packCount: input.builtIn.sets.count,
        personaCount: input.builtIn.sets.reduce(0) { $0 + $1.personas.count },
        diagnosticsCount: input.builtIn.diagnostics.count
      ),
      userPacks: input.includeUserPacks
        ? LoadMetrics(
          durationSeconds: input.userLoad.duration,
          packCount: input.userLoad.sets.count,
          personaCount: input.userLoad.sets.reduce(0) { $0 + $1.personas.count },
          diagnosticsCount: input.userLoad.diagnostics.count
        )
        : nil,
      merge: MergeMetrics(
        durationSeconds: input.mergeDuration,
        personaCount: input.mergeResult.personas.count,
        diagnosticsCount: input.mergeResult.diagnostics.count
      ),
      resolve: ResolveMetrics(
        durationSeconds: input.resolveDuration,
        personaCount: input.resolved.personasByID.count,
        diagnosticsCount: input.resolved.diagnostics.count
      ),
      totalPacks: input.builtIn.sets.count + input.userLoad.sets.count,
      totalPersonas: input.mergeResult.personas.count,
      diagnosticsCount: totalDiagnostics
    )
  }
}
