import { afterAll, describe, expect, test } from 'bun:test'
import type { AgentV2Info } from '@opencode-ai/sdk/v2/types'
import { chmodSync, mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import plugin from '../src/server'
import { applyV2Rules, globalConfigPaths, physicalForms, v2Rules, worktreeOf, type V2Rule } from '../src/v2'

const made: string[] = []
function tempDir(prefix: string): string {
  const dir = realpathSync(mkdtempSync(join(tmpdir(), prefix)))
  made.push(dir)
  return dir
}
afterAll(() => {
  for (const dir of made) rmSync(dir, { recursive: true, force: true })
})

const deny = (action: string, resource: string): V2Rule => ({ action, resource, effect: 'deny' })
const DENY_ALL = [deny('bash', '*'), deny('edit', '*'), deny('webfetch', '*'), deny('websearch', '*')]

/** The worktree-relative locations `edit` is denied on whenever a manifest allows file mutation. */
const WORKTREE_EDITS = [
  '*/.opencode',
  '*/.opencode/*',
  '*/opencode.json',
  '*/opencode.jsonc',
  '*/tui.json',
  '*/tui.jsonc',
  '.opencode',
  '.opencode/*',
  'opencode.json',
  'opencode.jsonc',
  'tui.json',
  'tui.jsonc',
].map((resource) => deny('edit', resource))

const ONE = { kind: 'one', path: '/w/.opencode/personakit/s.checks.json', projectDir: '/w' } as const

/** A manifest whose hook checks deny `classes`; `extra` checks are added as given. */
function manifest(classes: string[], extra: unknown[] = []): string {
  const checks = classes.map((actionClass) => ({
    id: `capability-deny.${actionClass}`,
    mandate: `deny ${actionClass}`,
    maxClass: 'hook',
    rule: { kind: 'capability-deny', deniedCapability: actionClass, deniedActionClasses: [actionClass] },
    source: { sourceType: 'persona', sourceId: 'p', field: 'forbiddenCapabilities' },
    hostNotes: [],
  }))
  return JSON.stringify({ personaId: 'p', sessionId: 's', checks: [...checks, ...extra], unrepresentedMandates: [], summary: {} })
}

describe('v2Rules', () => {
  test('noManifestHasNoRules', () => {
    expect(v2Rules({ kind: 'none' }, undefined)).toEqual([])
    expect(v2Rules({ kind: 'none' }, manifest(['command-execution']), ['/g/'])).toEqual([])
  })

  test('manyManifestsDenyEveryContractTool', () => {
    expect(v2Rules({ kind: 'many', paths: ['/a', '/b'] }, undefined, ['/g/'])).toEqual(DENY_ALL)
  })

  test('anUnreadableManifestDeniesEveryContractTool', () => {
    expect(v2Rules(ONE, undefined, ['/g/'])).toEqual(DENY_ALL)
  })

  test('anUnparseableManifestDeniesEveryContractTool', () => {
    const bad = [
      '',
      '{',
      'null',
      '[]',
      '{"personaId":"p"}',
      '{"personaId":"p","checks":{}}',
      '{"checks":[]}',
      '{"personaId":"p","checks":[1]}',
      '{"personaId":"p","checks":[{"maxClass":"hook"}]}',
      '{"personaId":"p","checks":[{"maxClass":1,"rule":{"kind":"review"}}]}',
      '{"personaId":"p","checks":[{"maxClass":"hook","rule":{}}]}',
      '{"personaId":"p","checks":[{"maxClass":"hook","rule":{"kind":"capability-deny","deniedActionClasses":"bash"}}]}',
      '{"personaId":"p","checks":[{"maxClass":"hook","rule":{"kind":"capability-deny","deniedActionClasses":[1]}}]}',
    ]
    for (const text of bad) expect(v2Rules(ONE, text, ['/g/'])).toEqual(DENY_ALL)
  })

  test('deniedCommandsDenyBashAndProtectTheEnforcementFiles', () => {
    expect(v2Rules(ONE, manifest(['command-execution']))).toEqual([deny('bash', '*'), ...WORKTREE_EDITS])
  })

  test('deniedFileMutationDeniesEveryEditAndNothingNarrower', () => {
    expect(v2Rules(ONE, manifest(['file-mutation']), ['/g/'])).toEqual([deny('edit', '*')])
  })

  test('deniedNetworkDeniesFetchAndSearch', () => {
    expect(v2Rules(ONE, manifest(['network-egress']))).toEqual([
      ...WORKTREE_EDITS,
      deny('webfetch', '*'),
      deny('websearch', '*'),
    ])
  })

  test('everyClassDeniedDeniesEveryContractTool', () => {
    const text = manifest(['network-egress', 'file-mutation', 'command-execution'])
    expect(v2Rules(ONE, text, ['/g/'])).toEqual(DENY_ALL)
  })

  test('onlyHookChecksDeny', () => {
    const review = {
      maxClass: 'review',
      rule: { kind: 'capability-deny', deniedActionClasses: ['command-execution', 'file-mutation'] },
    }
    const command = { maxClass: 'command', rule: { kind: 'command', command: 'swift test', deniedActionClasses: null } }
    expect(v2Rules(ONE, manifest([], [review, command]))).toEqual(WORKTREE_EDITS)
  })

  test('otherClassesDenyNothing', () => {
    expect(v2Rules(ONE, manifest(['inspection', 'unattended-iteration']))).toEqual(WORKTREE_EDITS)
  })

  test('protectedPathsAreDeniedForEditAsDirectoriesAndFiles', () => {
    const rules = v2Rules(ONE, manifest([]), ['/h/.config/opencode/', '/h/cfg.json', '/bin/personakit', '/h/.config/opencode/'])
    expect(rules).toEqual(
      [
        ...WORKTREE_EDITS,
        deny('edit', '/bin/personakit'),
        deny('edit', '/h/.config/opencode'),
        deny('edit', '/h/.config/opencode/*'),
        deny('edit', '/h/cfg.json'),
      ].sort((a, b) => (a.resource < b.resource ? -1 : 1)),
    )
  })

  test('rulesAreSortedByActionThenResource', () => {
    const rules = v2Rules(ONE, manifest(['network-egress', 'command-execution']), ['/z/', '/a'])
    const keys = rules.map((rule) => `${rule.action}\u0000${rule.resource}`)
    expect(keys).toEqual([...keys].sort())
    expect(new Set(keys).size).toBe(keys.length)
  })
})

describe('globalConfigPaths', () => {
  test('mirrorsTheSwiftList', () => {
    expect(
      globalConfigPaths({
        HOME: '/h',
        OPENCODE_CONFIG_DIR: '/c/dir/',
        OPENCODE_CONFIG: '/c/a/../oc.json',
        OPENCODE_TUI_CONFIG: '/c/tui.json',
        XDG_CONFIG_HOME: '/x/config',
        XDG_CACHE_HOME: '/x/cache',
      }),
    ).toEqual(['/c/dir/', '/c/oc.json', '/c/tui.json', '/h/.opencode/', '/x/cache/opencode/', '/x/config/opencode/'])
  })

  test('withoutHomeUsesTheAccountsHomeDirectoryAsOpenCodeDoes', () => {
    const passwd = () => '/p'
    const expected = ['/p/.cache/opencode/', '/p/.config/opencode/', '/p/.opencode/']
    expect(globalConfigPaths({}, passwd)).toEqual(expected)
    expect(globalConfigPaths({ HOME: '' }, passwd)).toEqual(expected)
    expect(globalConfigPaths({ HOME: '/h' }, passwd)).toEqual(['/h/.cache/opencode/', '/h/.config/opencode/', '/h/.opencode/'])
    expect(globalConfigPaths({}, () => '')).toEqual([])
  })

  test('fallsBackToHomeAndSkipsEmptyValues', () => {
    expect(globalConfigPaths({ HOME: '/h', OPENCODE_CONFIG_DIR: '', XDG_CONFIG_HOME: '', OPENCODE_CONFIG: '' })).toEqual([
      '/h/.cache/opencode/',
      '/h/.config/opencode/',
      '/h/.opencode/',
    ])
    expect(globalConfigPaths({}, () => '')).toEqual([])
  })
})

describe('physicalForms', () => {
  test('addsTheResolvedFormTheWayOpenCodeResolvesAWriteTarget', () => {
    const root = tempDir('v2-forms-')
    mkdirSync(join(root, 'real/opencode'), { recursive: true })
    symlinkSync(join(root, 'real'), join(root, 'link'))
    expect(physicalForms(join(root, 'link/opencode/'))).toEqual([join(root, 'link/opencode/'), join(root, 'real/opencode/')])
    // A missing tail keeps its spelling below the deepest directory that resolves.
    expect(physicalForms(join(root, 'link/missing/x.json'))).toEqual([
      join(root, 'link/missing/x.json'),
      join(root, 'real/missing/x.json'),
    ])
    expect(physicalForms(join(root, 'real/opencode/'))).toEqual([join(root, 'real/opencode/')])
  })

  test('keepsOnlyTheSpellingWhenResolutionFails', () => {
    const root = tempDir('v2-forms-loop-')
    symlinkSync(join(root, 'b'), join(root, 'a'))
    symlinkSync(join(root, 'a'), join(root, 'b'))
    expect(physicalForms(join(root, 'a/x'))).toEqual([join(root, 'a/x')])
  })
})

describe('worktreeOf', () => {
  test('isTheNearestAncestorHoldingGitElseTheRoot', () => {
    const root = tempDir('v2-worktree-')
    mkdirSync(join(root, 'repo/a/b'), { recursive: true })
    mkdirSync(join(root, 'repo/.git'))
    expect(worktreeOf(join(root, 'repo/a/b'))).toBe(join(root, 'repo'))
    expect(worktreeOf(join(root, 'repo'))).toBe(join(root, 'repo'))
    // A linked worktree's `.git` is a file.
    mkdirSync(join(root, 'linked/sub'), { recursive: true })
    writeFileSync(join(root, 'linked/.git'), 'gitdir: /elsewhere\n')
    expect(worktreeOf(join(root, 'linked/sub'))).toBe(join(root, 'linked'))
  })
})

/** A fake v2 agent domain: `transform` registers a callback that every `reload` runs against the agents. */
function fakeAgents(ids: string[]) {
  const agents = new Map<string, AgentV2Info>(
    ids.map((id) => [
      id,
      { id, request: {}, mode: 'primary', hidden: false, permissions: [{ action: '*', resource: '*', effect: 'allow' }] } as AgentV2Info,
    ]),
  )
  const callbacks: ((draft: never) => unknown)[] = []
  let reloads = 0
  const draft = {
    list: () => [...agents.values()],
    get: (id: string) => agents.get(id),
    default: () => {},
    update: (id: string, update: (agent: AgentV2Info) => void) => update(agents.get(id)!),
    remove: (id: string) => void agents.delete(id),
  }
  const agent = {
    transform: async (callback: (draft: never) => unknown) => {
      callbacks.push(callback)
      return { dispose: async () => {} }
    },
    reload: async () => {
      reloads += 1
      for (const callback of callbacks) await callback(draft as never)
    },
  }
  return { agent, agents, reloads: () => reloads, transforms: () => callbacks.length }
}

describe('applyV2Rules', () => {
  test('appendsTheRulesAfterEveryAgentsOwnAndReloads', async () => {
    const fake = fakeAgents(['build', 'plan'])
    await applyV2Rules(fake.agent, [deny('bash', '*'), deny('edit', '.opencode')])
    expect(fake.reloads()).toBe(1)
    for (const id of ['build', 'plan']) {
      expect(fake.agents.get(id)!.permissions).toEqual([
        { action: '*', resource: '*', effect: 'allow' },
        deny('bash', '*'),
        deny('edit', '.opencode'),
      ])
    }
  })

  test('noRulesRegistersNothingAndDoesNotReload', async () => {
    const fake = fakeAgents(['build'])
    await applyV2Rules(fake.agent, [])
    expect(fake.transforms()).toBe(0)
    expect(fake.reloads()).toBe(0)
  })
})

describe('setup', () => {
  /** Runs the plugin's `setup` from `directory`, as OpenCode does from the directory it serves. */
  async function setupIn(directory: string, options: Record<string, unknown> = {}) {
    const fake = fakeAgents(['build', 'general'])
    const cwd = process.cwd()
    process.chdir(directory)
    try {
      await plugin.setup({ options, agent: fake.agent } as never)
    } finally {
      process.chdir(cwd)
    }
    return fake
  }

  function project(text: string): string {
    const root = tempDir('v2-setup-')
    mkdirSync(join(root, '.git'))
    mkdirSync(join(root, '.opencode/personakit'), { recursive: true })
    writeFileSync(join(root, '.opencode/personakit/s.checks.json'), text)
    return root
  }

  const added = (fake: ReturnType<typeof fakeAgents>, id: string) => fake.agents.get(id)!.permissions.slice(1)

  test('exportsSetupBesideServer', () => {
    expect(plugin.id).toBe('opencode-personakit')
    expect(typeof plugin.server).toBe('function')
    expect(typeof plugin.setup).toBe('function')
  })

  test('deniesTheContractsToolsOnEveryAgent', async () => {
    const fake = await setupIn(project(manifest(['command-execution', 'file-mutation', 'network-egress'])))
    expect(fake.reloads()).toBe(1)
    expect(added(fake, 'build')).toEqual(DENY_ALL)
    expect(added(fake, 'general')).toEqual(DENY_ALL)
  })

  test('protectsTheGlobalConfigAndThePersonakitExecutableWhenEditsAreAllowed', async () => {
    const root = project(manifest(['command-execution']))
    const binary = join(root, 'bin/personakit')
    mkdirSync(join(root, 'bin'))
    writeFileSync(binary, '#!/bin/sh\n')
    chmodSync(binary, 0o755)
    const saved = process.env.OPENCODE_CONFIG_DIR
    process.env.OPENCODE_CONFIG_DIR = join(root, 'cfg')
    try {
      const fake = await setupIn(root, { personakitPath: binary })
      const resources = added(fake, 'build').map((rule) => `${rule.action} ${rule.resource}`)
      expect(resources).toContain('bash *')
      expect(resources).toContain('edit .opencode/*')
      expect(resources).toContain(`edit ${binary}`)
      expect(resources).toContain(`edit ${join(root, 'cfg')}`)
      expect(resources).toContain(`edit ${join(root, 'cfg')}/*`)
      expect(resources).not.toContain('edit *')
    } finally {
      if (saved === undefined) delete process.env.OPENCODE_CONFIG_DIR
      else process.env.OPENCODE_CONFIG_DIR = saved
    }
  })

  test('aManifestThatIsNotARegularFileDeniesEveryContractTool', async () => {
    const root = project('')
    const path = join(root, '.opencode/personakit/s.checks.json')
    rmSync(path)
    expect(Bun.spawnSync(['mkfifo', path]).exitCode).toBe(0)
    const fake = await setupIn(root)
    expect(added(fake, 'build')).toEqual(DENY_ALL)
  })

  test('anOversizedManifestDeniesEveryContractTool', async () => {
    const fake = await setupIn(project(manifest([]).padEnd(4 * 1024 * 1024 + 1, ' ')))
    expect(added(fake, 'build')).toEqual(DENY_ALL)
  })

  test('aManifestAtTheCapIsRead', async () => {
    const fake = await setupIn(project(manifest(['file-mutation']).padEnd(4 * 1024 * 1024, ' ')))
    expect(added(fake, 'build')).toEqual([deny('edit', '*')])
  })

  test('noManifestChangesNothing', async () => {
    const root = tempDir('v2-setup-none-')
    mkdirSync(join(root, '.git'))
    const fake = await setupIn(root)
    expect(fake.transforms()).toBe(0)
    expect(fake.reloads()).toBe(0)
  })

  test('aStartInASubdirectoryFindsTheManifestAtTheWorktreeRoot', async () => {
    const root = project(manifest(['file-mutation']))
    mkdirSync(join(root, 'a/b'), { recursive: true })
    const fake = await setupIn(join(root, 'a/b'))
    expect(added(fake, 'build')).toEqual([deny('edit', '*')])
  })

  test('manifestsAtTwoLevelsOfTheWorktreeAreMany', async () => {
    const root = project(manifest(['file-mutation']))
    mkdirSync(join(root, 'a/.opencode/personakit'), { recursive: true })
    writeFileSync(join(root, 'a/.opencode/personakit/b.checks.json'), manifest(['file-mutation']))
    const fake = await setupIn(join(root, 'a'))
    expect(added(fake, 'build')).toEqual(DENY_ALL)
  })

  test('aManifestAboveTheWorktreeIsNotRead', async () => {
    const outer = project(manifest(['file-mutation']))
    mkdirSync(join(outer, 'repo/.git'), { recursive: true })
    const fake = await setupIn(join(outer, 'repo'))
    expect(fake.transforms()).toBe(0)
  })

  test('readsOnlyTheStartDirectorysManifestWhateverDirectoryASessionUses', async () => {
    // A documented limit: v2 gives `setup` no directory, so a session in another project gets the start's rules.
    const served = project(manifest(['command-execution', 'file-mutation', 'network-egress']))
    const other = tempDir('v2-setup-other-')
    mkdirSync(join(other, '.git'))
    const fromServed = await setupIn(served, { directory: other })
    expect(added(fromServed, 'build')).toEqual(DENY_ALL)
    const fromOther = await setupIn(other, { directory: served })
    expect(fromOther.transforms()).toBe(0)
  })

  test('manyManifestsDenyEveryContractTool', async () => {
    const root = project(manifest([]))
    writeFileSync(join(root, '.opencode/personakit/a.checks.json'), manifest([]))
    const fake = await setupIn(root)
    expect(added(fake, 'build')).toEqual(DENY_ALL)
  })
})
