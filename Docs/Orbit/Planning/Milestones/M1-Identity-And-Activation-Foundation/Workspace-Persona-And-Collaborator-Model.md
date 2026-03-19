# Workspace Persona And Collaborator Model

Status: Accepted
Milestone: `M1`
Owner: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Define the first-checkpoint identity model that connects visible collaborators to
workspace persona instances and PersonaKit persona templates without blurring the
authored-versus-runtime boundary.

Accepted here means this note is the approved Packet 2 identity baseline for
`M1`. It does not mean the full activation contract or trace inspectability work
is finished.

## Identity Layers

The first checkpoint uses the RFC-0003 three-layer model:

1. persona template
   authored PersonaKit source such as `samwise` or `venture-product-steward`
2. workspace persona instance
   Orbit runtime identity anchored in the `Orbit` workspace
3. collaborator
   the product-facing teammate label shown in the command-center UI

For the first checkpoint, collaborator remains a product-facing layer over
runtime records. It is not introduced as a separate stored entity.

## Participant Classes

### Human participant

- visible actor in the workspace
- no PersonaKit persona template mapping required
- no workspace persona instance required for `M1`

### AI-backed collaborator

- visible teammate in the workspace
- must map to one stable workspace persona instance
- must map to one authored PersonaKit persona template or approved alias
- must preserve that mapping in activation records for attributable responses

## Required First-Checkpoint Runtime Fields

| Runtime record | Required identity fields | Why |
| --- | --- | --- |
| participant | `id`, `displayName`, `participantType` | visible roster identity |
| AI-backed participant | `workspacePersonaID`, `personaTemplateID`, `defaultDirectiveID` | stable runtime anchor plus authored contract reference |
| activation record | `workspaceID`, `participantID`, `workspacePersonaID`, `personaTemplateID`, `directiveID` | durable attribution from runtime identity back to authored truth |

## Founding Roster Mapping

| Visible collaborator | Participant type | Workspace persona instance | PersonaKit persona template | Identity note |
| --- | --- | --- | --- | --- |
| AJ | human | none required in `M1` | none | human operator record only |
| Samwise | ai-collaborator | `workspace-persona-orbit-samwise` | `samwise` | direct collaborator-to-template mapping |
| ProdDoc | ai-collaborator | `workspace-persona-orbit-proddoc` | `venture-product-steward` | approved product-facing alias over one stable authored template |

## First-Checkpoint Simplifications

- workspace persona instances are stored as stable ids on participant and
  activation records instead of as a separate rich runtime table
- collaborator remains a product-facing label and does not become a separate
  persisted entity
- human participant records stay lightweight because `M1` only needs one human
  operator record for AJ

These simplifications are acceptable for the local checkpoint because they keep
identity attributable without forcing the full canonical runtime model early.

## Guardrails

- do not show an AI-backed collaborator without a stable `workspacePersonaID`
- do not treat `personaTemplateID` as runtime-owned editable state
- do not let one visible collaborator swap between multiple authored persona
  templates invisibly
- do not break the frozen `ProdDoc` -> `venture-product-steward` alias mapping

## Packet 2 Decision

For `M1`, every visible AI-backed collaborator in Orbit must carry both:

- a runtime `workspacePersonaID`
- an authored `personaTemplateID`

That pair is the minimum stable identity anchor the first checkpoint may build
on.
