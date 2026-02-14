import Foundation

struct PersonaKitDirectory {
    private static let packsDirectoryName = "Packs"
    private static let sessionsDirectoryName = "Sessions"

    static func packsURL(root: URL) -> URL {
        root.appendingPathComponent(packsDirectoryName)
    }

    static func sessionsURL(root: URL) -> URL {
        root.appendingPathComponent(sessionsDirectoryName)
    }

    static func hasPacks(root: URL, fileManager: FileManager = .default) -> Bool {
        hasDirectory(at: packsURL(root: root), fileManager: fileManager)
    }

    static func hasSessions(root: URL, fileManager: FileManager = .default) -> Bool {
        hasDirectory(at: sessionsURL(root: root), fileManager: fileManager)
    }

    private static func hasDirectory(at url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
