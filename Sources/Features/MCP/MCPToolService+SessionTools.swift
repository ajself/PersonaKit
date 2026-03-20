import ContextCore
import MCP

extension MCPToolService {
  func validateTool(arguments: [String: Value]?) throws -> String {
    if let arguments, !arguments.isEmpty {
      throw MCPError.invalidParams(
        mcpWithRecoveryHint(
          "personakit_validate does not accept arguments.",
          hint: "Call personakit_validate with an empty argument object."
        )
      )
    }
    let result = try Validator.validate(scopes: scopes)
    let payload = ValidationToolOutput(result: result)
    return try mcpEncodeToolJSON(payload)
  }

  func exportTool(input: MCPToolArguments) throws -> String {
    do {
      let output = try SessionExporter.export(
        scopes: scopes,
        personaId: input.personaId,
        directiveId: input.directiveId,
        kitOverrides: input.kitOverrides
      )
      return output + "\n"
    } catch let error as ExportError {
      throw MCPError.invalidParams(mcpFormatExportError(error))
    }
  }

  func contractTool(input: MCPContractArguments) throws -> String {
    do {
      let result: SessionContractResult

      if let sessionId = input.sessionId {
        let session = try loadSession(id: sessionId)
        result = try SessionContractResolver.resolve(
          scopes: scopes,
          session: session,
          requestedSkillIds: input.requestedSkillIds
        )
      } else {
        result = try SessionContractResolver.resolve(
          scopes: scopes,
          personaId: input.personaId ?? "",
          directiveId: input.directiveId,
          kitOverrides: input.directiveId == nil ? [] : input.kitOverrides,
          requestedSkillIds: input.requestedSkillIds
        )
      }

      return try mcpEncodeToolJSON(SessionContractResolver.snapshot(from: result))
    } catch let error as ResolverResolutionError {
      throw MCPError.invalidParams(mcpFormatResolutionErrors(error.errors))
    }
  }

  func graphTool(input: MCPToolArguments) throws -> String {
    do {
      let registry = try Registry.load(scopes: scopes)
      let definition = SessionDefinition(
        personaId: input.personaId,
        directiveId: input.directiveId,
        kitOverrides: input.kitOverrides.isEmpty ? nil : input.kitOverrides
      )
      let resolved = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes
      )
      let output = GraphPrinter.render(
        resolvedSession: resolved,
        kitOverrides: input.kitOverrides
      )
      return output + "\n"
    } catch let error as RegistryLoadError {
      throw MCPError.invalidParams(mcpFormatRegistryErrors(error.errors))
    } catch let error as ResolverResolutionError {
      throw MCPError.invalidParams(mcpFormatResolutionErrors(error.errors))
    }
  }

  func resolveSessionRefTool(input: MCPResolveSessionArguments) throws -> String {
    let resolved: ResolvedSessionReference
    do {
      resolved = try SessionReferenceResolver.resolve(
        scopes: scopes,
        sessionRef: input.sessionRef
      )
    } catch let error as SessionReferenceError {
      throw MCPError.invalidParams(
        mcpWithRecoveryHint(
          error.localizedDescription,
          hint:
            "Use a valid session id from personakit://catalog/sessions or a path under Sessions/*.session.json in the active PersonaKit scope."
        )
      )
    } catch let error as SessionFileError {
      throw MCPError.invalidParams(
        mcpWithRecoveryHint(
          error.localizedDescription,
          hint:
            "Use a valid session id from personakit://catalog/sessions or a session-file path under the active PersonaKit scope."
        )
      )
    }

    return try mcpEncodeToolJSON(
      SessionReferenceResolutionPayload(
        inputRef: input.sessionRef,
        sourceRefType: resolved.sourceRefType.rawValue,
        normalizedSessionId: resolved.sessionId,
        resolvedPath: resolved.resolvedPath,
        scopeRootPath: resolved.scopeRootPath,
        personaId: resolved.session.personaId,
        directiveId: resolved.session.directiveId,
        kitOverrides: mcpUniqueSorted(resolved.session.kitOverrides ?? [])
      )
    )
  }

  func traceSessionTool(input: MCPTraceArguments) throws -> String {
    let session = try loadSession(id: input.sessionId)
    let registry = try loadRegistry()

    let definition = SessionDefinition(
      personaId: session.personaId,
      directiveId: session.directiveId,
      kitOverrides: (session.kitOverrides ?? []).isEmpty ? nil : session.kitOverrides
    )

    let resolved: ResolvedSession
    do {
      resolved = try Resolver.resolve(
        definition: definition,
        registry: registry,
        scopes: scopes
      )
    } catch let error as ResolverResolutionError {
      throw MCPError.invalidParams(mcpFormatResolutionErrors(error.errors))
    }

    let appliedKits = resolved.kits.sorted { $0.id < $1.id }
    let kitToEssentials = appliedKits.map {
      SessionTraceEdgeMap(sourceId: $0.id, targetIds: mcpUniqueSorted($0.essentialIds))
    }
    let kitToIntents = appliedKits.map {
      SessionTraceEdgeMap(sourceId: $0.id, targetIds: mcpUniqueSorted($0.intentTemplateIds ?? []))
    }
    let kitToSkills = appliedKits.map {
      SessionTraceEdgeMap(sourceId: $0.id, targetIds: mcpUniqueSorted($0.skillIds ?? []))
    }
    let intentToEssentials = resolved.intents
      .sorted { $0.id < $1.id }
      .map {
        SessionTraceEdgeMap(sourceId: $0.id, targetIds: mcpUniqueSorted($0.includesEssentialIds))
      }
    let intentToSkills = resolved.intents
      .sorted { $0.id < $1.id }
      .map {
        SessionTraceEdgeMap(sourceId: $0.id, targetIds: mcpUniqueSorted($0.requiresSkillIds))
      }
    let systemEssentialIds = resolved.essentials
      .filter { $0.source == .systemBuiltIn }
      .map(\.id)

    return try mcpEncodeToolJSON(
      SessionTracePayload(
        session: SessionTraceSession(
          id: session.id,
          personaId: session.personaId,
          directiveId: session.directiveId,
          kitOverrides: mcpUniqueSorted(session.kitOverrides ?? [])
        ),
        resolved: SessionTraceResolved(
          personaId: resolved.persona.id,
          directiveId: resolved.directive.id,
          kitIds: resolved.kits.map(\.id).sorted(),
          essentialIds: resolved.essentials.map(\.id),
          intentIds: resolved.intents.map(\.id).sorted(),
          skillIds: resolved.skills.map(\.id).sorted(),
          skillAuthorization: SessionTraceSkillAuthorization(
            allowedSkillIds: resolved.skillAuthorization.allowedSkillIds,
            forbiddenSkillIds: resolved.skillAuthorization.forbiddenSkillIds,
            authorizedSkillIds: resolved.skillAuthorization.authorizedSkillIds,
            requiredSkillIds: resolved.skillAuthorization.requiredSkillIds,
            unauthorizedRequiredSkillIds: resolved.skillAuthorization.unauthorizedRequiredSkillIds,
            isAuthorized: resolved.skillAuthorization.isAuthorized
          )
        ),
        edges: SessionTraceEdges(
          personaDefaultKitIds: mcpUniqueSorted(resolved.persona.defaultKitIds),
          sessionKitOverrideIds: mcpUniqueSorted(session.kitOverrides ?? []),
          directiveIntentIds: mcpUniqueSorted(resolved.directive.requiresIntentTemplateIds),
          directiveSkillIds: mcpUniqueSorted(resolved.directive.requiresSkillIds),
          kitToEssentials: kitToEssentials,
          kitToIntents: kitToIntents,
          kitToSkills: kitToSkills,
          intentToEssentials: intentToEssentials,
          intentToSkills: intentToSkills,
          systemEssentialIds: systemEssentialIds
        ),
        workstream: resolved.directive.workstream.map {
          mcpSessionTraceWorkstream(
            $0,
            activeSessionId: session.id
          )
        }
      )
    )
  }
}
