# Tools & Constraints

- No large refactors
- No new dependencies without approval
- Git commit authority is denied by default; require AJ approval per commit unless a scoped worktree auto-commit exception is active
- Scoped auto-commit exception is valid only for an AJ-approved dedicated non-main worktree and is never valid on `main`
