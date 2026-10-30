// Stages the publishable layout in `.stage/` and dry-runs `npm pack` there; nothing outside `.stage/` is written.
//
// The plugin imports the shared core by relative path (`../../ClaudeCode/hooks/lib`), so the stage keeps the repo
// layout: `Integrations/OpenCode/src` beside `Integrations/ClaudeCode/hooks/lib`. The core is copied into the stage
// only; the repo keeps its single copy. The source ships as TypeScript, which OpenCode's runtime loads directly.
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const pkgRoot = join(dirname(fileURLToPath(import.meta.url)), '..')
const repoRoot = join(pkgRoot, '..', '..')
const stage = join(pkgRoot, '.stage')
const opencodeDir = 'Integrations/OpenCode'

rmSync(stage, { recursive: true, force: true })
mkdirSync(stage, { recursive: true })

const isSource = (source: string) => !/\.test\.tsx?$/.test(source)
const copy = (from: string, to: string, filter?: (source: string) => boolean) =>
  cpSync(join(repoRoot, from), join(stage, to), { recursive: true, filter })

copy(`${opencodeDir}/src`, `${opencodeDir}/src`, isSource)
// Only source: tests live beside `src` and `lib`, not in them, but a stray one is still not shipped.
copy('Integrations/ClaudeCode/hooks/lib', 'Integrations/ClaudeCode/hooks/lib', isSource)
copy('Integrations/ClaudeCode/types/index.d.ts', 'Integrations/ClaudeCode/types/index.d.ts')

const readme = join(pkgRoot, 'README.md')
if (existsSync(readme)) cpSync(readme, join(stage, 'README.md'))

const source = JSON.parse(readFileSync(join(pkgRoot, 'package.json'), 'utf8')) as Record<string, unknown>
const { name, version, description, type, peerDependencies } = source
const staged = {
  name,
  version,
  description,
  type,
  'oc-plugin': source['oc-plugin'],
  exports: {
    './server': `./${opencodeDir}/src/server.ts`,
    './tui': `./${opencodeDir}/src/tui.tsx`,
  },
  peerDependencies,
}
writeFileSync(join(stage, 'package.json'), `${JSON.stringify(staged, null, 2)}\n`)

const missing = Object.values(staged.exports).filter((target) => !existsSync(join(stage, target)))
if (missing.length > 0) {
  for (const target of missing) console.error(`pack: entrypoint ${target} is not in the stage`)
  process.exit(1)
}

const packed = Bun.spawnSync(['npm', 'pack', '--dry-run', '--json'], { cwd: stage, stdout: 'pipe', stderr: 'pipe' })
if (packed.exitCode !== 0) {
  console.error(packed.stderr.toString())
  process.exit(packed.exitCode ?? 1)
}
process.stdout.write(packed.stdout)
