# Deterministic CLI Work

Use stable ordering when output is user-visible.

Keep changes scoped to the requested command, option, or help text.

Do not add agent orchestration, deployment behavior, memory, persistence, or arbitrary command execution.

Stop for human review when the requested change would create new execution behavior.

