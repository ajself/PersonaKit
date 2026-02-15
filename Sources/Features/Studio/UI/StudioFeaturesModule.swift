import StudioFoundation

/// Scaffold marker for the future Studio UI feature module.
public enum StudioFeaturesModule {
  public static let dependsOnStudioFoundation = StudioFoundationModule.dependsOnContextCore
}
