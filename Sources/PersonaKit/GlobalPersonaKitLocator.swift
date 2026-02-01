import Foundation

struct GlobalPersonaKitLocator {
    private let fileManager: FileManager
    private let homeDirectory: URL

    init(homeDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
    }

    func locate() -> URL? {
        let candidate = homeDirectory.appendingPathComponent(".personakit")
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return candidate.standardizedFileURL
    }
}
