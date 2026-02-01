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

    func locate() -> ScopeSet? {
        let project = projectLocator.locate()
        let global = globalLocator.locate()
        if project == nil && global == nil {
            return nil
        }
        return ScopeSet(projectScopeURL: project, globalScopeURL: global)
    }
}
