import Foundation

struct ScopeSet: Equatable {
    let projectScopeURL: URL?
    let globalScopeURL: URL?

    init(projectScopeURL: URL?, globalScopeURL: URL?) {
        self.projectScopeURL = projectScopeURL?.standardizedFileURL
        self.globalScopeURL = globalScopeURL?.standardizedFileURL
    }

    var isEmpty: Bool {
        projectScopeURL == nil && globalScopeURL == nil
    }

    var loadOrder: [URL] {
        uniqueRoots([globalScopeURL, projectScopeURL].compactMap { $0 })
    }

    var resolutionOrder: [URL] {
        uniqueRoots([projectScopeURL, globalScopeURL].compactMap { $0 })
    }

    private func uniqueRoots(_ roots: [URL]) -> [URL] {
        var seen: Set<String> = []
        return roots.filter { url in
            let path = url.standardizedFileURL.path
            return seen.insert(path).inserted
        }
    }
}
