import Foundation

struct ScopeRootResolver {
    private let projectLocator: ProjectPersonaKitLocator
    private let globalLocator: GlobalPersonaKitLocator

    init(
        startingURL: URL? = nil,
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.projectLocator = ProjectPersonaKitLocator(startingURL: startingURL, fileManager: fileManager)
        self.globalLocator = GlobalPersonaKitLocator(homeDirectory: homeDirectory, fileManager: fileManager)
    }

    func locate() -> URL? {
        if let project = projectLocator.locate() {
            return project
        }
        if let global = globalLocator.locate() {
            return global
        }
        return nil
    }
}
