# Artifact Storage Boundary Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `architectural-editor`
Review Ring: `studio-integration-coordinator`, `studio-reliability-engineer`
Last Updated: 2026-03-18

## Purpose

Record the Packet 4 storage-boundary slice before artifacts and transactional
runtime truth begin to blur.

## What Exists Now

- `OrbitArtifactReference`
- `OrbitArtifactPutRequest`
- `OrbitArtifactStorage`
- `OrbitFilesystemArtifactStorage`

These now exist in `Sources/Features/OrbitServerRuntime/OrbitArtifactStorage.swift`.

## Current Boundary Rule

### Transactional truth stays out of artifact storage

The relational runtime remains responsible for:

- workspace, channel, post, thread, and message truth
- activation, participant, and run linkage
- replay and recovery inputs

### Artifact storage owns only large durable file-like payloads

The artifact layer now provides:

- stable artifact references
- namespaced object-style writes
- replaceable storage implementation behind one protocol

The current first backend is filesystem-based by design.

## Why This Matters

- `M3` can now attach durable files without polluting runtime tables with raw
  artifact payloads
- later backend changes can replace the storage implementation without changing
  the product-facing artifact reference model
- the first self-hosted deployment shape stays compatible with a NAS-backed
  posture

## Deterministic Proof

- `Tests/Features/OrbitServer/OrbitArtifactStorageTests.swift`

Current proof covers:

- round-trip artifact write/read
- delete-by-reference behavior
- unsafe-namespace rejection

## Honest Limit

This slice does not yet attach artifact references to canonical room records.

It freezes the abstraction boundary and first backend shape needed before that
linkage is added.

## Packet 4 Judgment

Packet 4 has started credibly because the artifact layer is now object-style,
replaceable, filesystem-backed, and clearly separate from transactional runtime
truth.
