import { createMemo, For, Match, Show, Switch } from 'solid-js'
import type { Library, PaneState, Provenance, SessionState, Step, View } from '../../../../ClaudeCode/types'
import { usedBy } from '../../../../ClaudeCode/hooks/lib/libraryIndex.ts'
import { previewKey } from '../../../../ClaudeCode/hooks/lib/runner.ts'
import { sanitizeText } from '../text.ts'
import { Button, line, Muted, Row, ScopeBadge, Section, StepsSection, UseControl, useUi } from './library.tsx'
import type { PaneActions } from './library.tsx'

// A port of the Claude Code mod's `views/detail.tsx`: a persona, session, directive, kit or skill from the loaded
// library. Library text is drawn through `sanitizeLine` (`line`), multi-line text through `sanitizeText`.

export type Detail = Extract<View, { id: string }>
type Kind = Detail['kind']

const COLLAPSED = 3
const unique = (ids: readonly string[]) => [...new Set(ids)]
const joinPath = (root: string | undefined, path: string) => (root === undefined ? path : `${root.replace(/\/$/, '')}/${path}`)

type Context = { library: Library; pane: PaneState; session: SessionState; actions: PaneActions }

/** Display names by kind and id; a session is called by its id. */
const namesOf = (library: Library): Record<Kind, Map<string, string>> => ({
  persona: new Map(library.personas.map((p) => [p.id, p.entity.name])),
  session: new Map(library.sessions.map((s) => [s.id, s.id])),
  directive: new Map(library.directives.map((d) => [d.id, d.entity.title])),
  kit: new Map(library.kits.map((k) => [k.id, k.entity.name])),
  skill: new Map(library.skills.map((s) => [s.id, s.entity.name])),
})

/** A name that opens its detail view; an id the library lacks is its raw text, with nothing to open. */
function Ref(props: { c: Context; kind: Kind; id: string }) {
  const { theme } = useUi()
  const name = () => namesOf(props.c.library)[props.kind].get(props.id)
  return (
    <Show when={name()} fallback={<text fg={theme().text}>{line(props.id)}</text>}>
      {(label) => <Button link label={label()} onPress={() => props.c.actions.go({ kind: props.kind, id: props.id } as View)} />}
    </Show>
  )
}

function Refs(props: { c: Context; kind: Kind; ids: readonly string[] }) {
  return (
    <Show when={props.ids.length > 0} fallback={<Muted text="none" />}>
      <box flexDirection="row" flexWrap="wrap" columnGap={2}>
        <For each={unique(props.ids)}>{(id) => <Ref c={props.c} kind={props.kind} id={id} />}</For>
      </box>
    </Show>
  )
}

/** The Skills row of a Boundaries section: what is allowed, then what is forbidden. */
function SkillsRow(props: { c: Context; allowed: readonly string[]; forbidden: readonly string[] }) {
  const { theme } = useUi()
  return (
    <Row label="Skills">
      <box flexDirection="column">
        <box flexDirection="row" flexWrap="wrap" columnGap={1}>
          <text fg={theme().textMuted}>allowed</text>
          <Refs c={props.c} kind="skill" ids={props.allowed} />
        </box>
        <box flexDirection="row" flexWrap="wrap" columnGap={1}>
          <text fg={theme().textMuted}>forbidden</text>
          <Refs c={props.c} kind="skill" ids={props.forbidden} />
        </box>
      </box>
    </Row>
  )
}

/** Three items and `… n more`; the whole list once its toggle is pressed. Nothing at all for an empty list. */
function Bullets(props: { c: Context; title: string; items: readonly string[]; viewKey: string; name: string }) {
  const { theme } = useUi()
  const key = () => `${props.viewKey}:${props.name}`
  const isOpen = () => props.c.pane.expanded.includes(key())
  const shown = () => (isOpen() ? props.items : props.items.slice(0, COLLAPSED))
  return (
    <Show when={props.items.length > 0}>
      <Section title={props.title}>
        <For each={shown()}>{(item) => <text fg={theme().text}>{line(`• ${item}`)}</text>}</For>
        <Show when={props.items.length > COLLAPSED}>
          <box flexDirection="row">
            <Button label={isOpen() ? 'Show fewer' : `… ${props.items.length - COLLAPSED} more`} onPress={() => props.c.actions.toggle(key())} />
          </box>
        </Show>
      </Section>
    </Show>
  )
}

/** The title, `<id> · <kind>` with the scope badge, where the file lives, and, for an override, the shadowed one. */
function Header(props: { c: Context; kind: Kind; title: string; entity: Provenance }) {
  const { theme } = useUi()
  const shadowedRoot = () => (props.entity.shadows === null ? undefined : props.c.library.scopes[props.entity.shadows])
  return (
    <box flexDirection="column">
      <text fg={theme().text}>
        <b>{line(props.title)}</b>
      </text>
      <box flexDirection="row" flexWrap="wrap" columnGap={1}>
        <Muted text={`${props.entity.id} · ${props.kind}`} />
        <ScopeBadge scope={props.entity.scope} shadows={props.entity.shadows} />
      </box>
      <Muted text={joinPath(props.c.library.scopes[props.entity.scope], props.entity.path)} />
      <Show when={props.entity.shadows !== null && props.entity.shadowedPath}>
        {(shadowedPath) => <Row label="Shadowed">{joinPath(shadowedRoot(), shadowedPath())}</Row>}
      </Show>
    </box>
  )
}

function PersonaDetail(props: { c: Context; id: string }) {
  const { theme } = useUi()
  const p = () => props.c.library.personas.find((x) => x.id === props.id)!
  const entity = () => p().entity
  const titles = createMemo(() => new Map(props.c.library.directives.map((d) => [d.id, d.entity.title])))
  const sessions = createMemo(() =>
    (usedBy(props.c.library).sessionsByPersona[props.id] ?? []).flatMap((sessionId) => props.c.library.sessions.filter((s) => s.id === sessionId)),
  )
  const key = () => `persona:${props.id}`
  const inForce = () => props.c.session.main?.ids.sessionId
  return (
    <box flexDirection="column" gap={1}>
      <Header c={props.c} kind="persona" title={entity().name} entity={p()} />
      <Show when={entity().summary !== ''}>
        <text fg={theme().text}>{line(entity().summary)}</text>
      </Show>
      <Section title="Talk to them via">
        <Show when={sessions().length > 0} fallback={<Muted text="No session uses this persona yet." />}>
          <For each={sessions()}>
            {(s) => (
              <box flexDirection="row" flexWrap="wrap" columnGap={1}>
                <Ref c={props.c} kind="session" id={s.id} />
                <Muted text={`· ${titles().get(s.directiveId) ?? s.directiveId}`} />
                <Show when={s.scope !== p().scope || s.shadows !== null}>
                  <ScopeBadge scope={s.scope} shadows={s.shadows} />
                </Show>
                <UseControl sessionId={s.id} inForceSessionId={inForce()} use={props.c.actions.use} />
              </box>
            )}
          </For>
        </Show>
      </Section>
      <Bullets c={props.c} title="Responsibilities" items={entity().responsibilities} viewKey={key()} name="responsibilities" />
      <Bullets c={props.c} title="Non-goals" items={entity().nonGoals} viewKey={key()} name="non-goals" />
      <Section title="Boundaries">
        <Row label="Kits">
          <Refs c={props.c} kind="kit" ids={entity().defaultKitIds} />
        </Row>
        <SkillsRow c={props.c} allowed={entity().allowedSkillIds} forbidden={entity().forbiddenSkillIds} />
        <Show when={(entity().forbiddenCapabilities?.length ?? 0) > 0}>
          <Row label="Never">{entity().forbiddenCapabilities!.join(', ')}</Row>
        </Show>
      </Section>
    </box>
  )
}

function SessionDetail(props: { c: Context; id: string }) {
  const { theme } = useUi()
  const s = () => props.c.library.sessions.find((x) => x.id === props.id)!
  const preview = () => props.c.pane.previews[previewKey({ sessionId: props.id })]
  const inForce = () => props.c.session.main?.ids.sessionId
  const loaded = () => {
    const current = preview()
    return current?.kind === 'loaded' ? current : undefined
  }
  const failed = () => {
    const current = preview()
    return current?.kind === 'failed' ? current : undefined
  }
  return (
    <box flexDirection="column" gap={1}>
      <Header c={props.c} kind="session" title={props.id} entity={s()} />
      <text fg={theme().textMuted}>{inForce() === props.id ? 'in force' : 'preview, not in force'}</text>
      <box flexDirection="row">
        <UseControl sessionId={props.id} inForceSessionId={inForce()} use={props.c.actions.use} />
      </box>
      <box flexDirection="column">
        <Row label="Persona">
          <Ref c={props.c} kind="persona" id={s().personaId} />
        </Row>
        <Row label="Directive">
          <Ref c={props.c} kind="directive" id={s().directiveId} />
        </Row>
      </box>
      <Switch fallback={<text fg={theme().textMuted}>Loading contract…</text>}>
        <Match when={failed()}>
          {(f) => <text fg={theme().error}>{line(`Couldn't load the contract: ${f().message}`)}</text>}
        </Match>
        <Match when={loaded()}>
          {(p) => (
            <>
              <Show when={p().details?.goal !== undefined}>
                <Section title="Goal">
                  <text fg={theme().text}>{sanitizeText(p().details!.goal!)}</text>
                </Section>
              </Show>
              <Show when={(p().details?.steps.length ?? 0) > 0}>
                <StepsSection
                  steps={p().details!.steps}
                  toggleKey={`session:${props.id}:steps`}
                  expanded={props.c.pane.expanded}
                  toggle={props.c.actions.toggle}
                />
              </Show>
              <Show when={p().contract}>
                {(contract) => (
                  <Section title="Boundaries">
                    <Row label="Kits">
                      <Refs c={props.c} kind="kit" ids={contract().kitIds} />
                    </Row>
                    <SkillsRow c={props.c} allowed={contract().allowedSkillIds} forbidden={contract().forbiddenSkillIds} />
                  </Section>
                )}
              </Show>
            </>
          )}
        </Match>
      </Switch>
    </box>
  )
}

function DirectiveDetail(props: { c: Context; id: string }) {
  const { theme } = useUi()
  const d = () => props.c.library.directives.find((x) => x.id === props.id)!
  const entity = () => d().entity
  const steps = createMemo((): Step[] => entity().steps.map((step) => ({ text: step.text, isStop: step.requiresReview === true })))
  const key = () => `directive:${props.id}`
  const sessions = () => usedBy(props.c.library).sessionsByDirective[props.id] ?? []
  return (
    <box flexDirection="column" gap={1}>
      <Header c={props.c} kind="directive" title={entity().title} entity={d()} />
      <Show when={entity().goal !== ''}>
        <Section title="Goal">
          <text fg={theme().text}>{sanitizeText(entity().goal)}</text>
        </Section>
      </Show>
      <Show when={steps().length > 0}>
        <StepsSection steps={steps()} toggleKey={`${key()}:steps`} expanded={props.c.pane.expanded} toggle={props.c.actions.toggle} />
      </Show>
      <Bullets c={props.c} title="Acceptance" items={entity().acceptanceCriteria} viewKey={key()} name="acceptance" />
      <Show when={entity().requiresSkillIds.length > 0}>
        <Section title="Requires">
          <Row label="Skills">
            <Refs c={props.c} kind="skill" ids={entity().requiresSkillIds} />
          </Row>
        </Section>
      </Show>
      <Section title="Used by">
        <Row label="Sessions">
          <Refs c={props.c} kind="session" ids={sessions()} />
        </Row>
      </Section>
    </box>
  )
}

function KitDetail(props: { c: Context; id: string }) {
  const { theme } = useUi()
  const k = () => props.c.library.kits.find((x) => x.id === props.id)!
  const entity = () => k().entity
  const index = createMemo(() => usedBy(props.c.library))
  return (
    <box flexDirection="column" gap={1}>
      <Header c={props.c} kind="kit" title={entity().name} entity={k()} />
      <Show when={entity().summary !== ''}>
        <text fg={theme().text}>{line(entity().summary)}</text>
      </Show>
      <Section title="Skills">
        <Refs c={props.c} kind="skill" ids={entity().skillIds ?? []} />
      </Section>
      <Section title="Used by">
        <Row label="Personas">
          <Refs c={props.c} kind="persona" ids={index().personasByKit[props.id] ?? []} />
        </Row>
        <Row label="Sessions">
          <Refs c={props.c} kind="session" ids={index().sessionsByKit[props.id] ?? []} />
        </Row>
      </Section>
    </box>
  )
}

function SkillDetail(props: { c: Context; id: string }) {
  const { theme } = useUi()
  const s = () => props.c.library.skills.find((x) => x.id === props.id)!
  const entity = () => s().entity
  const index = createMemo(() => usedBy(props.c.library))
  return (
    <box flexDirection="column" gap={1}>
      <Header c={props.c} kind="skill" title={entity().name} entity={s()} />
      <Show when={entity().description !== ''}>
        <text fg={theme().text}>{line(entity().description)}</text>
      </Show>
      <Section title="Used by">
        <Row label="Kits">
          <Refs c={props.c} kind="kit" ids={index().kitsBySkill[props.id] ?? []} />
        </Row>
        <Row label="Personas">
          <Refs c={props.c} kind="persona" ids={index().personasBySkill[props.id] ?? []} />
        </Row>
      </Section>
    </box>
  )
}

/**
 * A persona, session, directive, kit or skill from the loaded library. A session's contract is the preview the route
 * read for it, never the session in force. A reference the library lacks is drawn as its raw id, with nothing to open.
 */
export function DetailView(props: { view: Detail; pane: PaneState; session: SessionState; actions: PaneActions }) {
  const { theme } = useUi()
  const library = createMemo(() => (props.pane.library.kind === 'loaded' ? props.pane.library.library : undefined))
  const exists = () => {
    const lib = library()
    if (lib === undefined) return false
    const collections: Record<Kind, readonly { id: string }[]> = {
      persona: lib.personas,
      session: lib.sessions,
      directive: lib.directives,
      kit: lib.kits,
      skill: lib.skills,
    }
    return collections[props.view.kind].some((x) => x.id === props.view.id)
  }
  return (
    <Show when={library()} fallback={<text fg={theme().textMuted}>The library isn't loaded.</text>}>
      {(lib) => {
        const c: Context = {
          get library() {
            return lib()
          },
          get pane() {
            return props.pane
          },
          get session() {
            return props.session
          },
          get actions() {
            return props.actions
          },
        }
        return (
          <Show when={exists()} fallback={<text fg={theme().text}>{line(`${props.view.kind} ${props.view.id} isn't in the library.`)}</text>}>
            <Switch>
              <Match when={props.view.kind === 'persona'}>
                <PersonaDetail c={c} id={props.view.id} />
              </Match>
              <Match when={props.view.kind === 'session'}>
                <SessionDetail c={c} id={props.view.id} />
              </Match>
              <Match when={props.view.kind === 'directive'}>
                <DirectiveDetail c={c} id={props.view.id} />
              </Match>
              <Match when={props.view.kind === 'kit'}>
                <KitDetail c={c} id={props.view.id} />
              </Match>
              <Match when={props.view.kind === 'skill'}>
                <SkillDetail c={c} id={props.view.id} />
              </Match>
            </Switch>
          </Show>
        )
      }}
    </Show>
  )
}
