import ContextCore

/// Scaffold marker for the future feature-oriented CLI module.
public enum ContextCLIModule {
  public static let dependsOnContextCore = ContextCoreModule.isScaffolded
}
