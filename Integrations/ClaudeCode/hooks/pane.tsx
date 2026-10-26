import type { Elements } from 'claude-code'

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

const named = (name: string | undefined, id: string | undefined) => (name && id && name !== id ? `${name} (${id})` : (name ?? id))

const isClean = (c: Contract) =>
  c.isAuthorized &&
  c.failureReasons.length === 0 &&
  c.unauthorizedRequestedSkillIds.length === 0 &&
  c.unauthorizedRequiredSkillIds.length === 0 &&
  c.undeclaredRequestedSkillIds.length === 0

function enforcementLines(enforcement: Enforcement, judged: Resolution | undefined): string[] {
  if (enforcement.kind === 'advisory') {
    const details = judged?.details
    const advisory = !details
      ? 'off until an export is seen'
      : details.deniedActionClasses.length
        ? `${details.deniedActionClasses.join(', ')} (from the export)`
        : 'nothing denied by the export'
    return ['Enforcement: advisory (no PersonaKit hook installed)', `Advisory drift: ${advisory}`]
  }
  const other = enforcement.ids.sessionId ?? enforcement.ids.personaId ?? 'another contract'
  const state = enforcement.manifestUnreadable
    ? '⚠ manifest unreadable'
    : enforcement.kind === 'enforced'
      ? 'enforced'
      : `⚠ enforcing ${other}`
  return [
    `Enforcement: ${state}`,
    `Manifest: ${enforcement.manifestPath}`,
    `Class-1 checks: ${enforcement.deniedActionClasses.length ? `deny ${enforcement.deniedActionClasses.join(', ')}` : 'none'}`,
    `Routed tools: ${list(enforcement.matcherTools)}`,
    'Advisory drift: off while a PersonaKit hook is installed',
  ]
}

function driftRow(d: DriftEvent): string {
  const what = d.actionClass ? `${d.tool} (${d.actionClass})` : d.tool
  const kind = d.kind === 'reground-blocked' ? 're-ground blocked' : d.kind
  return `${what} · ${kind} · ${d.agentId !== undefined ? `subagent ${d.agentId}` : 'main'} · turn ${d.turn}`
}

/**
 * The `/pk` pane: header, contract, scope, enforcement, freshness, drift log, subagent contracts,
 * actions, in the spec's order. Sized to the pane's body; Re-ground only while a contract is in force.
 */
export function paneTree({ Box, Text, Button }: El, state: SessionState, columns: number, reground: () => void) {
  const { main } = state
  const heading = (title: string) => (
    <Box marginTop={1}>
      <Text bold>{title}</Text>
    </Box>
  )
  const lines = (texts: readonly string[]) => texts.map((t) => <Text>{t}</Text>)

  const contract = main?.contract
  const details = main?.details
  const contractLines: string[] = []
  if (main) {
    contractLines.push(`Persona: ${named(details?.personaName, details?.personaId ?? main.ids.personaId) ?? 'unknown'}`)
    const directive = named(details?.directiveTitle, details?.directiveId ?? main.ids.directiveId)
    if (directive) contractLines.push(`Directive: ${directive}`)
    if (details?.goal) contractLines.push(`Goal: ${details.goal}`)
  }
  const steps = details?.steps ?? []
  // The marker sits in its own fixed-width box so a wrapped step's later lines align with its text.
  const markerWidth = `■ ${steps.length}. `.length
  const stepRows = steps.map((s, i) => (
    <Box key={`step-${i + 1}`} flexDirection="row">
      <Box width={markerWidth} flexShrink={0}>
        <Text>{s.isStop ? `■ ${i + 1}.` : `  ${i + 1}.`}</Text>
      </Box>
      <Box flexGrow={1} flexShrink={1}>
        <Text>{s.isStop ? `${s.text} (stop for review)` : s.text}</Text>
      </Box>
    </Box>
  ))
  const skillLines = contract
    ? [
        `Kits: ${list(contract.kitIds)}`,
        `Allowed skills: ${list(contract.allowedSkillIds)}`,
        `Forbidden skills: ${list(contract.forbiddenSkillIds)}`,
        `Authorized skills: ${list(contract.authorizedSkillIds)}`,
      ]
    : main
      ? ['Kits, skills, and scope: not seen (no contract JSON resolved)']
      : []
  const authLines =
    contract && !isClean(contract)
      ? [
          `Authorized: ${contract.isAuthorized}`,
          ...contract.failureReasons.map((r) => `  ${r}`),
          ...(contract.unauthorizedRequestedSkillIds.length ? [`Unauthorized requested: ${list(contract.unauthorizedRequestedSkillIds)}`] : []),
          ...(contract.unauthorizedRequiredSkillIds.length ? [`Unauthorized required: ${list(contract.unauthorizedRequiredSkillIds)}`] : []),
          ...(contract.undeclaredRequestedSkillIds.length ? [`Undeclared requested: ${list(contract.undeclaredRequestedSkillIds)}`] : []),
        ]
      : []
  const scope = contract?.scope
  const subagents = Object.keys(state.subagents).sort()

  return (
    <Box key="pane" flexDirection="column" width={columns}>
      {main ? (
        <Text bold>{`${lead(main)} · resolved turn ${main.turn} (${ago(state.turn - main.turn)}) · ${source(main)}`}</Text>
      ) : (
        <Text>{'No contract in force. Run /pk use <session> to ground this session.'}</Text>
      )}

      {main && heading('Contract')}
      {lines(contractLines)}
      {steps.length > 0 && <Text>Steps:</Text>}
      {stepRows}
      {lines(skillLines)}
      {lines(authLines)}

      {scope && heading('Scope')}
      {scope && lines([`Mode: ${scope.mode}`, ...(scope.projectRoot ? [`Project root: ${scope.projectRoot}`] : []), ...(scope.globalRoot ? [`Global root: ${scope.globalRoot}`] : [])])}

      {heading('Enforcement')}
      {lines(enforcementLines(state.enforcement, main))}

      {main && heading('Freshness')}
      {main && <Text>{`Compactions since resolve: ${state.compactions}${state.compactions > 0 ? ' · re-ground?' : ''}`}</Text>}

      {heading('Drift log')}
      {state.drift.length === 0 ? <Text dimColor>No drift.</Text> : lines(state.drift.map(driftRow))}

      {subagents.length > 0 && heading('Subagent contracts')}
      {lines(subagents.map((id) => `${id}: ${lead(state.subagents[id])} · resolved turn ${state.subagents[id].turn} · ${source(state.subagents[id])}`))}

      {main && heading('Actions')}
      {main && (
        <Box>
          <Button key="reground" onPress={() => reground()}>
            Re-ground
          </Button>
        </Box>
      )}
    </Box>
  )
}
