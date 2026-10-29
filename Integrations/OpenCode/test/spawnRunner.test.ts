import { describe, expect, test } from 'bun:test'
import { mkdtempSync, realpathSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createSpawnRunner } from '../src/tui/spawnRunner'

const cwd = realpathSync(tmpdir())
// The pattern the shared runner uses to tell "cannot start" from other rejections, copied from runner.ts.
const CANNOT_START = /ENOENT|ENOTDIR|EACCES|ENOEXEC|no such file|not found|permission denied|cannot (start|run|execute|spawn)|failed to (start|spawn|launch)/i

describe('createSpawnRunner', () => {
  test('runsArgvWithoutShell', async () => {
    const result = await createSpawnRunner({ cwd }).process.run(['/bin/echo', '$HOME'])
    expect(result.stdout).toBe('$HOME\n')
    expect(result.exitCode).toBe(0)
  })

  test('honorsCwd', async () => {
    const dir = realpathSync(mkdtempSync(join(tmpdir(), 'spawn-runner-')))
    const result = await createSpawnRunner({ cwd: dir }).process.run(['/bin/pwd'])
    expect(result.stdout.trim()).toBe(dir)
  })

  test('reportsNonzeroExitAndStderr', async () => {
    const result = await createSpawnRunner({ cwd }).process.run(['/bin/sh', '-c', 'echo oops >&2; exit 3'])
    expect(result.exitCode).toBe(3)
    expect(result.stderr).toBe('oops\n')
  })

  test('rejectsWhenMissing', async () => {
    const run = createSpawnRunner({ cwd }).process.run(['/nonexistent/personakit', 'list'])
    await expect(run).rejects.toThrow(CANNOT_START)
  })

  test('rejectsEmptyArgv', async () => {
    await expect(createSpawnRunner({ cwd }).process.run([])).rejects.toThrow()
  })

  test('timesOut', async () => {
    const started = Date.now()
    const run = createSpawnRunner({ cwd, timeoutMs: 100 }).process.run(['/bin/sleep', '5'])
    await expect(run).rejects.toThrow(/timed out/)
    expect(Date.now() - started).toBeLessThan(3000)
  })

  test('capsOutput', async () => {
    const result = await createSpawnRunner({ cwd, maxBytes: 8 }).process.run(['/bin/echo', 'a long line of output'])
    expect(result.isStdoutTruncated).toBe(true)
    expect(Buffer.byteLength(result.stdout)).toBeLessThanOrEqual(8)
  })

  test('untruncatedOutputIsNotFlagged', async () => {
    const result = await createSpawnRunner({ cwd }).process.run(['/bin/echo', 'hi'])
    expect(result.isStdoutTruncated).toBeFalsy()
  })
})

describe('createSpawnRunner process control', () => {
  test('killsTheChildOnTimeout', async () => {
    const pidFile = join(mkdtempSync(join(tmpdir(), 'spawn-runner-')), 'pid')
    const run = createSpawnRunner({ cwd, timeoutMs: 300 }).process.run(['/bin/sh', '-c', `echo $$ > ${pidFile}; exec /bin/sleep 5`])
    await expect(run).rejects.toThrow(/timed out/)
    const pid = Number((await Bun.file(pidFile).text()).trim())
    expect(pid).toBeGreaterThan(0)
    expect(() => process.kill(pid, 0)).toThrow()
  })

  test('escalatesToSigkillWhenTermIsIgnored', async () => {
    const pidFile = join(mkdtempSync(join(tmpdir(), 'spawn-runner-')), 'pid')
    const script = `echo $$ > ${pidFile}; trap "" TERM; while :; do sleep 0.05; done`
    const run = createSpawnRunner({ cwd, timeoutMs: 200 }).process.run(['/bin/sh', '-c', script])
    await expect(run).rejects.toThrow(/timed out/)
    const pid = Number((await Bun.file(pidFile).text()).trim())
    expect(pid).toBeGreaterThan(0)
    await Bun.sleep(100)
    expect(() => process.kill(pid, 0)).toThrow()
  }, 10_000)

  test('rejectsWhenStdinCannotBeWritten', async () => {
    const run = createSpawnRunner({ cwd }).process.run(['/bin/sh', '-c', 'exit 0'], { stdin: 'x'.repeat(5 * 1024 * 1024) })
    await expect(run).rejects.toThrow(/could not write stdin/)
  })

  test('writesStdinThenClosesIt', async () => {
    const result = await createSpawnRunner({ cwd }).process.run(['/bin/cat'], { stdin: 'piped in' })
    expect(result.stdout).toBe('piped in')
  })

  test('closesStdinWhenNoneGiven', async () => {
    const result = await createSpawnRunner({ cwd, timeoutMs: 2000 }).process.run(['/bin/cat'])
    expect(result.exitCode).toBe(0)
    expect(result.stdout).toBe('')
  })
})
