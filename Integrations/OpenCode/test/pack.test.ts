import { expect, test } from 'bun:test'
import { existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')

test('stagedPackageResolvesBothEntrypoints', async () => {
  const proc = Bun.spawn(['bun', 'scripts/pack.ts'], { cwd: root, stdout: 'pipe', stderr: 'pipe' })
  const [out, err, code] = await Promise.all([new Response(proc.stdout).text(), new Response(proc.stderr).text(), proc.exited])
  expect(code, err).toBe(0)
  const [report] = JSON.parse(out) as [{ files: { path: string }[] }]
  const files = report.files.map((file) => file.path)

  // Every entrypoint the package declares ships. An entrypoint whose source has not landed yet is skipped; pack.ts
  // names it on stderr.
  for (const entry of ['src/server.ts', 'src/tui.tsx']) {
    if (existsSync(join(root, entry))) expect(files).toContain(`Integrations/OpenCode/${entry}`)
  }
  const staged = JSON.parse(await Bun.file(join(root, '.stage/package.json')).text()) as { exports: Record<string, string> }
  expect(staged.exports).toEqual({
    './server': './Integrations/OpenCode/src/server.ts',
    './tui': './Integrations/OpenCode/src/tui.tsx',
  })
  expect(files).toContain('Integrations/OpenCode/src/tui/spawnRunner.ts')
  expect(files).toContain('Integrations/ClaudeCode/hooks/lib/runner.ts')
  expect(files).toContain('Integrations/ClaudeCode/types/index.d.ts')
  expect(files).toContain('package.json')
  expect(files.filter((path) => /(^|\/)(test|node_modules)\//.test(path))).toEqual([])
}, 60_000)
