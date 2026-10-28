import type { Elements, RenderChildren, RenderSurface } from 'claude-code'

import type { Scope, View } from '../../types'

/** The elements every view draws with, and the surface they draw on. `Input` is absent on mobile. */
export type El = Pick<Elements['terminal'], 'Box' | 'Text' | 'Button'> & {
  Input?: Elements['terminal']['Input']
  surface: RenderSurface
}

/**
 * The surfaces whose `Box` takes `borderStyle` (every surface's `BoxProps` does) and that can put a border around
 * inline text. The terminal's `Box` borders as a block, so a badge there would draw as three rows.
 */
const OUTLINED_SURFACES: readonly RenderSurface[] = ['desktop', 'mobile', 'vscode']

/** What the pane's controls do. Each is fire-and-forget: the handler reports its own failures. */
export type PaneActions = {
  go(view: View): void
  back(): void
  setFilter(text: string): void
  refresh(): void
  use(sessionId: string): void
  reground(): void
  toggle(key: string): void
}

/** The label column's width, in cells: the longest label ("Compactions") and a space. */
export const LABEL_WIDTH = 12

/** What a view is called on a Back button that returns to it. */
export function viewLabel(view: View): string {
  if (view.kind === 'contract') return 'Contract'
  if (view.kind === 'library') return 'Library'
  if (view.kind === 'list') return view.of === 'directives' ? 'Directives' : view.of === 'kits' ? 'Kits' : 'Skills'
  return view.id
}

/** `text` cut into runs, each case-insensitive occurrence of any of `words` its own run. The runs join back to `text`. */
export function highlightRuns(text: string, words: readonly string[]): { text: string; isMatch: boolean }[] {
  const needles = [...new Set(words.map((w) => w.toLowerCase()).filter((w) => w !== ''))].sort((a, b) => b.length - a.length)
  if (needles.length === 0) return [{ text, isMatch: false }]
  const pattern = new RegExp(needles.map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|'), 'gi')
  const runs: { text: string; isMatch: boolean }[] = []
  let at = 0
  for (const m of text.matchAll(pattern)) {
    if (m.index > at) runs.push({ text: text.slice(at, m.index), isMatch: false })
    runs.push({ text: m[0], isMatch: true })
    at = m.index + m[0].length
  }
  return at < text.length || runs.length === 0 ? [...runs, { text: text.slice(at), isMatch: false }] : runs
}

/** The pieces the views share, drawn with the surface's own elements. */
export function parts({ Box, Text, Button, surface }: El) {
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

  /**
   * The scope in words: `project`, `global`, or `project · overrides global`. The styling only reinforces the words:
   * project bold, global dim, an override in the warning color, and, where a surface can outline inline text, an
   * outline too. The types offer no dashed `borderStyle`, so both scopes use `round` and global's is muted.
   */
  const scopeBadge = (scope: Scope, shadows: Scope | null = null) => {
    const words = shadows === null ? scope : `${scope} · overrides ${shadows}`
    const text =
      shadows !== null ? (
        <Text color="warning">{words}</Text>
      ) : scope === 'project' ? (
        <Text bold>{words}</Text>
      ) : (
        <Text dimColor>{words}</Text>
      )
    return OUTLINED_SURFACES.includes(surface) ? (
      <Box borderStyle="round" borderDimColor={scope === 'global'} paddingX={1}>
        {text}
      </Box>
    ) : (
      text
    )
  }

  /** `text` with each match of `words` in its own semibold, colored `Text` run; the words read the same unstyled. */
  const highlighted = (text: string, words: readonly string[]) =>
    highlightRuns(text, words).map((run, i) =>
      run.isMatch ? (
        <Text key={`match-${i}`} weight="semibold" color="suggestion">
          {run.text}
        </Text>
      ) : (
        run.text
      ),
    )

  const backButton = (label: string, onPress: () => void) => (
    <Box key="back-row">
      <Button key="back" onPress={onPress}>
        {`‹ ${label}`}
      </Button>
    </Box>
  )

  return { section, row, scopeBadge, backButton, highlighted }
}
