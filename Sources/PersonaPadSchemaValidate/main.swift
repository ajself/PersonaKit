import Dependencies
import Foundation
import PersonaPadCore

struct SchemaConfig {
  let documentTypes: Set<String>
  let packRequired: [String]
  let personaRequired: [String]
  let personaPackRequired: [String]
  let outputFormats: Set<String>
}

@main
struct PersonaPadSchemaValidate {
  static func main() {
    let fileClient = SchemaEnvironment().fileClient
    let cwd = URL(fileURLWithPath: fileClient.currentDirectoryPath())
    guard let repoRoot = findRepoRoot(start: cwd, fileClient: fileClient) else {
      fputs("Schema validation failed: could not locate Schema/personapad.schema.json.\n", stderr)
      exit(2)
    }

    let schemaURL = repoRoot.appendingPathComponent("Schema/personapad.schema.json")
    guard let schemaData = try? fileClient.readData(schemaURL),
          let schemaJSON = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] else {
      fputs("Schema validation failed: could not read schema at \(schemaURL.path).\n", stderr)
      exit(2)
    }

    let config = loadSchemaConfig(schemaJSON: schemaJSON)

    let args = Array(CommandLine.arguments.dropFirst())
    let inputPaths = args.isEmpty ? [repoRoot.appendingPathComponent("Examples")] : args.map { URL(fileURLWithPath: $0, relativeTo: cwd) }

    let exampleFiles = collectJSONFiles(paths: inputPaths, fileClient: fileClient)
    if exampleFiles.isEmpty {
      fputs("Schema validation failed: no JSON files found in Examples/.\n", stderr)
      exit(2)
    }

    var failures: [String] = []
    for file in exampleFiles {
      if let message = validateFile(file, config: config, fileClient: fileClient) {
        failures.append(message)
      }
    }

    if !failures.isEmpty {
      fputs("Schema validation failed:\n", stderr)
      for message in failures {
        fputs("- \(message)\n", stderr)
      }
      exit(1)
    }

    print("Schema validation passed for \(exampleFiles.count) file(s).")
  }

  private static func findRepoRoot(start: URL, fileClient: FileClient) -> URL? {
    var current = start
    for _ in 0..<6 {
      let schema = current.appendingPathComponent("Schema/personapad.schema.json")
      if fileClient.fileExists(schema) {
        return current
      }
      current = current.deletingLastPathComponent()
    }
    return nil
  }

  private static func collectJSONFiles(paths: [URL], fileClient: FileClient) -> [URL] {
    var files: [URL] = []
    for path in paths {
      guard fileClient.fileExists(path) else { continue }
      if fileClient.isDirectory(path) {
        if let contents = try? fileClient.contentsOfDirectory(path, nil) {
          for item in contents where item.pathExtension.lowercased() == "json" {
            files.append(item)
          }
        }
      } else if path.pathExtension.lowercased() == "json" {
        files.append(path)
      }
    }
    return files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
  }

  private static func loadSchemaConfig(schemaJSON: [String: Any]) -> SchemaConfig {
    let documentTypes = Set(readStringArray(schemaJSON["properties"], keyPath: ["documentType", "enum"]))
    let personaRequired = readStringArray(schemaJSON["$defs"], keyPath: ["persona", "required"])
    let personaPackRequired = readStringArray(schemaJSON["allOf"], matchConst: "personaPack")
    let packRequired = readStringArray(schemaJSON["allOf"], matchConst: "personaPack", thenKeyPath: ["properties", "pack", "required"])
    let outputFormats = Set(readStringArray(schemaJSON["allOf"], matchConst: "personaPack", thenKeyPath: ["properties", "defaults", "properties", "outputFormat", "enum"]))

    return SchemaConfig(
      documentTypes: documentTypes.isEmpty ? ["personaPack", "persona"] : documentTypes,
      packRequired: packRequired.isEmpty ? ["id", "name"] : packRequired,
      personaRequired: personaRequired.isEmpty ? ["id", "name", "system"] : personaRequired,
      personaPackRequired: personaPackRequired.isEmpty ? ["pack", "personas"] : personaPackRequired,
      outputFormats: outputFormats.isEmpty ? ["markdown", "text", "json"] : outputFormats
    )
  }

  private static func readStringArray(_ root: Any?, keyPath: [String]) -> [String] {
    guard var current = root as? [String: Any] else { return [] }
    for key in keyPath.dropLast() {
      guard let next = current[key] as? [String: Any] else { return [] }
      current = next
    }
    guard let arr = current[keyPath.last ?? ""] as? [Any] else { return [] }
    return arr.compactMap { $0 as? String }
  }

  private static func readStringArray(_ root: Any?, matchConst: String, thenKeyPath: [String]? = nil) -> [String] {
    guard let list = root as? [Any] else { return [] }
    for item in list {
      guard let dict = item as? [String: Any],
            let ifObj = dict["if"] as? [String: Any],
            let props = ifObj["properties"] as? [String: Any],
            let docType = props["documentType"] as? [String: Any],
            let constValue = docType["const"] as? String,
            constValue == matchConst
      else { continue }

      guard let thenObj = dict["then"] as? [String: Any] else { return [] }
      if let thenKeyPath {
        return readStringArray(thenObj, keyPath: thenKeyPath)
      }
      if let req = thenObj["required"] as? [Any] {
        return req.compactMap { $0 as? String }
      }
    }
    return []
  }

  private static func validateFile(_ url: URL, config: SchemaConfig, fileClient: FileClient) -> String? {
    guard let data = try? fileClient.readData(url) else {
      return "\(url.lastPathComponent): could not read file."
    }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return "\(url.lastPathComponent): invalid JSON."
    }

    let requiredTop = ["schemaVersion", "documentType"]
    for key in requiredTop where json[key] == nil {
      return "\(url.lastPathComponent): missing '\(key)'."
    }

    guard let schemaVersion = json["schemaVersion"] as? Int, schemaVersion >= 1 else {
      return "\(url.lastPathComponent): schemaVersion must be >= 1."
    }
    guard let documentType = json["documentType"] as? String,
          config.documentTypes.contains(documentType) else {
      return "\(url.lastPathComponent): documentType must be one of \(config.documentTypes.sorted())."
    }

    if documentType == "personaPack" {
      for key in config.personaPackRequired where json[key] == nil {
        return "\(url.lastPathComponent): missing '\(key)' for personaPack."
      }
      if let pack = json["pack"] as? [String: Any] {
        for key in config.packRequired {
          guard let value = pack[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "\(url.lastPathComponent): pack.\(key) must be a non-empty string."
          }
        }
      } else {
        return "\(url.lastPathComponent): pack must be an object."
      }
      if let defaults = json["defaults"] as? [String: Any],
         let outputFormat = defaults["outputFormat"] as? String,
         !config.outputFormats.contains(outputFormat) {
        return "\(url.lastPathComponent): defaults.outputFormat must be one of \(config.outputFormats.sorted())."
      }
      guard let personas = json["personas"] as? [Any], !personas.isEmpty else {
        return "\(url.lastPathComponent): personas must be a non-empty array."
      }
      for (idx, item) in personas.enumerated() {
        if let message = validatePersonaObject(item, config: config) {
          return "\(url.lastPathComponent): personas[\(idx)]: \(message)"
        }
      }
    } else {
      guard let persona = json["persona"] else {
        return "\(url.lastPathComponent): missing 'persona' for persona."
      }
      if let message = validatePersonaObject(persona, config: config) {
        return "\(url.lastPathComponent): persona: \(message)"
      }
    }

    return nil
  }

  private static func validatePersonaObject(_ value: Any, config: SchemaConfig) -> String? {
    guard let persona = value as? [String: Any] else {
      return "must be an object."
    }
    if persona["extends"] != nil {
      return "'extends' is not supported in v1."
    }
    if persona["systemAppend"] != nil {
      return "'systemAppend' is not supported in v1."
    }
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

    if let template = persona["template"] {
      guard let templateObj = template as? [String: Any] else { return "template must be an object." }
      if let sections = templateObj["sections"] as? [Any] {
        for (idx, section) in sections.enumerated() {
          guard let sectionObj = section as? [String: Any] else {
            return "template.sections[\(idx)] must be an object."
          }
          for key in ["key", "label", "required"] {
            if sectionObj[key] == nil { return "template.sections[\(idx)] missing '\(key)'." }
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
    }

    if let contract = persona["outputContract"] as? [String: Any] {
      if let headings = contract["headings"] as? [Any] {
        for (idx, heading) in headings.enumerated() {
          if (heading as? String) == nil {
            return "outputContract.headings[\(idx)] must be a string."
          }
        }
      }
      if let max = contract["askClarifyingQuestionsMax"] {
        guard let intVal = max as? Int, intVal >= 0 else {
          return "outputContract.askClarifyingQuestionsMax must be an integer >= 0."
        }
      }
    }

    return nil
  }
}

private struct SchemaEnvironment {
  @Dependency(\.fileClient) var fileClient
}
