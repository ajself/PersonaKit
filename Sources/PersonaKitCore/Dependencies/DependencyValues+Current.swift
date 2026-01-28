import Dependencies

public extension DependencyValues {
  /// Public accessor for the current task-local dependency values.
  static var current: DependencyValues { _current }
}
