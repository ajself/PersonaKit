import Foundation

struct ScopeRootResolver: Sendable {
    private let projectLocator: ProjectPersonaKitLocator
    private let globalLocator: GlobalPersonaKitLocator

    init(
        startingURL: URL? = nil,
        homeDirectory: URL? = nil
    ) {
        self.projectLocator = ProjectPersonaKitLocator(startingURL: startingURL)
        self.globalLocator = GlobalPersonaKitLocator(homeDirectory: homeDirectory)
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
