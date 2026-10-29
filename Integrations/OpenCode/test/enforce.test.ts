import { afterAll, describe, expect, test } from 'bun:test'
import { createHash } from 'node:crypto'
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import type { ProcessRunResult, RunnerDollar } from '../../ClaudeCode/hooks/lib/runner.ts'
import {
  check,
  enforceCall,
  findManifest,
  isExecutableFile,
  liveServers,
  patchPaths,
  payload,
  resolveExecutable,
  routes,
  type Enforcement,
} from '../src/enforce'
import plugin from '../src/server'

type Run = RunnerDollar['process']['run']
type Call = { argv: readonly string[]; stdin?: string }

/** A fake `run` that records each call and answers with `result`. */
function fakeRun(result: Partial<ProcessRunResult> = {}): { run: Run; calls: Call[] } {
  const calls: Call[] = []
  const run: Run = async (argv, opts) => {
    calls.push({ argv, stdin: opts?.stdin })
    return { stdout: '', stderr: '', exitCode: 0, ...result }
  }
  return { run, calls }
}

/** A fake directory listing: `entries` maps a directory to the names in it; anything else is empty. */
/** A fresh temp directory, removed when the file's tests finish. */
const made: string[] = []
function tempDir(prefix: string): string {
  const dir = realpathSync(mkdtempSync(join(tmpdir(), prefix)))
  made.push(dir)
  return dir
}
afterAll(() => {
  for (const dir of made) rmSync(dir, { recursive: true, force: true })
})

const fakeFs = (entries: Record<string, string[]>) => ({ list: (dir: string) => entries[dir] ?? [] })

const manifest = { path: '/w/.opencode/personakit/s.checks.json', sha256: 'ab'.repeat(32) }
const body = payload('bash', { command: 'echo hi' }, [], '/w', '/w')
const okStatus = async () => ({ data: {} })

describe('findManifest', () => {
  test('findsManifestFromSubdirectory', () => {
    const fs = fakeFs({ '/w/.opencode/personakit': ['s.checks.json', 'notes.txt'] })
    expect(findManifest('/w/a/b', '/w', fs)).toEqual({
      kind: 'one',
      path: '/w/.opencode/personakit/s.checks.json',
      projectDir: '/w',
    })
  })

  test('noManifestIsNone', () => {
    expect(findManifest('/w/a', '/w', fakeFs({ '/w/.opencode/personakit': ['README.md'] }))).toEqual({ kind: 'none' })
  })

  test('manyManifestsIsMany', () => {
    const fs = fakeFs({ '/w/.opencode/personakit': ['b.checks.json', 'a.checks.json'] })
    expect(findManifest('/w', '/w', fs)).toEqual({
      kind: 'many',
      paths: ['/w/.opencode/personakit/a.checks.json', '/w/.opencode/personakit/b.checks.json'],
    })
  })

  test('manifestsAtTwoLevelsIsMany', () => {
    const fs = fakeFs({
      '/w/sub/.opencode/personakit': ['a.checks.json'],
      '/w/.opencode/personakit': ['b.checks.json'],
    })
    expect(findManifest('/w/sub', '/w', fs)).toEqual({
      kind: 'many',
      paths: ['/w/.opencode/personakit/b.checks.json', '/w/sub/.opencode/personakit/a.checks.json'],
    })
  })

  test('walkStopsAtWorktree', () => {
    const fs = fakeFs({ '/.opencode/personakit': ['x.checks.json'] })
    expect(findManifest('/w/a', '/w', fs)).toEqual({ kind: 'none' })
  })

  test('listingErrorPropagates', () => {
    const fs = {
      list: () => {
        throw new Error('EACCES')
      },
    }
    expect(() => findManifest('/w', '/w', fs)).toThrow('EACCES')
  })
})

describe('patchPaths', () => {
  test('patchPathsIncludeMoveTargets', () => {
    const patch = ['*** Begin Patch', '*** Update File: src/a.py', '*** Move to: opencode.json', '@@', '-a', '+b', '*** End Patch'].join('\n')
    expect(patchPaths(patch)).toEqual(['src/a.py', 'opencode.json'])
  })

  test('patchPathsReadsEveryHeaderInOrder', () => {
    const patch = ['*** Begin Patch', '*** Add File: n.ts', '+x', '*** Delete File: d.ts', '*** Update File: u.ts', '*** End Patch'].join('\n')
    expect(patchPaths(patch)).toEqual(['n.ts', 'd.ts', 'u.ts'])
  })

  test('patchPathsKeepsLoneCRInPath', () => {
    // OpenCode splits a patch on LF only, so a lone CR stays inside the path it writes.
    const add = '*** Begin Patch\n*** Add File: foo\r/../.opencode/plugins/evil.ts\n+x\n*** End Patch'
    expect(payload('apply_patch', { patchText: add }, [], '/w', '/w').paths).toEqual(['/w/.opencode/plugins/evil.ts'])
    const move = '*** Begin Patch\n*** Update File: a\n*** Move to: b\r/../opencode.json\n@@\n-a\n+b\n*** End Patch'
    expect(payload('apply_patch', { patchText: move }, [], '/w', '/w').paths).toEqual(['/w/a', '/w/opencode.json'])
  })

  test('patchPathsToleratesWrapperAndWhitespace', () => {
    const patch = ["cat <<'EOF'", '*** Begin Patch', '   *** Add File: sneaky.ts  ', '+x', '*** End Patch', 'EOF'].join('\r\n')
    expect(patchPaths(patch)).toEqual(['sneaky.ts'])
  })
})

describe('payload', () => {
  test('payloadSortsServers', () => {
    const servers = ['z', 'a', 'z']
    expect(payload('edit', { filePath: '/w/a.ts' }, servers, '/w', '/w')).toEqual({
      tool: 'edit',
      paths: ['/w/a.ts'],
      mcpServers: ['a', 'z'],
      directory: '/w',
      worktree: '/w',
    })
    expect(payload('write', { filePath: '/w/b.ts' }, servers, '/w', '/w').paths).toEqual(['/w/b.ts'])
    const patch = '*** Begin Patch\n*** Update File: /w/c.ts\n*** Move to: /w/d.ts\n*** End Patch'
    expect(payload('apply_patch', { patchText: patch }, servers, '/w', '/w').paths).toEqual(['/w/c.ts', '/w/d.ts'])
  })

  test('payloadResolvesRelativePathsFromSessionDirectory', () => {
    const patch = '*** Begin Patch\n*** Add File: ../opencode.json\n+{}\n*** End Patch'
    const patched = payload('apply_patch', { patchText: patch }, [], '/w/a', '/w')
    expect(patched.paths).toEqual(['/w/opencode.json'])
    expect(patched.directory).toBe('/w/a')
    expect(patched.worktree).toBe('/w')
    expect(payload('edit', { filePath: 'b.ts' }, [], '/w/a', '/w').paths).toEqual(['/w/a/b.ts'])
  })

  test('payloadKeepsAbsoluteEditPathsRaw', () => {
    expect(payload('edit', { filePath: '/w/ln/../opencode/x.ts' }, [], '/w', '/w').paths).toEqual(['/w/ln/../opencode/x.ts'])
  })

  test('payloadWithNothingParsedSendsNoPaths', () => {
    expect(payload('edit', {}, [], '/w', '/w').paths).toEqual([])
    expect(payload('apply_patch', { patchText: 42 }, [], '/w', '/w').paths).toEqual([])
    expect(payload('bash', { command: 'echo hi' }, [], '/w', '/w').paths).toEqual([])
  })
})

describe('routes', () => {
  test('readOnlyBuiltInsAreNotRouted', () => {
    expect(routes('read', [])).toBe(false)
    expect(routes('plan_exit', [])).toBe(false)
  })

  test('everythingElseIsRouted', () => {
    for (const tool of ['bash', 'edit', 'write', 'apply_patch', 'webfetch', 'repo_clone', 'mystery']) {
      expect(routes(tool, [])).toBe(true)
    }
  })

  test('mcpToolShadowingBuiltInIsRouted', () => {
    expect(routes('plan_exit', ['plan'])).toBe(true)
  })
})

describe('liveServers', () => {
  test('joinsConfigAndLiveNamesSorted', async () => {
    expect(await liveServers(['z', 'a'], async () => ({ data: { b: {}, a: {} } }))).toEqual(['a', 'b', 'z'])
  })

  test('failedLookupIsUndefined', async () => {
    expect(await liveServers(['a'], async () => ({ error: { message: 'nope' } }))).toBeUndefined()
    expect(await liveServers(['a'], async () => ({}))).toBeUndefined()
    expect(await liveServers(['a'], async () => ({ data: ['b'] }))).toBeUndefined()
    expect(
      await liveServers(['a'], async () => {
        throw new Error('down')
      }),
    ).toBeUndefined()
  })
})

describe('check', () => {
  test('routesWithStartupHash', async () => {
    const { run, calls } = fakeRun()
    await check(run, '/bin/personakit', manifest, body)
    expect(calls).toEqual([
      {
        argv: ['/bin/personakit', 'hook-check', '--host', 'opencode', '--manifest', manifest.path, '--expect-sha256', manifest.sha256],
        stdin: JSON.stringify(body),
      },
    ])
  })

  test('checkFailsClosedOnSpawnError', async () => {
    const run: Run = async () => {
      throw new Error('spawn /bin/personakit ENOENT')
    }
    const decision = await check(run, '/bin/personakit', manifest, body)
    expect('deny' in decision && decision.deny).toContain('could not run personakit')
  })

  test('checkDeniesOnDenyJSON', async () => {
    const { run } = fakeRun({ stdout: '{"decision":"deny","reason":"Blocked: no shell"}\n' })
    expect(await check(run, '/bin/personakit', manifest, body)).toEqual({ deny: 'Blocked: no shell' })
  })

  test('checkAllowsOnEmptyStdout', async () => {
    const { run } = fakeRun({ stdout: ' \n' })
    expect(await check(run, '/bin/personakit', manifest, body)).toEqual({ allow: true })
  })

  test('checkDeniesOnFailedOrUnreadableAnswers', async () => {
    const answers: Partial<ProcessRunResult>[] = [
      { exitCode: 64 },
      { exitCode: 134, stdout: '' },
      { exitCode: 128 },
      { stdout: 'not json' },
      { stdout: '{"decision":"allow"}' },
      { stdout: '{"decision":"deny","reason":"x","extra":1}' },
      { stdout: '{"decision":"deny","reason":""}' },
      { stdout: '["deny"]' },
      { stdout: '', isStdoutTruncated: true },
    ]
    for (const answer of answers) {
      const decision = await check(fakeRun(answer).run, '/bin/personakit', manifest, body)
      expect('deny' in decision, JSON.stringify(answer)).toBe(true)
    }
  })

  test('checkDeniesOnStdinWriteError', async () => {
    const run: Run = async () => {
      throw new Error('could not write stdin: EPIPE')
    }
    const decision = await check(run, '/bin/personakit', manifest, body)
    expect('deny' in decision && decision.deny).toContain('could not run personakit')
  })
})

describe('enforceCall', () => {
  const on: Enforcement = { kind: 'on', manifest, binary: '/bin/personakit' }
  const ctx = (run: Run, status: () => Promise<unknown> = okStatus, configServers: readonly string[] = []) => ({
    configServers: () => configServers,
    status,
    run,
    directory: '/w',
    worktree: '/w',
  })

  test('liveServersJoinConfigServers', async () => {
    const { run, calls } = fakeRun()
    await enforceCall(on, { tool: 'bash', args: {} }, ctx(run, async () => ({ data: { b: { status: 'connected' } } }), ['a']))
    expect(JSON.parse(calls[0]?.stdin ?? '{}').mcpServers).toEqual(['a', 'b'])

    const failing = fakeRun()
    const rejecting = async () => {
      throw new Error('down')
    }
    const decision = await enforceCall(on, { tool: 'bash', args: {} }, ctx(failing.run, rejecting, ['a']))
    expect('deny' in decision && decision.deny).toContain('could not list MCP servers')
    expect(failing.calls).toEqual([])
  })

  test('failedLookupDeniesReadOnlyBuiltIns', async () => {
    const { run, calls } = fakeRun()
    const decision = await enforceCall(on, { tool: 'read', args: {} }, ctx(run, async () => ({ error: 'x' })))
    expect('deny' in decision && decision.deny).toContain('could not list MCP servers')
    expect(calls).toEqual([])
  })

  test('readOnlyBuiltInIsAllowedWithoutSpawning', async () => {
    const { run, calls } = fakeRun()
    expect(await enforceCall(on, { tool: 'read', args: {} }, ctx(run))).toEqual({ allow: true })
    expect(calls).toEqual([])
  })

  test('liveMCPShadowIsRouted', async () => {
    const { run, calls } = fakeRun()
    await enforceCall(on, { tool: 'plan_exit', args: {} }, ctx(run, async () => ({ data: { plan: {} } })))
    expect(calls.length).toBe(1)
  })

  test('noManifestIsANoOp', async () => {
    const { run, calls } = fakeRun()
    let looked = false
    const status = async () => {
      looked = true
      return { data: {} }
    }
    expect(await enforceCall({ kind: 'off' }, { tool: 'bash', args: {} }, ctx(run, status))).toEqual({ allow: true })
    expect(calls).toEqual([])
    expect(looked).toBe(false)
  })

  test('blockAllDeniesEveryTool', async () => {
    const { run, calls } = fakeRun()
    const decision = await enforceCall({ kind: 'blockAll', reason: 'many' }, { tool: 'read', args: {} }, ctx(run))
    expect(decision).toEqual({ deny: 'many' })
    expect(calls).toEqual([])
  })

  test('blockRoutedDeniesRoutedToolsOnly', async () => {
    const { run, calls } = fakeRun()
    const state: Enforcement = { kind: 'blockRouted', reason: 'could not run personakit' }
    expect(await enforceCall(state, { tool: 'bash', args: {} }, ctx(run))).toEqual({ deny: 'could not run personakit' })
    expect(await enforceCall(state, { tool: 'read', args: {} }, ctx(run))).toEqual({ allow: true })
    expect(calls).toEqual([])
  })
})

describe('resolveExecutable', () => {
  const exists = (paths: string[]) => (path: string) => paths.includes(path)

  test('looksUpBareNamesOnPath', () => {
    expect(resolveExecutable('personakit', '/a:/b:/c', exists(['/b/personakit', '/c/personakit']))).toBe('/b/personakit')
  })

  test('skipsEmptyAndRelativePathEntries', () => {
    expect(resolveExecutable('personakit', ':.:bin:/c', exists(['personakit', './personakit', 'bin/personakit']))).toBeUndefined()
  })

  test('acceptsAnExistingAbsolutePath', () => {
    expect(resolveExecutable('/opt/pk', '', exists(['/opt/pk']))).toBe('/opt/pk')
    expect(resolveExecutable('/opt/missing', '/opt', exists([]))).toBeUndefined()
  })

  test('rejectsRelativePathsWithASeparator', () => {
    expect(resolveExecutable('bin/personakit', '/x', exists(['/x/bin/personakit']))).toBeUndefined()
  })

  test('isExecutableFileNeedsAnExecutableRegularFile', () => {
    const dir = tempDir('enforce-exec-')
    const plain = join(dir, 'plain')
    writeFileSync(plain, '')
    expect(isExecutableFile('/bin/sh')).toBe(true)
    expect(isExecutableFile(plain)).toBe(false)
    expect(isExecutableFile(dir)).toBe(false)
    expect(isExecutableFile(join(dir, 'missing'))).toBe(false)
  })
})

describe('server', () => {
  /** A project with one manifest, and a fake `personakit` that records its argv, cwd, and stdin, then answers. */
  function project(answer: string) {
    const root = tempDir('enforce-server-')
    mkdirSync(join(root, '.opencode/personakit'), { recursive: true })
    const manifestPath = join(root, '.opencode/personakit/s.checks.json')
    writeFileSync(manifestPath, '{"sessionId":"s"}\n')
    const record = join(root, 'record')
    const binary = join(root, 'personakit')
    writeFileSync(
      binary,
      `#!/bin/sh\nprintf '%s\\n' "$@" > '${record}.argv'\npwd > '${record}.cwd'\ncat > '${record}.stdin'\nprintf '%s' '${answer}'\n`,
    )
    chmodSync(binary, 0o755)
    return { root, manifestPath, record, binary }
  }

  const input = (root: string, status: () => Promise<unknown>) =>
    ({ directory: root, worktree: root, client: { mcp: { status } } }) as unknown as Parameters<typeof plugin.server>[0]

  test('exportsThePluginModule', () => {
    expect(plugin.id).toBe('opencode-personakit')
    expect(typeof plugin.server).toBe('function')
  })

  test('deniesByThrowingTheHookCheckReason', async () => {
    const { root, manifestPath, record, binary } = project('{"decision":"deny","reason":"Blocked: no shell"}')
    const hooks = await plugin.server(input(root, async () => ({ data: { live: {} } })), { personakitPath: binary })
    await hooks.config?.({ mcp: { cfg: { type: 'local', command: ['x'] } } } as never)
    const before = hooks['tool.execute.before']
    expect(before).toBeDefined()
    await expect(before!({ tool: 'bash', sessionID: 's', callID: 'c' }, { args: { command: 'echo hi' } })).rejects.toThrow(
      'Blocked: no shell',
    )
    const sha = createHash('sha256').update(readFileSync(manifestPath)).digest('hex')
    expect(readFileSync(`${record}.argv`, 'utf8').trim().split('\n')).toEqual([
      'hook-check', '--host', 'opencode', '--manifest', manifestPath, '--expect-sha256', sha,
    ])
    expect(readFileSync(`${record}.cwd`, 'utf8').trim()).toBe(realpathSync(process.cwd()))
    expect(JSON.parse(readFileSync(`${record}.stdin`, 'utf8'))).toEqual({
      tool: 'bash',
      paths: [],
      mcpServers: ['cfg', 'live'],
      directory: root,
      worktree: root,
    })
  })

  test('allowsOnEmptyAnswer', async () => {
    const { root, binary } = project('')
    const hooks = await plugin.server(input(root, async () => ({ data: {} })), { personakitPath: binary })
    await hooks['tool.execute.before']!({ tool: 'bash', sessionID: 's', callID: 'c' }, { args: { command: 'echo hi' } })
  })

  test('unresolvablePersonakitDeniesRoutedCalls', async () => {
    const { root } = project('')
    const hooks = await plugin.server(input(root, async () => ({ data: {} })), { personakitPath: join(root, 'missing') })
    const before = hooks['tool.execute.before']!
    await expect(before({ tool: 'bash', sessionID: 's', callID: 'c' }, { args: {} })).rejects.toThrow('could not run personakit')
    await before({ tool: 'read', sessionID: 's', callID: 'c' }, { args: {} })
  })

  test('manyManifestsDenyNamingEveryPath', async () => {
    const { root, manifestPath, binary } = project('')
    const second = join(root, '.opencode/personakit/a.checks.json')
    writeFileSync(second, '{}')
    const hooks = await plugin.server(input(root, async () => ({ data: {} })), { personakitPath: binary })
    const denied = hooks['tool.execute.before']!({ tool: 'read', sessionID: 's', callID: 'c' }, { args: {} })
    await expect(denied).rejects.toThrow(
      `Blocked by PersonaKit contract: more than one enforcement manifest in .opencode/personakit/: ${second}, ${manifestPath}`,
    )
  })

  test('unlistableManifestDirDeniesRoutedCallsNamingIt', async () => {
    const { root, binary } = project('')
    const dir = join(root, '.opencode/personakit')
    chmodSync(dir, 0o000)
    try {
      const hooks = await plugin.server(input(root, async () => ({ data: {} })), { personakitPath: binary })
      const before = hooks['tool.execute.before']!
      await expect(before({ tool: 'bash', sessionID: 's', callID: 'c' }, { args: {} })).rejects.toThrow(
        `could not read the enforcement manifest at ${dir}`,
      )
      await before({ tool: 'read', sessionID: 's', callID: 'c' }, { args: {} })
    } finally {
      chmodSync(dir, 0o755)
    }
  })

  test('unreadableManifestDeniesRoutedCalls', async () => {
    const { root, manifestPath, binary } = project('')
    rmSync(manifestPath)
    mkdirSync(manifestPath)
    const hooks = await plugin.server(input(root, async () => ({ data: {} })), { personakitPath: binary })
    const before = hooks['tool.execute.before']!
    await expect(before({ tool: 'bash', sessionID: 's', callID: 'c' }, { args: {} })).rejects.toThrow(
      `could not read the enforcement manifest at ${manifestPath}`,
    )
    await before({ tool: 'read', sessionID: 's', callID: 'c' }, { args: {} })
  })

  test('noManifestNeverRuns', async () => {
    const root = tempDir('enforce-none-')
    const hooks = await plugin.server(input(root, async () => ({ error: 'down' })), { personakitPath: '/nonexistent' })
    await hooks['tool.execute.before']!({ tool: 'bash', sessionID: 's', callID: 'c' }, { args: {} })
  })
})
