import Foundation

struct GlobalPersonaKitLocator: Sendable {
    private let homeDirectory: URL

    init(homeDirectory: URL? = nil) {
        self.homeDirectory = homeDirectory ?? FileManager.default.homeDirectoryForCurrentUser
    }

    func locate() -> URL? {
        let candidate = homeDirectory.appendingPathComponent(".personakit")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return candidate.standardizedFileURL
    }
}
