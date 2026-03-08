# Tools & Constraints

- No large refactors
- No new dependencies without approval
- Git commit authority is denied by default; require AJ approval per commit unless a scoped worktree authorization mode is active
- `samwise-feature-commit-approved` is valid only for the current AJ-approved Taskboard parity initiative branch/worktree and is never valid on repository `main`
- Scoped auto-commit approval is otherwise valid only for an AJ-approved dedicated non-main worktree and is never valid on repository `main`
