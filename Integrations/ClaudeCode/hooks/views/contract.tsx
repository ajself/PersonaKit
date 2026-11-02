import type { Color, RenderChildren } from 'claude-code'

import type { Contract, DriftEvent, Enforcement, PaneState, Preview, Resolution, SessionState } from '../../types'
import { previewKey } from '../lib/runner'
import { countsFromGrounding, driftSinceGrounding } from '../lib/session'
import { LABEL_WIDTH, parts } from './parts'
import type { El, PaneActions } from './parts'

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
const named = (name: string | undefined, id: string | undefined) =>
  name && id && name !== id ? { name, id } : { name: name ?? id }

const isClean = (c: Contract) =>
  c.isAuthorized &&
  c.failureReasons.length === 0 &&
  c.unauthorizedRequestedSkillIds.length === 0 &&
  c.unauthorizedRequiredSkillIds.length === 0 &&
  c.undeclaredRequestedSkillIds.length === 0

/** Why the Skills section is empty: the pane is reading, couldn't, or there was nothing to read. */
const notSeen = (preview: Preview | undefined) =>
  preview?.kind === 'loading'
    ? 'Kits, skills, and scope: reading from the CLI…'
    : preview?.kind === 'failed'
      ? `Kits, skills, and scope: not seen (the pane couldn't read them: ${preview.message})`
      : 'Kits, skills, and scope: not seen (no contract JSON resolved)'

/** A drift event's kind in words: a call the contract forbids ran unblocked, was blocked, or a re-ground was blocked. */
const driftKind = (d: DriftEvent) => (d.kind === 'reground-blocked' ? 're-ground blocked' : d.kind === 'advisory' ? 'not blocked' : 'blocked')

/** The tools the hook checks: its matcher entries, or "every tool call" for `.*` or no matcher, which match any tool. */
const checked = (matcherTools: readonly string[]) =>
  matcherTools.length === 0 || matcherTools.includes('.*') ? 'every tool call' : list(matcherTools)

/** What the hook blocks: the manifest's denied classes, or every call it checks while it can't read the manifest. */
const blocks = (e: Exclude<Enforcement, { kind: 'advisory' }>) => (e.manifestUnreadable ? 'every tool call it checks' : list(e.deniedActionClasses))

/**
 * The Contract view: header with status chips, then contract, skills, scope, enforcement, freshness,
 * drift log, subagent contracts, and Re-ground, in the spec's order. Labels are muted in a fixed
 * column so values align and wrap inside their own column; status reads through theme colors only,
 * so light and dark follow the person's theme. Re-ground only while a contract is in force.
 *
 * A resolution with export details but no contract JSON is filled in from the preview the pane read for its ids
 * (`pane.previews`), display-only: the view reads it and runs nothing, and `main` is never touched.
 */
export function contractView(el: El, state: SessionState, pane: PaneState, actions: Pick<PaneActions, 'reground' | 'toggle'>): RenderChildren[] {
  const { Box, Text, Button } = el
  const { section, row, stepsSection } = parts(el)
  const { main, enforcement } = state
  const withId = ({ name, id }: { name?: string; id?: string }) => (
    <Text>
      {name ?? 'unknown'}
      {id && <Text dimColor>{` (${id})`}</Text>}
    </Text>
  )
  const path = (p: string) => <Text mono>{p}</Text>

  // Status chips: what the sections below say, at a glance. Advisory is the default, so it reads muted, as the status
  // line does; a hook for another contract is an error only once a contract is resolved for it to contradict.
  const enforcing = enforcement.kind === 'advisory' ? undefined : (enforcement.ids.sessionId ?? enforcement.ids.personaId ?? 'another contract')
  const enforcementChip: [string, Color] =
    enforcement.kind === 'advisory'
      ? ['● Advisory', 'inactive']
      : enforcement.manifestUnreadable
        ? ['● Manifest unreadable', 'error']
        : enforcement.kind === 'enforced'
          ? ['● Enforced', 'success']
          : [`● Enforcing ${enforcing}`, main ? 'error' : 'warning']
  // Counted as the status line counts, from the latest grounding; the drift log below keeps all of it.
  const since = driftSinceGrounding(state)
  const blocked = since.some((d) => d.kind !== 'advisory')
  const driftChip: [string, Color] =
    since.length === 0
      ? ['✓ No drift', 'success']
      : [`● ${since.length} drift${countsFromGrounding(state) ? ' since grounding' : ''}`, blocked ? 'error' : 'warning']
  const chips: [string, Color][] = [
    enforcementChip,
    ...(main && state.compactions > 0
      ? [[`● ${state.compactions} ${state.compactions === 1 ? 'compaction' : 'compactions'}`, 'warning'] as [string, Color]]
      : []),
    driftChip,
  ]

  const header = (
    <Box key="header" flexDirection="column">
      {main ? (
        <Text size="title" weight="semibold">
          {lead(main)}
        </Text>
      ) : (
        <Text size="title" weight="semibold">
          No contract in force
        </Text>
      )}
      {main ? (
        <Text size="caption" dimColor>{`Resolved turn ${main.turn} · ${ago(state.turn - main.turn)} · ${source(main)}`}</Text>
      ) : (
        <Text size="caption" dimColor>
          {'Run /pk use with a PersonaKit session id to ground this session.'}
        </Text>
      )}
      <Box key="chips" flexDirection="row" flexWrap="wrap" columnGap={2} marginTop={1}>
        {chips.map(([label, color]) => (
          <Text size="caption" color={color}>
            {label}
          </Text>
        ))}
      </Box>
    </Box>
  )

  const preview = main?.contract || !main?.details ? undefined : pane.previews[previewKey(main.ids)]
  const read = preview?.kind === 'loaded' ? preview.contract : undefined
  const contract = main?.contract ?? read
  const details = main?.details
  const steps = details?.steps ?? []
  const directive = named(details?.directiveTitle, details?.directiveId ?? main?.ids.directiveId)

  const contractSection =
    main &&
    section(
      'Contract',
      row('Persona', withId(named(details?.personaName, details?.personaId ?? main.ids.personaId))),
      directive.name && row('Directive', withId(directive)),
      details?.goal && row('Goal', details.goal),
    )
  const stepsBlock = steps.length > 0 && stepsSection(steps, 'contract:steps', pane.expanded, actions.toggle)

  const authRows =
    contract && !isClean(contract)
      ? [
          row(
            'Authorized',
            <Text color={contract.isAuthorized ? 'text' : 'error'}>{`${contract.isAuthorized}`}</Text>,
          ),
          ...[
            ...contract.failureReasons,
            ...(contract.unauthorizedRequestedSkillIds.length ? [`Unauthorized requested: ${list(contract.unauthorizedRequestedSkillIds)}`] : []),
            ...(contract.unauthorizedRequiredSkillIds.length ? [`Unauthorized required: ${list(contract.unauthorizedRequiredSkillIds)}`] : []),
            ...(contract.undeclaredRequestedSkillIds.length ? [`Undeclared requested: ${list(contract.undeclaredRequestedSkillIds)}`] : []),
          ].map((problem, i) => (
            <Box key={`problem-${i}`} marginLeft={LABEL_WIDTH}>
              <Text color="error">{problem}</Text>
            </Box>
          )),
        ]
      : []
  const skillsSection = contract
    ? section(
        'Skills',
        row('Kits', list(contract.kitIds)),
        row('Allowed', list(contract.allowedSkillIds)),
        row('Forbidden', list(contract.forbiddenSkillIds)),
        row('Authorized', list(contract.authorizedSkillIds)),
        ...authRows,
        read && (
          <Text key="read-by-pane" size="caption" dimColor>
            Kits, skills, and scope: read by the pane from the CLI; the session did not resolve them.
          </Text>
        ),
      )
    : main && section('Skills', <Text dimColor>{notSeen(preview)}</Text>)

  const scope = contract?.scope
  const scopeSection =
    scope &&
    section(
      'Scope',
      row('Mode', scope.mode),
      scope.projectRoot && row('Project', path(scope.projectRoot)),
      scope.globalRoot && row('Global', path(scope.globalRoot)),
    )

  const watching = (() => {
    if (enforcement.kind !== 'advisory') return <Text dimColor>Off while a PersonaKit hook is installed</Text>
    if (!details) return <Text dimColor>Off until handoff context is seen</Text>
    if (!details.deniedActionClasses.length) return <Text dimColor>Nothing denied by the handoff context</Text>
    return (
      <Text>
        {details.deniedActionClasses.join(', ')}
        <Text dimColor> · from the handoff context</Text>
      </Text>
    )
  })()
  const enforcementSection =
    enforcement.kind === 'advisory'
      ? section(
          'Enforcement',
          row(
            'State',
            <Text dimColor>Advisory · no hook installed</Text>,
          ),
          row('Drift check', watching),
        )
      : section(
          'Enforcement',
          row(
            'State',
            <Text color={enforcementChip[1]}>
              {enforcement.manifestUnreadable
                ? '⚠ Manifest unreadable'
                : enforcement.kind === 'enforced'
                  ? 'Enforced'
                  : `⚠ Enforcing ${enforcing}`}
            </Text>,
          ),
          row('Manifest', path(enforcement.manifestPath)),
          row('Blocks', blocks(enforcement)),
          row('Checks', checked(enforcement.matcherTools)),
          row('Drift check', watching),
        )

  const freshnessSection =
    main &&
    section(
      'Freshness',
      row(
        'Compactions',
        state.compactions > 0 ? <Text color="warning">{`${state.compactions} · re-ground?`}</Text> : <Text dimColor>0</Text>,
      ),
    )

  const driftSection = section(
    'Drift log',
    state.drift.length === 0 ? (
      <Text dimColor>No drift.</Text>
    ) : (
      state.drift.map((d, i) => (
        <Box key={`drift-${i}`}>
          <Text>
            <Text weight="semibold">{d.tool}</Text>
            {' '}
            <Text color={d.kind === 'advisory' ? 'warning' : 'error'}>{driftKind(d)}</Text>
            <Text dimColor>{`${d.actionClass ? ` · ${d.actionClass}` : ''} · ${d.agentId !== undefined ? `subagent ${d.agentId}` : 'main'} · turn ${d.turn}`}</Text>
          </Text>
        </Box>
      ))
    ),
  )

  const subagents = Object.entries(state.subagents).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
  const subagentSection =
    subagents.length > 0 &&
    section(
      'Subagent contracts',
      subagents.map(([id, r]) => (
        <Box key={`subagent-${id}`}>
          <Text>
            <Text weight="semibold">{id}</Text>
            {` ${lead(r)}`}
            <Text dimColor>{` · resolved turn ${r.turn} · ${source(r)}`}</Text>
          </Text>
        </Box>
      )),
    )

  return [
    header,
    contractSection,
    stepsBlock,
    skillsSection,
    scopeSection,
    enforcementSection,
    freshnessSection,
    driftSection,
    subagentSection,
    main && (
      <Box key="actions">
        <Button key="reground" variant="primary" onPress={() => actions.reground()}>
          Re-ground
        </Button>
      </Box>
    ),
  ]
}
