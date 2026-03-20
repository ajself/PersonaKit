  # Migration Validation Artifact

Status: Accepted
Milestone: `M3`
Owner: `senior-swiftui-engineer`
Grounding: `senior-swiftui-engineer` + `apply-style`
Last Updated: 2026-03-20

## Decision

- result: `pass with notes`

## Validation Readout

### Current proof set exercised

- `swift test --filter Phase1RuntimeSchemaTests`
- `swift test --filter Phase1RuntimeRepositoryTests`
- `swift test --filter Phase1CollaboratorResponseServiceTests`
- `swift test --filter Phase1RoomWriteServiceTests`
- `swift test --filter Phase1RealtimeContractTests`
- `swift test --filter Phase1RealtimeFeedServiceTests`
- `swift test --filter OrbitPostgresRealtimeLoaderTests`
- `swift test --filter Phase1RealtimeSubscriptionAdapterTests`
- `swift test --filter Phase1RealtimePollingSessionTests`
- `swift test --filter Phase1RealtimeTransportAdapterTests`
- `swift test --filter OrbitArtifactStorageTests`
- `swift test --filter OrbitServerGatewayTests`
- `swift test --filter OrbitGatewayNetworkClientTests`
- `swift test --filter OrbitPostgresRuntimeStoreIntegrationTests`
- `swift test --filter OrbitServerRoomProjectionTests`
- `swift test --filter OrbitServerBackedRoomClientTests`
- `swift test --filter OrbitServerBackedRoomCoordinatorTests`
- `swift test --filter OrbitServerBackedRoomClientFactoryTests`
- `swift test --filter OrbitServerBackedRoomTransportPolicyTests`
- `swift test --filter OrbitServerBackedRoomStateTests`
- `swift test --filter OrbitWorkspaceTests`
- `git diff --check`

### What this proves now

- canonical schema and repository contract are locked in code
- bootstrap, append, replay, resync, and thin transport semantics are all
  deterministic
- a live `Vapor` gateway seam now exists and stays thin over the replay/session
  services
- the first server-side room write path now exists through the runtime service
  and gateway edge
- the first server-driven collaborator response path now exists through the same
  canonical runtime and gateway seam
- the live runtime-store harness now has a one-command local temp-`Postgres`
  proof path, and that path passed three consecutive mutation-ring runs
- artifact storage is replaceable and filesystem-backed
- a canonical room snapshot can be projected into the Orbit macOS room shape
- replayed server events can be reduced into the projected macOS room state
- the macOS client now has a transport-facing coordinator seam for server-backed
  connect and poll behavior
- the macOS client can now keep canonical transport traffic on one persistent
  gateway `WebSocket` connection, reconnect from its last replay cursor, and
  fall back to the existing HTTP poll path when persistent transport fails
- replay of the currently supported runtime mutation types is now covered on the
  server-backed macOS path, including system-message, collaborator-response,
  and activation-failure recovery
- the Studio root can now enable the server-backed Orbit client path through
  explicit runtime configuration

### What this does not prove yet

- long-running persistent transport soak or operations-grade
  disconnect/reconnect proof
- CI-backed or operations-backed live database proof beyond the repeated local
  temp-`Postgres` harness runs
- full end-to-end macOS closeout proof over the env-gated server-backed
  write/read path

## Judgment

The current `M3` slice is validation-reviewable and materially stronger than a
pure planning baseline, with explicit notes on what is still missing.

Current disposition:

- this migration validation readout supported AJ approval of the current `M3`
  checkpoint
