# SwiftUI Style Guide

Use this runtime guide for active SwiftUI implementation and review sessions.
Consult reference id `swiftui-style-guide-reference` when you need examples, architecture rationale, or deeper SwiftUI composition guidance.

## Core Rules

1. Each mutable concept has one clear owner.
2. Route mutation through named methods on that owner.
3. Keep networking, file IO, persistence, and OS-service access out of views.
4. Do not introduce MVVM or coordinator layers by default.
5. Organize code by feature first, then supporting layer when needed.

## Default Shape

1. Each feature should have:
   - SwiftUI view(s)
   - one explicit owner type
   - injected client or service boundaries
2. UI-facing owner types should usually be `@MainActor`.
3. Read `App/ArchitectureDefaults.md` before adding a new feature owner shape.

## View And Data Guidance

1. Keep owned data local until a real shared owner is required.
2. Avoid duplicated mutable state across views.
3. Move non-trivial derived state, async work, and mutation logic into the owner type.
4. Prefer small feature-local components over giant view files.

## Testing

1. Tests are required for non-trivial owner behavior.
2. Owner types are the default unit under test.
3. If a feature needs a different architecture shape, document the reason and tradeoff.
