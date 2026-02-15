import ContextCore

/// Scaffold marker for the future Studio foundation module.
public enum StudioFoundationModule {
  public static let dependsOnContextCore = ContextCoreModule.isScaffolded
}
