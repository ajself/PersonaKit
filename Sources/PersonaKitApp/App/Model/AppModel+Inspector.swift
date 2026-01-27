import PersonaKitCore

/// Inspector-related behaviors for ``AppModel``.
extension AppModel {
  /// Computes a diff between two selected packs and returns diff diagnostics.
  func computePackDiff(
    primary: PackSelection,
    comparison: PackSelection
  ) -> (diff: PackDiff, diagnostics: [Diagnostic]) {
    let left = PackDiffInputBuilder.build(for: primary, fileClient: fileClient)
    let right = PackDiffInputBuilder.build(for: comparison, fileClient: fileClient)
    let diagnostics = left.diagnostics + right.diagnostics
    let diff = PackDiffBuilder.diff(left: left.records, right: right.records)
    return (diff, diagnostics)
  }
}
