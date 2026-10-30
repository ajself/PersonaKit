import type { TuiPluginApi } from '@opencode-ai/plugin/tui'
import type { RGBA } from '@opentui/core'
import { For, Show } from 'solid-js'
import type { DriftEvent, Enforcement, Resolution, SessionState } from '../../../../ClaudeCode/types'
import { sanitizeLine, sanitizeText } from '../text.ts'
import { MANIFEST_CHANGED } from './chip.tsx'

/** The label column's width, in cells: the longest label ("Compactions") and a space. */
const LABEL_WIDTH = 12
const DRIFT_SHOWN = 5

type Theme = TuiPluginApi['theme']['current']

const list = (ids: readonly string[]) => (ids.length ? ids.join(', ') : 'none')

/** The enforcement row: the status line's words, and the theme color they read in. */
function enforcementRow(enforcement: Enforcement, manifestChanged: boolean, theme: Theme): [string, RGBA] {
  if (manifestChanged) return [MANIFEST_CHANGED, theme.warning]
  if (enforcement.kind === 'advisory') return ['advisory', theme.textMuted]
  if (enforcement.pluginMissing) return ['⚠ manifest present · plugin not loaded', theme.warning]
  if (enforcement.manifestUnreadable) return ['⚠ enforcement manifest unreadable', theme.error]
  if (enforcement.kind === 'enforced') return ['enforced', theme.success]
  return [`⚠ enforcing ${enforcement.ids.sessionId ?? enforcement.ids.personaId ?? 'another contract'}`, theme.error]
}

/** Session id, else persona › directive: how the resolution is named. */
function lead({ ids, details }: Resolution): string {
  if (ids.sessionId) return ids.sessionId
  const persona = details?.personaName ?? ids.personaId ?? 'contract'
  const directive = details?.directiveTitle ?? ids.directiveId
  return directive ? `${persona} › ${directive}` : persona
}

const driftLine = (d: DriftEvent) =>
  `${d.tool} ${d.kind === 'reground-blocked' ? 're-ground blocked' : d.kind}${d.actionClass ? ` · ${d.actionClass}` : ''} · ${d.agentId !== undefined ? 'subagent' : 'main'} · turn ${d.turn}`

/** A muted label in a fixed column, its value wrapping in its own. */
function Row(props: { theme: Theme; label: string; value: string; color?: RGBA }) {
  return (
    <box flexDirection="row">
      <box width={LABEL_WIDTH} flexShrink={0}>
        <text fg={props.theme.textMuted}>{props.label}</text>
      </box>
      <box flexGrow={1} flexShrink={1}>
        <text fg={props.color ?? props.theme.text}>{props.value}</text>
      </box>
    </box>
  )
}

/**
 * The sidebar panel: the contract in force (persona, directive, steps with stop points, kits, skills), enforcement,
 * compactions and the latest drift. Library text is drawn safe: `sanitizeLine` for rows, `sanitizeText` for steps.
 * Re-ground shows only when `reground` is given, which the plugin does while the contract's ids can be used.
 */
export function Sidebar(props: { api: TuiPluginApi; state: SessionState; manifestChanged: boolean; reground: (() => void) | undefined }) {
  const theme = () => props.api.theme.current
  const main = () => props.state.main
  const enforcement = () => enforcementRow(props.state.enforcement, props.manifestChanged, theme())
  const drift = () => props.state.drift.slice(-DRIFT_SHOWN)
  return (
    <box flexDirection="column">
      <text fg={theme().text}>
        <b>PersonaKit</b>
      </text>
      <Show when={main()} fallback={<text fg={theme().textMuted}>◇ no contract · /pk-use to ground one</text>}>
        {(resolution) => {
          const details = () => resolution().details
          const contract = () => resolution().contract
          return (
            <box flexDirection="column">
              <text fg={theme().text}>{sanitizeLine(`◆ ${lead(resolution())}`)}</text>
              <Row
                theme={theme()}
                label="Persona"
                value={sanitizeLine(details()?.personaName ?? details()?.personaId ?? resolution().ids.personaId ?? 'unknown')}
              />
              <Show when={details()?.directiveTitle ?? details()?.directiveId ?? resolution().ids.directiveId}>
                {(directive) => <Row theme={theme()} label="Directive" value={sanitizeLine(directive())} />}
              </Show>
              <For each={details()?.steps ?? []}>
                {(step, i) => (
                  <box flexDirection="row">
                    <box width={LABEL_WIDTH} flexShrink={0}>
                      <text fg={theme().textMuted}>{i() === 0 ? 'Steps' : ''}</text>
                    </box>
                    <box flexGrow={1} flexShrink={1} flexDirection="row" flexWrap="wrap" columnGap={1}>
                      <text fg={theme().text}>{sanitizeText(`${i() + 1}. ${step.text}`)}</text>
                      <Show when={step.isStop}>
                        <text fg={theme().warning}>◆ stop</text>
                      </Show>
                    </box>
                  </box>
                )}
              </For>
              <Row theme={theme()} label="Kits" value={contract() ? sanitizeLine(list(contract()!.kitIds)) : 'not seen'} />
              <Row theme={theme()} label="Skills" value={contract() ? sanitizeLine(list(contract()!.authorizedSkillIds)) : 'not seen'} />
            </box>
          )
        }}
      </Show>
      <Row theme={theme()} label="Enforcement" value={sanitizeLine(enforcement()[0])} color={enforcement()[1]} />
      <Show when={main()}>
        <Row
          theme={theme()}
          label="Compactions"
          value={props.state.compactions > 0 ? `${props.state.compactions} · re-ground?` : '0'}
          color={props.state.compactions > 0 ? theme().warning : theme().textMuted}
        />
      </Show>
      <Show when={drift().length > 0}>
        <box flexDirection="column">
          <text fg={theme().textMuted}>{`Drift (${props.state.drift.length})`}</text>
          <For each={drift()}>
            {(d) => <text fg={d.kind === 'advisory' ? theme().warning : theme().error}>{sanitizeLine(driftLine(d))}</text>}
          </For>
        </box>
      </Show>
      <Show when={props.reground}>
        {(reground) => (
          <box onMouseUp={() => reground()()}>
            <text fg={theme().primary}>[ Re-ground ]</text>
          </box>
        )}
      </Show>
    </box>
  )
}
