import ArgumentParser
import ContextCore
import Foundation

struct RecommendCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "recommend",
    abstract: "Recommend a session for a goal."
  )

  @OptionGroup
  var scope: ScopeOptions

  @Option(name: .customLong("goal"), help: "Goal or task description to match against sessions.")
  var goal: String

  @Option(name: .customLong("limit"), help: "Maximum recommendations to show (1-20).")
  var limit = 3

  mutating func validate() throws {
    let normalizedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalizedGoal.isEmpty else {
      throw ArgumentParser.ValidationError("recommend requires --goal <text>.")
    }

    guard (1...20).contains(limit) else {
      throw ArgumentParser.ValidationError("recommend requires --limit between 1 and 20.")
    }

    goal = normalizedGoal
  }

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)

    do {
      let sessions = try SessionFileLoader.list(scopes: scopes)

      guard !sessions.isEmpty else {
        throw CLIError.failure(
          "No session files found. Create at least one Sessions/*.session.json file in the active PersonaKit scope."
        )
      }

      let registry = try Registry.load(scopes: scopes)
      let result = SessionRecommendationSupport.recommend(
        goal: goal,
        sessions: sessions,
        registry: registry
      )

      if !result.invalidSessions.isEmpty {
        var stderrStream = StandardError()
        stderrStream.write(SessionRecommendationSupport.formatInvalidSessions(result.invalidSessions) + "\n")
        throw ExitCode.failure
      }

      let strongRecommendations = result.recommendations.filter { $0.score > 0 }

      if strongRecommendations.isEmpty {
        print(renderNoStrongMatch(result: result))
        return
      }

      let sessionsById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
      let selected = Array(strongRecommendations.prefix(limit))
      let output = try renderRecommendations(
        result: result,
        selected: selected,
        sessionsById: sessionsById,
        registry: registry,
        scopes: scopes
      )
      print(output)
    } catch let error as RegistryLoadError {
      var stderrStream = StandardError()
      for registryError in error.errors {
        stderrStream.write(CLIHelpers.formatRegistryError(registryError) + "\n")
      }
      throw ExitCode.failure
    } catch let error as ResolverResolutionError {
      var stderrStream = StandardError()
      for resolutionError in error.errors {
        stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
      }
      throw ExitCode.failure
    } catch let error as SessionFileError {
      var stderrStream = StandardError()
      stderrStream.write("Error: \(error.localizedDescription)\n")
      throw ExitCode.failure
    }
  }

  private func renderRecommendations(
    result: SessionRecommendationSupport.Result,
    selected: [SessionRecommendationSupport.Recommendation],
    sessionsById: [String: SessionFile],
    registry: Registry,
    scopes: ScopeSet
  ) throws -> String {
    var lines: [String] = [
      "Goal: \(result.goal)",
      "Goal terms: \(displayList(result.goalTerms))",
      "Considered sessions: \(displayList(result.consideredSessionIds))",
      "",
    ]

    for (index, recommendation) in selected.enumerated() {
      guard let session = sessionsById[recommendation.sessionId],
        let persona = registry.personasById[recommendation.personaId],
        let directive = registry.directivesById[recommendation.directiveId]
      else {
        continue
      }

      let contract = try SessionContractResolver.resolve(
        scopes: scopes,
        session: session
      )
      let authorizedSkills = contract.skillAuthorization.authorizedSkillIds
      let groundingSkillIds = contract.availableGroundingSkills.map(\.id).sorted()
      let kitIds = contract.kits.map(\.id).sorted()
      let stopPoints = directive.steps
        .filter { $0.requiresReview == true }
        .map(\.text)

      if index > 0 {
        lines.append("")
      }

      lines.append("\(index + 1). \(recommendation.sessionId)")
      lines.append("   persona: \(persona.name) (\(persona.id))")
      lines.append("   directive: \(directive.title) (\(directive.id))")
      lines.append("   kits: \(displayList(kitIds))")
      lines.append("   why: matched goal terms \(displayList(recommendation.matchedGoalTerms))")
      lines.append("   skills: \(displayList(authorizedSkills))")
      lines.append("   grounding skills: \(displayList(groundingSkillIds))")
      lines.append("   stop points: \(displayList(stopPoints))")
      lines.append("   next:")
      lines.append("     \(baseCommand(for: .contract)) --session \(recommendation.sessionId)")
      lines.append(
        "     \(baseCommand(for: .export)) --session \(recommendation.sessionId) --copy"
      )
    }

    return lines.joined(separator: "\n")
  }

  private func renderNoStrongMatch(
    result: SessionRecommendationSupport.Result
  ) -> String {
    [
      "Goal: \(result.goal)",
      "Goal terms: \(displayList(result.goalTerms))",
      "Considered sessions: \(displayList(result.consideredSessionIds))",
      "",
      "No strong session match found.",
      "PersonaKit may not be needed for this task.",
      "If the work spans multiple lanes, split it into one bounded lane first.",
      "Next:",
      "  \(baseCommand(for: .list)) sessions",
      "  \(baseCommand(for: .contract)) --session <id>",
    ].joined(separator: "\n")
  }

  private func displayList(_ items: [String]) -> String {
    guard !items.isEmpty else {
      return "none"
    }

    return items.joined(separator: ", ")
  }

  private func baseCommand(for subcommand: Subcommand) -> String {
    let command = ["personakit", subcommand.rawValue] + scopeArguments
    return command.joined(separator: " ")
  }

  private var scopeArguments: [String] {
    var args: [String] = []

    if let rootPath = scope.rootPath?.trimmingCharacters(in: .whitespacesAndNewlines), !rootPath.isEmpty {
      args.append("--root")
      args.append(shellQuoted(rootPath))
    }

    if scope.noProject {
      args.append("--no-project")
    }

    if scope.noGlobal {
      args.append("--no-global")
    }

    return args
  }

  private func shellQuoted(_ value: String) -> String {
    guard value.contains(where: { $0.isWhitespace }) || value.contains("\"") else {
      return value
    }

    let escaped =
      value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")

    return "\"\(escaped)\""
  }
}

private enum Subcommand: String {
  case contract
  case export
  case list
}
