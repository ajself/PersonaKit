import Foundation
import PersonaKitCore

extension PersonaKitSchemaValidate {
  /// Validates a single JSON file against the schema-derived constraints.
  ///
  /// - Parameters:
  ///   - url: File URL to validate.
  ///   - config: Derived schema constraints.
  ///   - fileClient: File system dependency.
  /// - Returns: An error message if validation fails, otherwise `nil`.
  static func validateFile(
    _ url: URL,
    config: SchemaConfig,
    fileClient: FileClient
  ) -> String? {
    guard let data = try? fileClient.readData(url) else {
      return "\(url.lastPathComponent): could not read file."
    }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return "\(url.lastPathComponent): invalid JSON."
    }

    let topLevel = validateTopLevel(json: json, config: config, fileName: url.lastPathComponent)
    guard let documentType = topLevel.documentType else {
      return topLevel.message
    }

    if documentType == "personaPack" {
      if let message = validatePersonaPack(
        json: json,
        config: config,
        fileName: url.lastPathComponent
      ) {
        return message
      }
    } else {
      if let message = validatePersonaDocument(
        json: json,
        config: config,
        fileName: url.lastPathComponent
      ) {
        return message
      }
    }

    return nil
  }

  /// Validates top-level schema properties and extracts the document type.
  private static func validateTopLevel(
    json: [String: Any],
    config: SchemaConfig,
    fileName: String
  ) -> (documentType: String?, message: String?) {
    let requiredTop = ["schemaVersion", "documentType"]
    for key in requiredTop where json[key] == nil {
      return (nil, "\(fileName): missing '\(key)'.")
    }

    guard let schemaVersion = json["schemaVersion"] as? Int, schemaVersion >= 1 else {
      return (nil, "\(fileName): schemaVersion must be >= 1.")
    }
    guard let documentType = json["documentType"] as? String,
      config.documentTypes.contains(documentType)
    else {
      return (
        nil,
        "\(fileName): documentType must be one of \(config.documentTypes.sorted())."
      )
    }

    return (documentType, nil)
  }

  /// Validates a `personaPack` document structure.
  private static func validatePersonaPack(
    json: [String: Any],
    config: SchemaConfig,
    fileName: String
  ) -> String? {
    for key in config.personaPackRequired where json[key] == nil {
      return "\(fileName): missing '\(key)' for personaPack."
    }
    guard let pack = json["pack"] as? [String: Any] else {
      return "\(fileName): pack must be an object."
    }
    if let message = validatePackFields(pack, config: config, fileName: fileName) {
      return message
    }
    if let message = validateDefaults(json: json, config: config, fileName: fileName) {
      return message
    }
    guard let personas = json["personas"] as? [Any], !personas.isEmpty else {
      return "\(fileName): personas must be a non-empty array."
    }
    for (idx, item) in personas.enumerated() {
      if let message = validatePersonaObject(item, config: config) {
        return "\(fileName): personas[\(idx)]: \(message)"
      }
    }
    return nil
  }

  /// Validates required fields under the `pack` object.
  private static func validatePackFields(
    _ pack: [String: Any],
    config: SchemaConfig,
    fileName: String
  ) -> String? {
    for key in config.packRequired {
      guard let value = pack[key] as? String,
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        return "\(fileName): pack.\(key) must be a non-empty string."
      }
    }
    return nil
  }

  /// Validates `defaults` values against schema constraints.
  private static func validateDefaults(
    json: [String: Any],
    config: SchemaConfig,
    fileName: String
  ) -> String? {
    let outputFormat = (json["defaults"] as? [String: Any])?["outputFormat"] as? String
    if let outputFormat, !config.outputFormats.contains(outputFormat) {
      return "\(fileName): defaults.outputFormat must be one of \(config.outputFormats.sorted())."
    }
    return nil
  }

  /// Validates a `persona` document structure.
  private static func validatePersonaDocument(
    json: [String: Any],
    config: SchemaConfig,
    fileName: String
  ) -> String? {
    guard let persona = json["persona"] else {
      return "\(fileName): missing 'persona' for persona."
    }
    if let message = validatePersonaObject(persona, config: config) {
      return "\(fileName): persona: \(message)"
    }
    return nil
  }

  /// Validates a persona object shared by persona documents and persona packs.
  private static func validatePersonaObject(_ value: Any, config: SchemaConfig) -> String? {
    guard let persona = value as? [String: Any] else {
      return "must be an object."
    }
    if let message = validatePersonaExtensions(persona) {
      return message
    }
    if let message = validatePersonaRequiredFields(persona, config: config) {
      return message
    }
    if let message = validateOptionalTemplate(persona) {
      return message
    }
    if let message = validateOptionalOutputContract(persona) {
      return message
    }

    return nil
  }

  /// Rejects unsupported extension fields in schema v1.
  private static func validatePersonaExtensions(_ persona: [String: Any]) -> String? {
    if persona["extends"] != nil {
      return "'extends' is not supported in v1."
    }
    if persona["systemAppend"] != nil {
      return "'systemAppend' is not supported in v1."
    }
    return nil
  }

  /// Validates required persona fields are non-empty strings.
  private static func validatePersonaRequiredFields(
    _ persona: [String: Any],
    config: SchemaConfig
  ) -> String? {
    for key in config.personaRequired {
      guard let raw = persona[key] else { return "missing '\(key)'." }
      if let str = raw as? String {
        if str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          return "'\(key)' must be a non-empty string."
        }
      } else {
        return "'\(key)' must be a string."
      }
    }
    return nil
  }

  /// Validates an optional `template` object if present.
  private static func validateOptionalTemplate(_ persona: [String: Any]) -> String? {
    guard let template = persona["template"] else { return nil }
    return validateTemplate(template)
  }

  /// Validates an optional `outputContract` object if present.
  private static func validateOptionalOutputContract(_ persona: [String: Any]) -> String? {
    guard let contract = persona["outputContract"] as? [String: Any] else { return nil }
    return validateOutputContract(contract)
  }

  /// Validates template sections for required keys and value types.
  private static func validateTemplate(_ template: Any) -> String? {
    guard let templateObj = template as? [String: Any] else {
      return "template must be an object."
    }
    if let sections = templateObj["sections"] as? [Any] {
      for (idx, section) in sections.enumerated() {
        guard let sectionObj = section as? [String: Any] else {
          return "template.sections[\(idx)] must be an object."
        }
        for key in ["key", "label", "required"] where sectionObj[key] == nil {
          return "template.sections[\(idx)] missing '\(key)'."
        }
        if let keyStr = sectionObj["key"] as? String, keyStr.isEmpty {
          return "template.sections[\(idx)].key must be non-empty."
        }
        if let labelStr = sectionObj["label"] as? String, labelStr.isEmpty {
          return "template.sections[\(idx)].label must be non-empty."
        }
        if (sectionObj["required"] as? Bool) == nil {
          return "template.sections[\(idx)].required must be boolean."
        }
      }
    }
    return nil
  }

  /// Validates output contract headings and numeric constraints.
  private static func validateOutputContract(_ contract: [String: Any]) -> String? {
    if let headings = contract["headings"] as? [Any] {
      for (idx, heading) in headings.enumerated() where (heading as? String) == nil {
        return "outputContract.headings[\(idx)] must be a string."
      }
    }
    if let max = contract["askClarifyingQuestionsMax"] {
      guard let intVal = max as? Int, intVal >= 0 else {
        return "outputContract.askClarifyingQuestionsMax must be an integer >= 0."
      }
    }
    return nil
  }
}
