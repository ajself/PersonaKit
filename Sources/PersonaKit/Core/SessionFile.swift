import Foundation

struct SessionFile: Codable {
    let id: String
    let personaId: String
    let directiveId: String
    let kitOverrides: [String]?
}

enum SessionFileError: LocalizedError {
    case notFound(String, String)
    case decodeFailed(String, String)
    case idMismatch(String, String, String)
    case invalidSessionId

    var errorDescription: String? {
        switch self {
        case .notFound(let sessionId, let expectedPath):
            return "Session file not found for \(sessionId). Expected \(expectedPath)."
        case .decodeFailed(let sessionId, let message):
            return "Failed to decode session file for \(sessionId): \(message)"
        case .idMismatch(let sessionId, let actualId, let path):
            return "Session id mismatch in \(path). Expected \(sessionId), got \(actualId)."
        case .invalidSessionId:
            return "Session id is required."
        }
    }
}

struct SessionFileLoader {
    static func load(
        scopes: ScopeSet,
        sessionId: String,
        fileManager: FileManager = .default
    ) throws -> SessionFile {
        let trimmedId = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            throw SessionFileError.invalidSessionId
        }

        let relativePath = "Sessions/\(trimmedId).session.json"
        for root in scopes.resolutionOrder {
            let fileURL = root.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: fileURL.path) {
                return try loadSessionFile(
                    fileURL: fileURL,
                    sessionId: trimmedId,
                    relativePath: relativePath
                )
            }
        }

        throw SessionFileError.notFound(trimmedId, relativePath)
    }

    static func load(
        root: URL,
        sessionId: String,
        fileManager: FileManager = .default
    ) throws -> SessionFile {
        let trimmedId = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            throw SessionFileError.invalidSessionId
        }

        let relativePath = "Sessions/\(trimmedId).session.json"
        let fileURL = root.appendingPathComponent(relativePath)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw SessionFileError.notFound(trimmedId, relativePath)
        }

        return try loadSessionFile(
            fileURL: fileURL,
            sessionId: trimmedId,
            relativePath: relativePath
        )
    }

    private static func loadSessionFile(
        fileURL: URL,
        sessionId: String,
        relativePath: String
    ) throws -> SessionFile {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw SessionFileError.decodeFailed(sessionId, error.localizedDescription)
        }

        let session: SessionFile
        do {
            session = try JSONDecoder().decode(SessionFile.self, from: data)
        } catch {
            throw SessionFileError.decodeFailed(sessionId, error.localizedDescription)
        }

        guard session.id == sessionId else {
            throw SessionFileError.idMismatch(sessionId, session.id, relativePath)
        }

        return session
    }
}
