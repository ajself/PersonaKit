# PersonaKit Studio (macOS) — MVP Specification

## 1. Product Intent

PersonaKit Studio is a local-first macOS application for managing:

- Personas
- Directives
- Kits
- Essentials
- Skills
- Intents
- Sessions

It is a deterministic GUI over the existing PersonaKit file structure.

Studio does not run agents.
Studio assembles, validates, previews, and exports session context.

All data is file-backed inside `.personakit/`.

---

## 2. Non-Goals (Explicitly Out of Scope)

- No cloud sync
- No collaboration
- No background automation
- No plugin system
- No schema-generated mega-forms
- No editing of Global scope in v1
- No runtime agent execution

Keep it small and durable.

---

## 3. Workspace Model

A Workspace = a folder containing:

.personakit/
  Packs/
    personas/
    directives/
    kits/
    intents/
    skills/
    essentials/
  Sessions/

Studio loads:

- Project scope: `<workspace>/.personakit`
- Global scope: `~/.personakit` (read-only in v1)

Each item must display its scope:
- Project
- Global

Editing rules:
- Project items: editable
- Global items: read-only
- Optional action: “Copy to Project”

---

## 4. Application Architecture

### 4.1 High-Level Structure

NavigationSplitView:

Sidebar
List
Detail

### Sidebar Sections

- Sessions
- Library
  - Personas
  - Directives
  - Kits
  - Essentials
  - Skills
  - Intents
- Diagnostics
  - Validation Results

---

## 5. Core Features (v1)

### 5.1 Workspace Loading

- File → Open Workspace…
- Validate `.personakit/` exists
- If missing, offer:
  - “Initialize PersonaKit Structure”

Initialize creates:

.personakit/Packs/{personas,directives,kits,intents,skills,essentials}
.personakit/Sessions

After load:
- Build registry snapshot
- Run validation once

---

### 5.2 Sessions (Primary Workflow)

List shows:
- id
- personaId
- directiveId
- validity indicator

Detail tabs:

#### Edit Tab
Fields:
- id
- Persona picker (searchable)
- Directive picker (searchable)
- Kit overrides (multi-select)

Actions:
- Save
- Validate
- Reveal in Finder
- Delete (confirm dialog)

Rules:
- File name = `<id>.session.json`
- Renaming id renames file
- Cannot save if personaId or directiveId do not exist

#### Preview Tab
- Render Exporter output
- Copy to Clipboard
- Export to File…

---

### 5.3 Library Items

Entities:
- Personas
- Directives
- Kits
- Skills
- Intents

Each item has:

#### Tab 1: Minimal Form
Editable:
- id
- name/title
- key arrays

This form is intentionally limited.

#### Tab 2: Raw JSON
- Monospaced editor
- Validate
- Save

Rules:
- Save blocked if schema invalid
- Optional preference: Allow invalid saves (default OFF)

Global items:
- Read-only
- “Copy to Project” action

---

### 5.4 Essentials

- Markdown text editor
- Save writes to file
- No rich WYSIWYG in v1

---

### 5.5 Validation

- “Validate Workspace” button
- Displays:
  - file path
  - error message
  - severity
- Clicking navigates to relevant item

---

### 5.6 Export

Session Preview supports:

- Copy to clipboard
- Export to file (Markdown preferred canonical format)

---

## 6. Data Flow

Studio is a thin UI shell over ContextCore.

### WorkspaceStore (@MainActor)

Properties:
- workspaceURL: URL?
- snapshot: WorkspaceSnapshot
- selection
- validationResults

### WorkspaceSnapshot

Contains arrays per entity type.
Each element includes:
- id
- display name
- fileURL
- sourceScope (project/global)

---

## 7. Acceptance Criteria (MVP)

1. Can open a workspace folder.
2. Sidebar populates Sessions + Library.
3. Can create/edit/delete Sessions.
4. Session validation blocks invalid references.
5. Can preview resolved output.
6. Can copy/export resolved output.
7. Can edit Project-scope library items.
8. Global items are read-only.
9. Workspace validation reports schema errors.

---

## 8. Future (v1.1)

- Dependency graph viewer
- Cross-reference inspector
- File watching (auto reload)
- Rendered markdown preview
- Quick session export from menu bar app

---

## 9. Design Principles

- Local-first
- Deterministic
- File-backed
- Small and durable
- No invented abstractions
- Reuse ContextCore wherever possible
