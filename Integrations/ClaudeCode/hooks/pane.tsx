import type { PaneState, SessionState } from '../types'
import { contractView } from './views/contract'
import { libraryHome, libraryList } from './views/library'
import { parts, viewLabel } from './views/parts'
import type { El, PaneActions } from './views/parts'

export type { PaneActions }

/**
 * The `/pk` pane: a Contract | Library switch over the view the pane state names. The Contract view is the contract
 * in force; the Library views are the loaded library. Navigation is Buttons only, so every surface can navigate.
 */
export function paneTree(el: El, session: SessionState, pane: PaneState, columns: number, actions: PaneActions) {
  const { Box, Text, Button } = el
  const { backButton } = parts(el)
  const { view } = pane
  const isContract = view.kind === 'contract'

  const body = (() => {
    switch (view.kind) {
      case 'contract':
        return contractView(el, session, () => actions.reground())
      case 'library':
        return libraryHome(el, session, pane, actions)
      case 'list':
        return libraryList(el, view.of, session, pane, actions)
      default:
        // The detail views are drawn by their own task; until then, a way back.
        return [
          backButton(viewLabel(pane.back.at(-1) ?? { kind: 'library' }), () => actions.back()),
          <Text key="detail" dimColor>{`${view.kind} ${view.id}`}</Text>,
        ]
    }
  })()

  return (
    <Box key="pane" flexDirection="column" width={columns} gap={1}>
      <Box key="switch" flexDirection="row" columnGap={1}>
        <Button key="switch-contract" variant={isContract ? 'primary' : 'secondary'} onPress={() => actions.go({ kind: 'contract' })}>
          Contract
        </Button>
        <Button key="switch-library" variant={isContract ? 'secondary' : 'primary'} onPress={() => actions.go({ kind: 'library' })}>
          Library
        </Button>
      </Box>
      {body}
    </Box>
  )
}
