# Codex Task Plan — PersonaKit Studio (macOS)

This plan is incremental and PR-sized.
Each milestone must compile and run.
When it is appropriate to commit code pause to review with me first.

---

# Milestone 0 — App Shell

Status: Completed on February 14, 2026.

## Goal
Create a macOS SwiftUI app target that links PersonaKitCore.

## Tasks

1. Create new macOS app target:
   Apps/PersonaKitStudio/

2. Add SwiftPM dependency on the main package.

3. Minimum deployment:
   macOS 26

4. Implement:
   - NavigationSplitView
   - Static sidebar sections
   - File → Open Workspace menu item

## Acceptance

- App launches
- Sidebar renders static sections
- Open Workspace menu presents folder picker

---

# Milestone 1 — Workspace Loading (Read-Only)

Status: Completed on February 14, 2026.

## Goal
Load project + global scope and show lists.

## Tasks

1. Implement WorkspaceStore (@MainActor)
   - workspaceURL
   - snapshot
   - loadWorkspace()

2. Implement WorkspaceSnapshot builder:
   - Scan .personakit structure
   - Load registry via PersonaKitCore
   - Include fileURL + sourceScope

3. Populate List view for:
   - Sessions
   - Personas
   - Directives
   - Kits
   - Skills
   - Intents
   - Essentials

4. Add search filter.

## Acceptance

- Opening workspace populates all categories
- Items show scope badge (Project/Global)

---

# Milestone 2 — Validation Panel

Status: Completed on February 14, 2026.

## Goal
Surface schema validation results.

## Tasks

1. Use existing Validator from PersonaKitCore.
2. Store validation results in WorkspaceStore.
3. Implement Diagnostics list view.
4. Add “Validate Workspace” button.

## Acceptance

- Validation runs and displays errors.
- Clicking error navigates to correct entity.

---

# Milestone 3 — Session Editor

Status: Completed on February 14, 2026.

## Goal
Full create/edit/delete workflow for Sessions.

## Tasks

1. Implement SessionEditorView:
   - id field
   - persona picker
   - directive picker
   - kit overrides multi-select

2. Save writes to:
   .personakit/Sessions/<id>.session.json

3. Block save if:
   - personaId invalid
   - directiveId invalid

4. Implement delete with confirmation.

5. Implement rename:
   - update id
   - rename file

## Acceptance

- Can create session
- Can edit session
- Can delete session
- Validation prevents invalid references

---

# Milestone 4 — Session Preview + Export

Status: Completed on February 14, 2026.

## Goal
Display resolved output.

## Tasks

1. Use Resolver + Exporter from PersonaKitCore.
2. Implement Preview tab.
3. Add:
   - Copy to Clipboard
   - Export to file (Markdown)

## Acceptance

- Preview shows assembled output
- Copy works
- Export writes file

---

# Milestone 5 — Library Editing (Raw JSON First)

## Goal
Enable editing of Project-scope entities.

## Tasks

1. Implement RawJSONEditorView:
   - TextEditor
   - Validate
   - Save

2. Block editing if sourceScope == Global.
3. Add “Copy to Project” action for Global items.
4. On save:
   - Validate via schema
   - Write file

## Acceptance

- Can edit Project items
- Cannot edit Global items
- Copy to Project duplicates file into workspace

---

# Milestone 6 — Essentials Editor

## Goal
Edit Markdown essentials.

## Tasks

1. Implement MarkdownEditorView.
2. Save writes to correct file.
3. Validate references after save.

## Acceptance

- Can edit and save essentials
- Validation updates correctly

---

# Engineering Constraints

- No schema-driven UI generator.
- No file watching (manual reload acceptable).
- No runtime automation.
- No additional domain abstractions.
- Reuse PersonaKitCore for all logic.

---

# Definition of Done (MVP)

- All milestones complete
- App builds clean
- No warnings
- Workspace open → edit → validate → export works end-to-end
