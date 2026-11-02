import { expect, test } from 'claude-code/testing'

import { usePrompt } from './lib/prompts'

test('a session prompt names it and asks to resolve, export, and adopt it', async () => {
  const text = usePrompt({ sessionId: 's' })
  expect(text).toContain('`s`')
  expect(text).toContain('personakit_resolve_contract tool and then its personakit_export tool')
  expect(text).toContain('MCP')
  expect(text).toContain('`personakit contract --session=s` and then `personakit export --session=s`')
  expect(text).toContain('adopt')
  expect(text).not.toContain('--persona')
})

test('the CLI fallback names the configured personakitPath, quoted when it needs to be', async () => {
  expect(usePrompt({ sessionId: 's' }, '/opt/pk/bin/personakit')).toContain(
    '`/opt/pk/bin/personakit contract --session=s` and then `/opt/pk/bin/personakit export --session=s`',
  )
  expect(usePrompt({ sessionId: 's' }, '/Users/x/My Tools/personakit')).toContain("`'/Users/x/My Tools/personakit' contract --session=s`")
})

test('persona and directive ids produce --persona and --directive', async () => {
  const text = usePrompt({ personaId: 'p', directiveId: 'd' })
  expect(text).toContain('`personakit contract --persona=p --directive=d` and then `personakit export --persona=p --directive=d`')
  expect(text).toContain('personaId `p`')
  expect(text).toContain('directiveId `d`')
  expect(text).not.toContain('--session')
})

test('a persona alone produces --persona only', async () => {
  expect(usePrompt({ personaId: 'p' })).toContain('`personakit export --persona=p`')
})

test('the session id wins over persona and directive', async () => {
  const text = usePrompt({ sessionId: 's', personaId: 'p', directiveId: 'd' })
  expect(text).toContain('--session=s')
  expect(text).not.toContain('--persona')
})

test('a session name the shell would split is single-quoted', async () => {
  expect(usePrompt({ sessionId: "it's mine" })).toContain(`--session='it'\\''s mine'`)
})
