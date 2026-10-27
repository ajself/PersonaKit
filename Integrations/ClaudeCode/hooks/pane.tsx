import type { Color, Elements, RenderChildren } from 'claude-code'

import type { Contract, DriftEvent, Enforcement, Resolution, SessionState } from '../types'

type El = Pick<Elements['terminal'], 'Box' | 'Text' | 'Button'>

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

/** The label column's width, in cells: the longest label ("Compactions") and a space. */
const LABEL_WIDTH = 12

const driftKind = (d: DriftEvent) => (d.kind === 'reground-blocked' ? 're-ground blocked' : d.kind)

/**
 * The `/pk` pane: header with status chips, then contract, skills, scope, enforcement, freshness,
 * drift log, subagent contracts, and Re-ground, in the spec's order. Labels are muted in a fixed
 * column so values align and wrap inside their own column; status reads through theme colors only,
 * so light and dark follow the person's theme. Re-ground only while a contract is in force.
 */
export function paneTree({ Box, Text, Button }: El, state: SessionState, columns: number, reground: () => void) {
  const { main, enforcement } = state

  const section = (title: string, ...rows: RenderChildren[]) => (
    <Box key={`section-${title}`} flexDirection="column">
      <Text size="caption" weight="semibold" dimColor>
        {title.toUpperCase()}
      </Text>
      {rows}
    </Box>
  )
  const row = (label: string, value: RenderChildren) => (
    <Box key={`row-${label}`} flexDirection="row">
      <Box width={LABEL_WIDTH} flexShrink={0}>
        <Text dimColor>{label}</Text>
      </Box>
      <Box flexDirection="column" flexGrow={1} flexShrink={1}>
        {typeof value === 'string' ? <Text>{value}</Text> : value}
      </Box>
    </Box>
  )
  const withId = ({ name, id }: { name?: string; id?: string }) => (
    <Text>
      {name ?? 'unknown'}
      {id && <Text dimColor>{` (${id})`}</Text>}
    </Text>
  )
  const path = (p: string) => <Text mono>{p}</Text>

  // Status chips: what the sections below say, at a glance.
  const enforcementChip: [string, Color] =
    enforcement.kind === 'advisory'
      ? ['● Advisory', 'warning']
      : enforcement.manifestUnreadable
        ? ['● Manifest unreadable', 'error']
        : enforcement.kind === 'enforced'
          ? ['● Enforced', 'success']
          : ['● Enforcing another contract', 'error']
  const blocked = state.drift.some((d) => d.kind !== 'advisory')
  const driftChip: [string, Color] =
    state.drift.length === 0
      ? ['✓ No drift', 'success']
      : [`● ${state.drift.length} drift`, blocked ? 'error' : 'warning']
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
          {'Run /pk use <session> to ground this session.'}
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

  const contract = main?.contract
  const details = main?.details
  const steps = details?.steps ?? []
  // The number sits in its own fixed-width box so a wrapped step's later lines align with its text.
  const numberWidth = `${steps.length}`.length + 2
  const stepRows = steps.map((s, i) => (
    <Box key={`step-${i + 1}`} flexDirection="row">
      <Box width={numberWidth} flexShrink={0}>
        <Text dimColor tabular>{`${i + 1}`}</Text>
      </Box>
      <Box flexDirection="column" flexGrow={1} flexShrink={1}>
        <Text>{s.text}</Text>
        {s.isStop && <Text color="warning">⏸ Stop for review</Text>}
      </Box>
    </Box>
  ))
  const directive = named(details?.directiveTitle, details?.directiveId ?? main?.ids.directiveId)

  const contractSection =
    main &&
    section(
      'Contract',
      row('Persona', withId(named(details?.personaName, details?.personaId ?? main.ids.personaId))),
      directive.name && row('Directive', withId(directive)),
      details?.goal && row('Goal', details.goal),
      steps.length > 0 && row('Steps', stepRows),
    )

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
      )
    : main && section('Skills', <Text dimColor>Kits, skills, and scope: not seen (no contract JSON resolved)</Text>)

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
    if (!details) return <Text dimColor>Off until an export is seen</Text>
    if (!details.deniedActionClasses.length) return <Text dimColor>Nothing denied by the export</Text>
    return (
      <Text>
        {details.deniedActionClasses.join(', ')}
        <Text dimColor> · from the export</Text>
      </Text>
    )
  })()
  const enforcementSection =
    enforcement.kind === 'advisory'
      ? section(
          'Enforcement',
          row(
            'State',
            <Text color="warning">
              Advisory
              <Text dimColor> · no hook installed</Text>
            </Text>,
          ),
          row('Watching', watching),
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
                  : `⚠ Enforcing ${enforcement.ids.sessionId ?? enforcement.ids.personaId ?? 'another contract'}`}
            </Text>,
          ),
          row('Manifest', path(enforcement.manifestPath)),
          row('Class-1', enforcement.deniedActionClasses.length ? `deny ${enforcement.deniedActionClasses.join(', ')}` : 'none'),
          row('Routed', list(enforcement.matcherTools)),
          row('Watching', watching),
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

  return (
    <Box key="pane" flexDirection="column" width={columns} gap={1}>
      {header}
      {contractSection}
      {skillsSection}
      {scopeSection}
      {enforcementSection}
      {freshnessSection}
      {driftSection}
      {subagentSection}
      {main && (
        <Box key="actions">
          <Button key="reground" variant="primary" onPress={() => reground()}>
            Re-ground
          </Button>
        </Box>
      )}
    </Box>
  )
}
