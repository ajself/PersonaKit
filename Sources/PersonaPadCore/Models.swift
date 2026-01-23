import Foundation

// MARK: - Top-level documents

public struct PersonaDocumentEnvelope: Codable, Sendable {
  public let schemaVersion: Int
  public let documentType: DocumentType

  public let pack: PackMeta?
  public let defaults: PackDefaults?
  public let personas: [Persona]?

  public let persona: Persona?

  private let decodingErrors: [String]
  private let documentTypeIsValid: Bool

  public enum DocumentType: String, Codable, Sendable {
    case personaPack
    case persona
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case documentType
    case pack
    case defaults
    case personas
    case persona
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.schemaVersion = (try? container.decode(Int.self, forKey: .schemaVersion)) ?? 0

    let rawType = try? container.decode(String.self, forKey: .documentType)
    let decodedType = rawType.flatMap(DocumentType.init(rawValue:))
    self.documentType = decodedType ?? .persona
    self.documentTypeIsValid = decodedType != nil

    var errors: [String] = []
    if !documentTypeIsValid {
      if let rawType {
        errors.append("Unsupported documentType: \(rawType). Fix: set documentType to 'personaPack' or 'persona'.")
      } else {
        errors.append("Missing documentType. Fix: set documentType to 'personaPack' or 'persona'.")
      }
    }

    switch documentType {
    case .personaPack:
      let pack = try? container.decode(PackMeta.self, forKey: .pack)
      if container.contains(.pack), pack == nil {
        errors.append("Invalid 'pack' object. Fix: ensure 'pack' matches schema v1.")
      }
      let defaults = try? container.decode(PackDefaults.self, forKey: .defaults)
      if container.contains(.defaults), defaults == nil {
        errors.append("Invalid 'defaults' object. Fix: ensure 'defaults' matches schema v1.")
      }
      let personas = try? container.decode([Persona].self, forKey: .personas)
      if container.contains(.personas), personas == nil {
        errors.append("Invalid 'personas' array. Fix: ensure it is a JSON array of persona objects.")
      }

      self.pack = pack
      self.defaults = defaults
      self.personas = personas
      self.persona = nil

    case .persona:
      let persona = try? container.decode(Persona.self, forKey: .persona)
      if container.contains(.persona), persona == nil {
        errors.append("Invalid 'persona' object. Fix: ensure 'persona' matches schema v1.")
      }

      self.pack = nil
      self.defaults = nil
      self.personas = nil
      self.persona = persona
    }

    self.decodingErrors = errors
  }

  public func asResolvedSet(source: PersonaSource) -> Result<PersonaSet, DiagnosticError> {
    var diags: [Diagnostic] = decodingErrors.map { .error(source: source, message: $0) }
    if !documentTypeIsValid {
      return .failure(DiagnosticError(diags))
    }
    if schemaVersion != 1 {
      diags.append(.error(
        source: source,
        message: "Unsupported schemaVersion: \(schemaVersion). Fix: set schemaVersion to 1."
      ))
    }

    switch documentType {
    case .personaPack:
      guard let pack, let personas, !personas.isEmpty else {
        diags.append(.error(
          source: source,
          message: "personaPack requires 'pack' and non-empty 'personas'. Fix: add pack metadata and at least one persona."
        ))
        return .failure(DiagnosticError(diags))
      }
      let set = PersonaSet(source: source, pack: pack, defaults: defaults, personas: personas)
      diags.append(contentsOf: PersonaValidator.validate(set: set))
      return diags.contains(where: { $0.severity == .error }) ? .failure(DiagnosticError(diags)) : .success(set)

    case .persona:
      guard let persona else {
        diags.append(.error(
          source: source,
          message: "persona document requires 'persona'. Fix: provide a 'persona' object."
        ))
        return .failure(DiagnosticError(diags))
      }
      // Wrap single persona as a set for consistent merging.
      let pack = PackMeta(id: source.idFallback, name: source.displayNameFallback, author: nil, description: nil, homepage: nil)
      let set = PersonaSet(source: source, pack: pack, defaults: nil, personas: [persona])
      diags.append(contentsOf: PersonaValidator.validate(set: set))
      return diags.contains(where: { $0.severity == .error }) ? .failure(DiagnosticError(diags)) : .success(set)
    }
  }
}

// MARK: - Pack metadata

public struct PackMeta: Codable, Sendable, Hashable {
  public let id: String
  public let name: String
  public let author: String?
  public let description: String?
  public let homepage: String?
}

public struct PackDefaults: Codable, Sendable, Hashable {
  public enum OutputFormat: String, Codable, Sendable {
    case markdown, text, json
  }
  public let outputFormat: OutputFormat?
  public let modelHint: String?
}

// MARK: - Persona

public struct Persona: Codable, Sendable, Identifiable, Hashable {
  public let id: String
  public var name: String
  public var tags: [String]?
  public var description: String?

  /// Instruction block (system prompt-ish).
  public var system: String

  /// Optional composition.
  /// Unsupported in v1. Presence will trigger validation errors.
  public var extends: String?
  /// Unsupported in v1. Presence will trigger validation errors.
  public var systemAppend: String?

  public var template: PromptTemplate?
  public var outputContract: OutputContract?

  public init(
    id: String,
    name: String,
    tags: [String]? = nil,
    description: String? = nil,
    system: String,
    extends: String? = nil,
    systemAppend: String? = nil,
    template: PromptTemplate? = nil,
    outputContract: OutputContract? = nil
  ) {
    self.id = id
    self.name = name
    self.tags = tags
    self.description = description
    self.system = system
    self.extends = extends
    self.systemAppend = systemAppend
    self.template = template
    self.outputContract = outputContract
  }
}

public struct PromptTemplate: Codable, Sendable, Hashable {
  public var format: String?
  public var sections: [TemplateSection]?

  public init(format: String? = nil, sections: [TemplateSection]? = nil) {
    self.format = format
    self.sections = sections
  }
}

public struct TemplateSection: Codable, Sendable, Hashable {
  public var key: String
  public var label: String
  public var required: Bool
  public var placeholder: String?

  public init(key: String, label: String, required: Bool, placeholder: String? = nil) {
    self.key = key
    self.label = label
    self.required = required
    self.placeholder = placeholder
  }
}

public struct OutputContract: Codable, Sendable, Hashable {
  public var headings: [String]?
  public var askClarifyingQuestionsMax: Int?

  public init(headings: [String]? = nil, askClarifyingQuestionsMax: Int? = nil) {
    self.headings = headings
    self.askClarifyingQuestionsMax = askClarifyingQuestionsMax
  }
}
