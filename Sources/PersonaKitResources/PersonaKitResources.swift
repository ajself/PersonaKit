import Foundation

public enum PersonaKitResources {
  public static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    let bundle = Bundle(for: BundleToken.self)
    if let resourceURL = bundle.url(forResource: "PersonaKitResources", withExtension: "bundle"),
       let resourceBundle = Bundle(url: resourceURL) {
      return resourceBundle
    }
    return bundle
    #endif
  }()
}

private final class BundleToken {}
