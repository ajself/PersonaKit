import Foundation

struct ProjectPersonaKitLocator: Sendable {
    private let startingURL: URL

    init(startingURL: URL? = nil) {
        if let startingURL {
            self.startingURL = startingURL
        } else {
            self.startingURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
    }

    func locate() -> URL? {
        var current = startingURL.standardizedFileURL
        var remaining = current.pathComponents.count + 1
        while remaining > 0 {
            if hasPersonaKitDirectory(at: current) {
                return current.appendingPathComponent(".personakit")
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
            remaining -= 1
        }
        return nil
    }

    private func hasPersonaKitDirectory(at root: URL) -> Bool {
        let candidate = root.appendingPathComponent(".personakit")
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
