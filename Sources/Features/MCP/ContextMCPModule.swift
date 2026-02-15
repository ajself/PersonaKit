import ContextCore

/// Scaffold marker for the future feature-oriented MCP module.
public enum ContextMCPModule {
  public static let dependsOnContextCore = ContextCoreModule.isScaffolded
}
