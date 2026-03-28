import ContextCore
import MCP

extension MCPToolService {
  func validateTool(arguments: [String: Value]?) throws -> String {
    if let arguments, !arguments.isEmpty {
      throw MCPError.invalidParams(
        MCPInternalSupport.withRecoveryHint(
          "personakit_validate does not accept arguments.",
          hint: "Call personakit_validate with an empty argument object."
        )
      )
    }
    let result = try Validator.validate(scopes: scopes)
    let payload = MCPToolPayloads.ValidationToolOutput(result: result)
    return try MCPInternalSupport.encodeToolJSON(payload)
  }

  func exportTool(input: MCPToolArguments) throws -> String {
    do {
      return try MCPInternalSupport.exportOutput(
        scopes: scopes,
        personaId: input.personaId,
        directiveId: input.directiveId,
        kitOverrides: input.kitOverrides,
        targetPaths: input.targetPaths,
        requestFlags: input.requestFlags
      )
    } catch let error as ExportError {
      throw MCPError.invalidParams(MCPInternalSupport.formatExportError(error))
    }
  }

  func resolveReferencesTool(input: MCPToolArguments) throws -> String {
    do {
      let result = try WorkflowReferenceResolver.resolve(
        scopes: scopes,
        personaId: input.personaId,
        directiveId: input.directiveId,
        kitOverrides: input.kitOverrides,
        input: ReferenceSelectionInput(
          targetPaths: input.targetPaths,
          requestFlags: input.requestFlags
        )
      )
      return try MCPInternalSupport.encodeToolJSON(result)
    } catch let error as ReferenceLookupError {
      switch error {
      case .validationFailed(let result):
        let lines = [result.summary] + result.errors.map { $0.lineDescription() }
        throw MCPError.invalidParams(lines.joined(separator: "\n"))
      case .resolutionFailed(let resolutionError):
        throw MCPError.invalidParams(MCPInternalSupport.formatResolutionErrors(resolutionError.errors))
      case .referenceResolutionFailed(let resolutionError):
        throw MCPError.invalidParams("Error: \(resolutionError.message)")
      }
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

      return try MCPInternalSupport.encodeToolJSON(SessionContractResolver.snapshot(from: result))
    } catch let error as ResolverResolutionError {
      throw MCPError.invalidParams(MCPInternalSupport.formatResolutionErrors(error.errors))
    }
  }

  func graphTool(input: MCPToolArguments) throws -> String {
    do {
      return try MCPInternalSupport.graphOutput(
        scopes: scopes,
        personaId: input.personaId,
        directiveId: input.directiveId,
        kitOverrides: input.kitOverrides
      )
    } catch let error as RegistryLoadError {
      throw MCPError.invalidParams(MCPInternalSupport.formatRegistryErrors(error.errors))
    } catch let error as ResolverResolutionError {
      throw MCPError.invalidParams(MCPInternalSupport.formatResolutionErrors(error.errors))
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
        MCPInternalSupport.withRecoveryHint(
          error.localizedDescription,
          hint:
            "Use a valid session id from personakit://catalog/sessions or a path under Sessions/*.session.json in the active PersonaKit scope."
        )
      )
    } catch let error as SessionFileError {
      throw MCPError.invalidParams(
        MCPInternalSupport.withRecoveryHint(
          error.localizedDescription,
          hint:
            "Use a valid session id from personakit://catalog/sessions or a session-file path under the active PersonaKit scope."
        )
      )
    }

    return try MCPInternalSupport.encodeToolJSON(
      MCPToolPayloads.SessionReferenceResolutionPayload(
        inputRef: input.sessionRef,
        sourceRefType: resolved.sourceRefType.rawValue,
        normalizedSessionId: resolved.sessionId,
        resolvedPath: resolved.resolvedPath,
        scopeRootPath: resolved.scopeRootPath,
        personaId: resolved.session.personaId,
        directiveId: resolved.session.directiveId,
        kitOverrides: MCPInternalSupport.uniqueSorted(resolved.session.kitOverrides ?? [])
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
      throw MCPError.invalidParams(MCPInternalSupport.formatResolutionErrors(error.errors))
    }

    let appliedKits = resolved.kits.sorted { $0.id < $1.id }
    let kitToEssentials = appliedKits.map {
      MCPToolPayloads.SessionTraceEdgeMap(
        sourceId: $0.id,
        targetIds: MCPInternalSupport.uniqueSorted($0.essentialIds)
      )
    }
    let kitToIntents = appliedKits.map {
      MCPToolPayloads.SessionTraceEdgeMap(
        sourceId: $0.id,
        targetIds: MCPInternalSupport.uniqueSorted($0.intentTemplateIds ?? [])
      )
    }
    let kitToSkills = appliedKits.map {
      MCPToolPayloads.SessionTraceEdgeMap(
        sourceId: $0.id,
        targetIds: MCPInternalSupport.uniqueSorted($0.skillIds ?? [])
      )
    }
    let kitToReferences = appliedKits.map {
      MCPToolPayloads.SessionTraceEdgeMap(
        sourceId: $0.id,
        targetIds: MCPInternalSupport.uniqueSorted($0.referenceIds ?? [])
      )
    }
    let intentToEssentials = resolved.intents
      .sorted { $0.id < $1.id }
      .map {
        MCPToolPayloads.SessionTraceEdgeMap(
          sourceId: $0.id,
          targetIds: MCPInternalSupport.uniqueSorted($0.includesEssentialIds)
        )
      }
    let intentToReferences = resolved.intents
      .sorted { $0.id < $1.id }
      .map {
        MCPToolPayloads.SessionTraceEdgeMap(
          sourceId: $0.id,
          targetIds: MCPInternalSupport.uniqueSorted($0.referenceIds ?? [])
        )
      }
    let intentToSkills = resolved.intents
      .sorted { $0.id < $1.id }
      .map {
        MCPToolPayloads.SessionTraceEdgeMap(
          sourceId: $0.id,
          targetIds: MCPInternalSupport.uniqueSorted($0.requiresSkillIds)
        )
      }
    let systemEssentialIds = resolved.essentials
      .filter { $0.source == .systemBuiltIn }
      .map(\.id)

    return try MCPInternalSupport.encodeToolJSON(
      MCPToolPayloads.SessionTracePayload(
        session: MCPToolPayloads.SessionTraceSession(
          id: session.id,
          personaId: session.personaId,
          directiveId: session.directiveId,
          kitOverrides: MCPInternalSupport.uniqueSorted(session.kitOverrides ?? [])
        ),
        resolved: MCPToolPayloads.SessionTraceResolved(
          personaId: resolved.persona.id,
          directiveId: resolved.directive.id,
          kitIds: resolved.kits.map(\.id).sorted(),
          essentialIds: resolved.essentials.map(\.id),
          availableReferenceIds: resolved.availableReferences.map(\.id).sorted(),
          intentIds: resolved.intents.map(\.id).sorted(),
          skillIds: resolved.skills.map(\.id).sorted(),
          skillAuthorization: MCPToolPayloads.SessionTraceSkillAuthorization(
            allowedSkillIds: resolved.skillAuthorization.allowedSkillIds,
            forbiddenSkillIds: resolved.skillAuthorization.forbiddenSkillIds,
            authorizedSkillIds: resolved.skillAuthorization.authorizedSkillIds,
            requiredSkillIds: resolved.skillAuthorization.requiredSkillIds,
            unauthorizedRequiredSkillIds: resolved.skillAuthorization.unauthorizedRequiredSkillIds,
            isAuthorized: resolved.skillAuthorization.isAuthorized
          )
        ),
        edges: MCPToolPayloads.SessionTraceEdges(
          personaDefaultKitIds: MCPInternalSupport.uniqueSorted(resolved.persona.defaultKitIds),
          sessionKitOverrideIds: MCPInternalSupport.uniqueSorted(session.kitOverrides ?? []),
          directiveIntentIds: MCPInternalSupport.uniqueSorted(resolved.directive.requiresIntentTemplateIds),
          directiveReferenceIds: MCPInternalSupport.uniqueSorted(resolved.directive.referenceIds ?? []),
          directiveSkillIds: MCPInternalSupport.uniqueSorted(resolved.directive.requiresSkillIds),
          kitToEssentials: kitToEssentials,
          kitToReferences: kitToReferences,
          kitToIntents: kitToIntents,
          kitToSkills: kitToSkills,
          intentToEssentials: intentToEssentials,
          intentToReferences: intentToReferences,
          intentToSkills: intentToSkills,
          systemEssentialIds: systemEssentialIds
        ),
        workstream: resolved.directive.workstream.map {
          MCPInternalSupport.sessionTraceWorkstream(
            $0,
            activeSessionId: session.id
          )
        }
      )
    )
  }
}
