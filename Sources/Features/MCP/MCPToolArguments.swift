import Foundation
import MCP

/// Parsed and normalized session arguments for export/graph tool calls.
struct MCPToolArguments: Equatable {
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
  let targetPaths: [String]
  let referenceTags: [String]
}

struct MCPEntityArguments: Equatable {
  let entityType: MCPEntityType
  let id: String
}

struct MCPCompareArguments: Equatable {
  let entityType: MCPEntityType
  let leftId: String
  let rightId: String
}

struct MCPRecommendArguments: Equatable {
  let goal: String
  let limit: Int
}

struct MCPTraceArguments: Equatable {
  let sessionId: String
}

struct MCPContractArguments: Equatable {
  let sessionId: String?
  let personaId: String?
  let directiveId: String?
  let kitOverrides: [String]
  let requestedSkillIds: [String]
}

struct MCPResolveSessionArguments: Equatable {
  let sessionRef: String
}

/// Tool argument parsing failures returned as MCP invalid-params errors.
enum MCPToolArgumentError: Error, LocalizedError, Equatable {
  case missing(String)
  case invalidType(String)
  case invalidValue(String, String)

  var errorDescription: String? {
    switch self {
    case .missing(let name):
      return "Missing required argument: \(name)"
    case .invalidType(let name):
      if name == "kits" {
        return
          "Invalid argument type for \(name); expected array of strings or comma-separated string."
      }
      if name == "limit" {
        return "Invalid argument type for \(name); expected integer or numeric string."
      }
      return "Invalid argument type for \(name); expected string."
    case .invalidValue(let name, let message):
      return "Invalid value for \(name): \(message)"
    }
  }
}

/// Decoder for tool call arguments.
enum MCPToolArgumentParser {
  /// Parses and validates common session arguments for MCP tool calls.
  static func parseSession(_ arguments: [String: Value]?) throws -> MCPToolArguments {
    let personaId = try requireString(arguments, name: "personaId")
    let directiveId = try requireString(arguments, name: "directiveId")
    let kitOverrides = try parseKitOverrides(arguments?["kits"])
    let targetPaths = try parseStringList(arguments?["targetPaths"], fieldName: "targetPaths")
    let referenceTags = try parseStringList(
      arguments?["referenceTags"],
      fieldName: "referenceTags"
    )
    return MCPToolArguments(
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides,
      targetPaths: targetPaths,
      referenceTags: referenceTags
    )
  }

  static func parseEntity(_ arguments: [String: Value]?) throws -> MCPEntityArguments {
    let entityType = try parseEntityType(arguments, name: "entityType")
    let id = try requireString(arguments, name: "id")
    return MCPEntityArguments(entityType: entityType, id: id)
  }

  static func parseCompare(_ arguments: [String: Value]?) throws -> MCPCompareArguments {
    let entityType = try parseEntityType(arguments, name: "entityType")
    let leftId = try requireString(arguments, name: "leftId")
    let rightId = try requireString(arguments, name: "rightId")
    return MCPCompareArguments(entityType: entityType, leftId: leftId, rightId: rightId)
  }

  static func parseRecommend(_ arguments: [String: Value]?) throws -> MCPRecommendArguments {
    let goal = try requireString(arguments, name: "goal")
    let limit = try parseLimit(arguments?["limit"])
    return MCPRecommendArguments(goal: goal, limit: limit)
  }

  static func parseTrace(_ arguments: [String: Value]?) throws -> MCPTraceArguments {
    return MCPTraceArguments(sessionId: try requireString(arguments, name: "sessionId"))
  }

  static func parseResolveSession(_ arguments: [String: Value]?) throws -> MCPResolveSessionArguments {
    return MCPResolveSessionArguments(sessionRef: try requireString(arguments, name: "sessionRef"))
  }

  static func parseContract(_ arguments: [String: Value]?) throws -> MCPContractArguments {
    let sessionId = try parseOptionalString(arguments, name: "sessionId")
    let personaId = try parseOptionalString(arguments, name: "personaId")
    let directiveId = try parseOptionalString(arguments, name: "directiveId")
    let kitOverrides = try parseKitOverrides(arguments?["kits"])
    let requestedSkillIds = try parseRequestedSkillIds(arguments?["requestedSkillIds"])

    if sessionId != nil {
      if personaId != nil || directiveId != nil || !kitOverrides.isEmpty {
        throw MCPToolArgumentError.invalidValue(
          "sessionId",
          "cannot be combined with personaId, directiveId, or kits"
        )
      }
    } else {
      guard personaId != nil else {
        throw MCPToolArgumentError.missing("personaId")
      }

      if directiveId == nil && !kitOverrides.isEmpty {
        throw MCPToolArgumentError.invalidValue(
          "kits",
          "kits require directiveId when resolving a contract without sessionId"
        )
      }
    }

    return MCPContractArguments(
      sessionId: sessionId,
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides,
      requestedSkillIds: requestedSkillIds
    )
  }

  private static func requireString(_ arguments: [String: Value]?, name: String) throws -> String {
    guard let value = arguments?[name] else {
      throw MCPToolArgumentError.missing(name)
    }
    guard let stringValue = value.stringValue else {
      throw MCPToolArgumentError.invalidType(name)
    }
    let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw MCPToolArgumentError.missing(name)
    }
    return trimmed
  }

  private static func parseOptionalString(_ arguments: [String: Value]?, name: String) throws -> String? {
    guard let value = arguments?[name] else {
      return nil
    }

    guard let stringValue = value.stringValue else {
      throw MCPToolArgumentError.invalidType(name)
    }

    let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

    return trimmed.isEmpty ? nil : trimmed
  }

  private static func parseEntityType(_ arguments: [String: Value]?, name: String) throws -> MCPEntityType {
    let value = try requireString(arguments, name: name)
    guard let entityType = MCPEntityType(rawValue: value) else {
      throw MCPToolArgumentError.invalidValue(
        name,
        "expected one of: \(MCPEntityType.allCases.map(\.rawValue).joined(separator: ", "))"
      )
    }
    return entityType
  }

  private static func parseLimit(_ value: Value?) throws -> Int {
    guard let value else {
      return 3
    }

    let parsed: Int?
    if let intValue = value.intValue {
      parsed = intValue
    } else if let stringValue = value.stringValue {
      parsed = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    } else {
      parsed = nil
    }

    guard let parsed else {
      throw MCPToolArgumentError.invalidType("limit")
    }

    guard (1...20).contains(parsed) else {
      throw MCPToolArgumentError.invalidValue("limit", "must be between 1 and 20")
    }

    return parsed
  }

  private static func parseKitOverrides(_ value: Value?) throws -> [String] {
    guard let value else {
      return []
    }
    if let stringValue = value.stringValue {
      return parseKitList(stringValue)
    }
    if let arrayValue = value.arrayValue {
      var parsed: [String] = []
      var sawNonString = false
      for item in arrayValue {
        guard let stringValue = item.stringValue else {
          sawNonString = true
          continue
        }
        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          parsed.append(trimmed)
        }
      }
      if sawNonString {
        throw MCPToolArgumentError.invalidType("kits")
      }
      return parsed
    }
    throw MCPToolArgumentError.invalidType("kits")
  }

  private static func parseKitList(_ value: String) -> [String] {
    return
      value
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func parseRequestedSkillIds(_ value: Value?) throws -> [String] {
    try parseStringList(value, fieldName: "requestedSkillIds")
  }

  private static func parseStringList(_ value: Value?, fieldName: String) throws -> [String] {
    guard let value else {
      return []
    }

    if let stringValue = value.stringValue {
      return parseKitList(stringValue)
    }

    guard let arrayValue = value.arrayValue else {
      throw MCPToolArgumentError.invalidType(fieldName)
    }

    var parsed: [String] = []
    var sawNonString = false

    for item in arrayValue {
      guard let stringValue = item.stringValue else {
        sawNonString = true
        continue
      }

      let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        parsed.append(trimmed)
      }
    }

    if sawNonString {
      throw MCPToolArgumentError.invalidType(fieldName)
    }

    return parsed
  }
}
