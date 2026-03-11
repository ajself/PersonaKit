# Tools & Constraints

- No large refactors
- No new dependencies without approval
- Git commit authority is denied by default; require AJ approval per commit unless a scoped worktree authorization mode is active
- When creating a git commit, use Conventional Commit format: `type(scope): summary` when a clear scope exists, otherwise `type: summary`
- `samwise-feature-commit-approved` is valid only for the current AJ-approved Taskboard parity initiative branch/worktree and is never valid on repository `main`
- Scoped auto-commit approval is otherwise valid only for an AJ-approved dedicated non-main worktree and is never valid on repository `main`
- Xcode app and CLI flows in this repo use `xcodebuildmcp` for app and CLI builds (`PersonaKitStudio` for app build verification, `PersonaKitCLI` for CLI build), and use `xcodebuild` with `PersonaKit` plus `.build/DerivedData` for app launch/test coverage
- Package, unit, and snapshot verification flows standardize on `swift test`, which also writes into `.build`
