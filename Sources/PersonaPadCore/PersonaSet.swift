import Foundation

public struct PersonaSet: Sendable, Hashable {
  public let source: PersonaSource
  public let pack: PackMeta
  public let defaults: PackDefaults?
  public let personas: [Persona]
}

public struct ResolvedPersona: Sendable, Hashable {
  public let baseIDs: [String]   // source ids (v1: single id)
  public let persona: Persona
}
