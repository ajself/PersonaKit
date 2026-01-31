import Foundation

struct SessionFile: Codable {
    let id: String
    let personaId: String
    let taskId: String
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

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw SessionFileError.decodeFailed(trimmedId, error.localizedDescription)
        }

        let session: SessionFile
        do {
            session = try JSONDecoder().decode(SessionFile.self, from: data)
        } catch {
            throw SessionFileError.decodeFailed(trimmedId, error.localizedDescription)
        }

        guard session.id == trimmedId else {
            throw SessionFileError.idMismatch(trimmedId, session.id, relativePath)
        }

        return session
    }
}
