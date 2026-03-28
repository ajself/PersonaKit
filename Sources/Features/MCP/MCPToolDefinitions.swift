import MCP

/// Supported tool names exposed by the PersonaKit MCP server.
enum MCPToolName: String, CaseIterable {
  case compareEntities = "personakit_compare_entities"
  case contract = "personakit_resolve_contract"
  case explainEntity = "personakit_explain_entity"
  case export = "personakit_export"
  case graph = "personakit_graph"
  case recommendSession = "personakit_recommend_session"
  case resolveSessionRef = "personakit_resolve_session_ref"
  case resolveReferences = "personakit_resolve_references"
  case traceSession = "personakit_trace_session"
  case validate = "personakit_validate"

  var description: String {
    switch self {
    case .compareEntities:
      return "Compare two PersonaKit entities of the same type and report deterministic differences."
    case .contract:
      return "Resolve the structured PersonaKit operating contract for a session or persona selection."
    case .explainEntity:
      return "Explain a PersonaKit entity with key fields and relationship edges."
    case .export:
      return "Assemble Persona+Kits+Directive into a single Markdown prompt."
    case .graph:
      return "Print a readable dependency graph for a session."
    case .recommendSession:
      return "Recommend sessions for a goal using deterministic ranking."
    case .resolveSessionRef:
      return "Resolve a session reference supplied as either a session id or a session-file path."
    case .resolveReferences:
      return "Resolve triggered references declared for a session using explicit target paths and request flags."
    case .traceSession:
      return "Trace a session into persona/directive/kits/intents/skills/essentials edges."
    case .validate:
      return "Validate PersonaKit packs and report errors."
    }
  }

  var inputSchema: Value {
    switch self {
    case .validate:
      return [
        "type": "object",
        "properties": Value.object([:]),
        "additionalProperties": false,
      ]
    case .contract:
      return [
        "type": "object",
        "properties": [
          "sessionId": [
            "type": "string",
            "description": "Optional session id to resolve.",
          ],
          "personaId": [
            "type": "string",
            "description": "Persona id.",
          ],
          "directiveId": [
            "type": "string",
            "description": "Optional directive id.",
          ],
          "kits": [
            "type": "array",
            "description": "Optional kit id overrides when directiveId is provided.",
            "items": [
              "type": "string"
            ],
          ],
          "requestedSkillIds": [
            "type": "array",
            "description": "Optional skill ids to verify against the resolved contract.",
            "items": [
              "type": "string"
            ],
          ],
        ],
        "additionalProperties": false,
      ]
    case .graph:
      let properties: Value = [
        "personaId": [
          "type": "string",
          "description": "Persona id",
        ],
        "directiveId": [
          "type": "string",
          "description": "Directive id",
        ],
        "kits": [
          "type": "array",
          "description": "Optional kit id overrides",
          "items": [
            "type": "string"
          ],
        ],
      ]
      return [
        "type": "object",
        "properties": properties,
        "required": ["personaId", "directiveId"],
        "additionalProperties": false,
      ]
    case .export, .resolveReferences:
      let properties: Value = [
        "personaId": [
          "type": "string",
          "description": "Persona id",
        ],
        "directiveId": [
          "type": "string",
          "description": "Directive id",
        ],
        "kits": [
          "type": "array",
          "description": "Optional kit id overrides",
          "items": [
            "type": "string"
          ],
        ],
        "targetPaths": [
          "type": "array",
          "description": "Optional target file paths used when evaluating references.",
          "items": [
            "type": "string"
          ],
        ],
        "flags": [
          "type": "array",
          "description": "Optional request flags used when evaluating references.",
          "items": [
            "type": "string"
          ],
        ],
      ]
      return [
        "type": "object",
        "properties": properties,
        "required": ["personaId", "directiveId"],
        "additionalProperties": false,
      ]
    case .explainEntity:
      return [
        "type": "object",
        "properties": [
          "entityType": [
            "type": "string",
            "enum": Value.array(MCPEntityType.allCases.map { .string($0.rawValue) }),
            "description": "Entity type to explain",
          ],
          "id": [
            "type": "string",
            "description": "Entity id",
          ],
        ],
        "required": ["entityType", "id"],
        "additionalProperties": false,
      ]
    case .compareEntities:
      return [
        "type": "object",
        "properties": [
          "entityType": [
            "type": "string",
            "enum": Value.array(MCPEntityType.allCases.map { .string($0.rawValue) }),
            "description": "Entity type shared by both inputs",
          ],
          "leftId": [
            "type": "string",
            "description": "Left entity id",
          ],
          "rightId": [
            "type": "string",
            "description": "Right entity id",
          ],
        ],
        "required": ["entityType", "leftId", "rightId"],
        "additionalProperties": false,
      ]
    case .recommendSession:
      return [
        "type": "object",
        "properties": [
          "goal": [
            "type": "string",
            "description": "Natural-language goal to match against session metadata",
          ],
          "limit": [
            "type": "integer",
            "description": "Optional max recommendations (1-20), default 3",
          ],
        ],
        "required": ["goal"],
        "additionalProperties": false,
      ]
    case .resolveSessionRef:
      return [
        "type": "object",
        "properties": [
          "sessionRef": [
            "type": "string",
            "description": "Session id or session-file path",
          ]
        ],
        "required": ["sessionRef"],
        "additionalProperties": false,
      ]
    case .traceSession:
      return [
        "type": "object",
        "properties": [
          "sessionId": [
            "type": "string",
            "description": "Session id",
          ]
        ],
        "required": ["sessionId"],
        "additionalProperties": false,
      ]
    }
  }

  var annotations: Tool.Annotations {
    return Tool.Annotations(
      readOnlyHint: true,
      openWorldHint: false
    )
  }
}

/// Supported explain/compare entity types.
enum MCPEntityType: String, CaseIterable {
  case persona
  case directive
  case kit
  case session
  case intent
  case reference
  case skill
  case essential
}
