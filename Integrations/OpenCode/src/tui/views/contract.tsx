import type { RGBA } from '@opentui/core'
import { For, Show } from 'solid-js'
import type { Contract, DriftEvent, PaneState, Preview, Resolution, SessionState } from '../../../../ClaudeCode/types'
import { canUse } from '../../../../ClaudeCode/hooks/lib/ids.ts'
import { previewKey } from '../../../../ClaudeCode/hooks/lib/runner.ts'
import { MANIFEST_CHANGED, NO_CONTRACT_HINT } from './chip.tsx'
import { Button, LABEL_WIDTH, line, Muted, Row, Section, StepsSection, useUi } from './library.tsx'
import type { PaneActions, Theme } from './library.tsx'

// A port of the Claude Code mod's `views/contract.tsx`: the contract in force for the session the route was opened
// from. OpenCode's enforcement adds two states the mod lacks, a manifest changed since startup and a manifest whose
// server plugin isn't loaded; both read as the sidebar and status chip say them.

const list = (ids: readonly string[]) => (ids.length ? ids.join(', ') : 'none')
const source = (r: Resolution) => (r.source === 'mcp' ? 'MCP' : 'CLI')
const ago = (turns: number) => (turns <= 0 ? 'this turn' : turns === 1 ? '1 turn ago' : `${turns} turns ago`)

/** Session id, else persona › directive: how a resolution is named in a row. */
function lead({ ids, details }: Resolution): string {
  if (ids.sessionId) return ids.sessionId
  const persona = details?.personaName ?? ids.personaId ?? 'contract'
  const directive = details?.directiveTitle ?? ids.directiveId
  return directive ? `${persona} › ${directive}` : persona
}

/** A display name and, when it differs, the id to show muted beside it. */
const named = (name: string | undefined, id: string | undefined) => (name && id && name !== id ? { name, id } : { name: name ?? id })

const isClean = (c: Contract) =>
  c.isAuthorized &&
  c.failureReasons.length === 0 &&
  c.unauthorizedRequestedSkillIds.length === 0 &&
  c.unauthorizedRequiredSkillIds.length === 0 &&
  c.undeclaredRequestedSkillIds.length === 0

/** Why the Skills section is empty: the route is reading, couldn't, or there was nothing to read. */
const notSeen = (preview: Preview | undefined) =>
  preview?.kind === 'loading'
    ? 'Kits, skills, and scope: reading from the CLI…'
    : preview?.kind === 'failed'
      ? `Kits, skills, and scope: not seen (the pane couldn't read them: ${preview.message})`
      : 'Kits, skills, and scope: not seen (no contract JSON resolved)'

/** A drift event's kind in words: a call the contract forbids ran unblocked, was blocked, or a re-ground was blocked. */
const driftKind = (d: DriftEvent) => (d.kind === 'reground-blocked' ? 're-ground blocked' : d.kind === 'advisory' ? 'not blocked' : 'blocked')

/**
 * The enforcement chip and the State row: words and their theme color. Advisory is the default, so it reads muted, as
 * the chip and sidebar do; a manifest for another contract is an error only once a contract is resolved to contradict.
 */
function enforcementWords(state: SessionState, manifestChanged: boolean, theme: Theme): { chip: [string, RGBA]; state: [string, RGBA] } {
  const { enforcement } = state
  if (manifestChanged) return { chip: ['● Manifest changed', theme.warning], state: [MANIFEST_CHANGED, theme.warning] }
  if (enforcement.kind === 'advisory') return { chip: ['● Advisory', theme.textMuted], state: ['Advisory', theme.textMuted] }
  if (enforcement.pluginMissing) {
    return { chip: ['● Plugin not loaded', theme.warning], state: ['⚠ manifest present · plugin not loaded', theme.warning] }
  }
  if (enforcement.manifestUnreadable) return { chip: ['● Manifest unreadable', theme.error], state: ['⚠ Manifest unreadable', theme.error] }
  if (enforcement.kind === 'enforced') return { chip: ['● Enforced', theme.success], state: ['Enforced', theme.success] }
  const other = enforcement.ids.sessionId ?? enforcement.ids.personaId ?? 'another contract'
  const color = state.main ? theme.error : theme.warning
  return { chip: [`● Enforcing ${other}`, color], state: [`⚠ Enforcing ${other}`, color] }
}

/** A name with its id muted beside it. */
function WithId(props: { name?: string; id?: string }) {
  const { theme } = useUi()
  return (
    <text fg={theme().text}>
      {line(props.name ?? 'unknown')}
      <Show when={props.id}>{(id) => <span style={{ fg: theme().textMuted }}>{line(` (${id()})`)}</span>}</Show>
    </text>
  )
}

/**
 * The Contract view: header with status chips, then contract, skills, scope, enforcement, freshness, drift log,
 * subagent contracts, and Re-ground, in the mod's order. Re-ground only while a contract is in force, and disabled
 * while its ids could not be used.
 *
 * A resolution with export details but no contract JSON is filled in from the preview the route read for its ids
 * (`pane.previews`), display-only: the view reads it and runs nothing, and `main` is never touched.
 */
export function ContractView(props: { state: SessionState; manifestChanged: boolean; pane: PaneState; actions: PaneActions }) {
  const { theme } = useUi()
  const main = () => props.state.main
  const words = () => enforcementWords(props.state, props.manifestChanged, theme())
  const enforcement = () => props.state.enforcement
  /** The enforcement with a manifest behind it, else undefined. */
  const manifest = () => {
    const e = enforcement()
    return e.kind === 'advisory' ? undefined : e
  }
  /**
   * What the plugin blocks, or undefined when it isn't enforcing this manifest: one whose plugin isn't loaded enforces
   * nothing, and a changed one isn't the snapshot the server plugin enforces.
   */
  const blocks = () => {
    const e = manifest()
    if (e === undefined || e.pluginMissing || props.manifestChanged) return undefined
    return e.manifestUnreadable ? 'every tool call it checks' : list(e.deniedActionClasses)
  }
  const chips = (): [string, RGBA][] => {
    const blocked = props.state.drift.some((d) => d.kind !== 'advisory')
    const drift: [string, RGBA] =
      props.state.drift.length === 0 ? ['✓ No drift', theme().success] : [`● ${props.state.drift.length} drift`, blocked ? theme().error : theme().warning]
    const compactions = props.state.compactions
    return [
      words().chip,
      ...(main() && compactions > 0 ? [[`● ${compactions} ${compactions === 1 ? 'compaction' : 'compactions'}`, theme().warning] as [string, RGBA]] : []),
      drift,
    ]
  }

  const preview = () => {
    const m = main()
    return m?.contract || !m?.details ? undefined : props.pane.previews[previewKey(m.ids)]
  }
  const read = () => {
    const p = preview()
    return p?.kind === 'loaded' ? p.contract : undefined
  }
  const contract = () => main()?.contract ?? read()
  const details = () => main()?.details
  const directive = () => named(details()?.directiveTitle, details()?.directiveId ?? main()?.ids.directiveId)
  const problems = (c: Contract) => [
    ...c.failureReasons,
    ...(c.unauthorizedRequestedSkillIds.length ? [`Unauthorized requested: ${list(c.unauthorizedRequestedSkillIds)}`] : []),
    ...(c.unauthorizedRequiredSkillIds.length ? [`Unauthorized required: ${list(c.unauthorizedRequiredSkillIds)}`] : []),
    ...(c.undeclaredRequestedSkillIds.length ? [`Undeclared requested: ${list(c.undeclaredRequestedSkillIds)}`] : []),
  ]
  const watching = () => {
    // A manifest whose plugin is not loaded enforces nothing, so its drift is still watched (see `classifyDrift`).
    const e = enforcement()
    if (e.kind !== 'advisory' && !e.pluginMissing) return { text: 'Off while the plugin enforces a manifest', isMuted: true }
    const d = details()
    if (!d) return { text: 'Off until handoff context is seen', isMuted: true }
    if (!d.deniedActionClasses.length) return { text: 'Nothing denied by the handoff context', isMuted: true }
    return { text: d.deniedActionClasses.join(', '), isMuted: false }
  }
  const subagents = () => Object.entries(props.state.subagents).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))

  return (
    <box flexDirection="column" gap={1}>
      <box flexDirection="column">
        <text fg={theme().text}>
          <b>{main() ? line(lead(main()!)) : 'No contract in force'}</b>
        </text>
        <Show when={main()} fallback={<text fg={theme().textMuted}>{`Run ${NO_CONTRACT_HINT} to ground this session.`}</text>}>
          {(m) => <text fg={theme().textMuted}>{`Resolved turn ${m().turn} · ${ago(props.state.turn - m().turn)} · ${source(m())}`}</text>}
        </Show>
        <box flexDirection="row" flexWrap="wrap" columnGap={2} marginTop={1}>
          <For each={chips()}>{([label, color]) => <text fg={color}>{line(label)}</text>}</For>
        </box>
      </box>

      <Show when={main()}>
        {(m) => (
          <Section title="Contract">
            <Row label="Persona">
              <WithId {...named(details()?.personaName, details()?.personaId ?? m().ids.personaId)} />
            </Row>
            <Show when={directive().name}>
              <Row label="Directive">
                <WithId {...directive()} />
              </Row>
            </Show>
            <Show when={details()?.goal}>{(goal) => <Row label="Goal">{goal()}</Row>}</Show>
          </Section>
        )}
      </Show>
      <Show when={(details()?.steps.length ?? 0) > 0}>
        <StepsSection steps={details()!.steps} toggleKey="contract:steps" expanded={props.pane.expanded} toggle={props.actions.toggle} />
      </Show>

      <Show when={contract()} fallback={<Show when={main()}><Section title="Skills"><Muted text={notSeen(preview())} /></Section></Show>}>
        {(c) => (
          <Section title="Skills">
            <Row label="Kits">{list(c().kitIds)}</Row>
            <Row label="Allowed">{list(c().allowedSkillIds)}</Row>
            <Row label="Forbidden">{list(c().forbiddenSkillIds)}</Row>
            <Row label="Authorized">{list(c().authorizedSkillIds)}</Row>
            <Show when={!isClean(c())}>
              <Row label="Authorized">
                <text fg={c().isAuthorized ? theme().text : theme().error}>{`${c().isAuthorized}`}</text>
              </Row>
              <For each={problems(c())}>
                {(problem) => (
                  <box marginLeft={LABEL_WIDTH}>
                    <text fg={theme().error}>{line(problem)}</text>
                  </box>
                )}
              </For>
            </Show>
            <Show when={read()}>
              <text fg={theme().textMuted}>Kits, skills, and scope: read by the pane from the CLI; the session did not resolve them.</text>
            </Show>
          </Section>
        )}
      </Show>

      <Show when={contract()?.scope}>
        {(scope) => (
          <Section title="Scope">
            <Row label="Mode">{scope().mode}</Row>
            <Show when={scope().projectRoot}>{(root) => <Row label="Project">{root()}</Row>}</Show>
            <Show when={scope().globalRoot}>{(root) => <Row label="Global">{root()}</Row>}</Show>
          </Section>
        )}
      </Show>

      <Section title="Enforcement">
        <Row label="State">
          <text fg={words().state[1]}>
            {line(words().state[0])}
            <Show when={enforcement().kind === 'advisory' && !props.manifestChanged}>
              <span style={{ fg: theme().textMuted }}> · no manifest installed</span>
            </Show>
          </text>
        </Row>
        <Show when={manifest()}>
          {(e) => (
            <>
              <Row label="Manifest">{e().manifestPath}</Row>
              <Show when={blocks()}>
                {(blocked) => (
                  <>
                    <Row label="Blocks">{blocked()}</Row>
                    <Row label="Checks">every tool call but OpenCode's read-only built-ins</Row>
                  </>
                )}
              </Show>
            </>
          )}
        </Show>
        <Row label="Drift check">
          <text fg={watching().isMuted ? theme().textMuted : theme().text}>
            {line(watching().text)}
            <Show when={!watching().isMuted}>
              <span style={{ fg: theme().textMuted }}> · from the handoff context</span>
            </Show>
          </text>
        </Row>
      </Section>

      <Show when={main()}>
        <Section title="Freshness">
          <Row label="Compactions">
            <text fg={props.state.compactions > 0 ? theme().warning : theme().textMuted}>
              {props.state.compactions > 0 ? `${props.state.compactions} · re-ground?` : '0'}
            </text>
          </Row>
        </Section>
      </Show>

      <Section title="Drift log">
        <Show when={props.state.drift.length > 0} fallback={<text fg={theme().textMuted}>No drift.</text>}>
          <For each={props.state.drift}>
            {(d) => (
              <text fg={theme().text}>
                <b>{line(d.tool)}</b>
                {' '}
                <span style={{ fg: d.kind === 'advisory' ? theme().warning : theme().error }}>{driftKind(d)}</span>
                <span style={{ fg: theme().textMuted }}>
                  {line(`${d.actionClass ? ` · ${d.actionClass}` : ''} · ${d.agentId !== undefined ? `subagent ${d.agentId}` : 'main'} · turn ${d.turn}`)}
                </span>
              </text>
            )}
          </For>
        </Show>
      </Section>

      <Show when={subagents().length > 0}>
        <Section title="Subagent contracts">
          <For each={subagents()}>
            {([id, r]) => (
              <text fg={theme().text}>
                <b>{line(id)}</b>
                {line(` ${lead(r)}`)}
                <span style={{ fg: theme().textMuted }}>{` · resolved turn ${r.turn} · ${source(r)}`}</span>
              </text>
            )}
          </For>
        </Section>
      </Show>

      <Show when={main()}>
        {(m) => (
          <box flexDirection="row">
            <Button label="Re-ground" disabled={!canUse(m().ids)} onPress={() => props.actions.reground()} />
          </box>
        )}
      </Show>
    </box>
  )
}

