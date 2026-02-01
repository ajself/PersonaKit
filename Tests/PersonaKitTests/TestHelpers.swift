import Foundation
import Darwin

private let stdoutCaptureLock = NSLock()

func makeTempDirectory() throws -> URL {
    let base = FileManager.default.temporaryDirectory
    let destination = base.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    return destination
}

func snapshotFiles(at root: URL) throws -> [String: Data] {
    let fileManager = FileManager.default
    let rootComponents = root.standardizedFileURL.pathComponents
    var results: [String: Data] = [:]

    guard let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return results
    }

    for case let fileURL as URL in enumerator {
        let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
        if values.isDirectory == true {
            continue
        }
        let fileComponents = fileURL.standardizedFileURL.pathComponents
        let relativeComponents = fileComponents.dropFirst(rootComponents.count)
        let relativePath = relativeComponents.joined(separator: "/")
        results[relativePath] = try Data(contentsOf: fileURL)
    }

    return results
}

func repoRootURL() -> URL {
    let fileURL = URL(fileURLWithPath: #filePath)
    return fileURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func fixturesRootURL() -> URL {
    repoRootURL().appendingPathComponent("Fixtures")
}

func fixtureKitRootURL() -> URL {
    fixturesRootURL().appendingPathComponent("kit-root")
}

func copyFixtureKit(to destination: URL) throws {
    try FileManager.default.copyItem(at: fixtureKitRootURL(), to: destination)
}

func normalizedTrailingNewline(_ value: String) -> String {
    var trimmed = value
    while trimmed.last == "\n" {
        trimmed.removeLast()
    }
    return trimmed + "\n"
}

func captureStdout(_ work: () -> Void) -> String {
    stdoutCaptureLock.lock()
    defer { stdoutCaptureLock.unlock() }

    let pipe = Pipe()
    let stdoutFd = dup(STDOUT_FILENO)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    work()
    fflush(stdout)
    pipe.fileHandleForWriting.closeFile()
    dup2(stdoutFd, STDOUT_FILENO)
    close(stdoutFd)

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}
