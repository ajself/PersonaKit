import { spawn } from 'node:child_process'
import type { ProcessRunResult, RunnerDollar } from '../../../ClaudeCode/hooks/lib/runner.ts'

const KILL_GRACE_MS = 1000

/**
 * The one-shot process call the shared loaders need, on `node:child_process`. The argv runs directly: no shell, so no
 * word splitting or expansion; the first element is the executable. It rejects when the executable cannot start (the
 * message names the spawn errno, which the shared runner reads as "cannot start") and when `timeoutMs` passes
 * (`timed out`; SIGTERM, then SIGKILL after a second, and it rejects once the child has exited) and when its stdin
 * could not be written (`could not write stdin`). A nonzero exit resolves, it is not an error.
 *
 * Output is capped at `maxBytes` for stdout and for stderr. Past the cap stdout stops accumulating and
 * `isStdoutTruncated` is set; the child is not killed, its output is read and dropped so it exits on its own and the
 * timeout bounds how long that can take.
 */
export function createSpawnRunner(opts: { cwd: string; timeoutMs?: number; maxBytes?: number }): RunnerDollar {
  const { cwd, timeoutMs = 10_000, maxBytes = 4 * 1024 * 1024 } = opts
  return {
    process: {
      run: (argv, runOpts) =>
        new Promise<ProcessRunResult>((resolve, reject) => {
          const [command, ...args] = argv
          if (command === undefined || command === '') return reject(new Error('cannot run an empty command'))

          const child = spawn(command, args, { cwd, shell: false, stdio: ['pipe', 'pipe', 'pipe'] })
          const out = capped(maxBytes)
          const err = capped(maxBytes)
          child.stdout.on('data', out.add)
          child.stderr.on('data', err.add)

          // A stdin write that fails (EPIPE when the child exits without reading it) means the child never saw its
          // input, so the call rejects rather than resolving with an exit code that says nothing of that. The write
          // callback is what reports it: under Bun a large write to a child that already exited can finish with no
          // `error` event at all, but its callback still gets the error.
          let stdinError: string | undefined
          let writeDone = runOpts?.stdin === undefined
          const noteStdinError = (error: NodeJS.ErrnoException | null | undefined) => {
            if (error && runOpts?.stdin !== undefined) stdinError ??= error.code ?? error.message
          }
          child.stdin.on('error', noteStdinError)

          let settled = false
          let timedOut = false
          let killTimer: ReturnType<typeof setTimeout> | undefined
          const finish = (settle: () => void) => {
            if (settled) return
            settled = true
            clearTimeout(timer)
            clearTimeout(killTimer)
            settle()
          }
          const timeoutError = new Error(`${command} timed out after ${timeoutMs} ms`)
          const timer = setTimeout(() => {
            timedOut = true
            // Already exited but still waiting on a pipe: nothing is left to kill or to wait for.
            if (child.exitCode !== null || child.signalCode !== null) return finish(() => reject(timeoutError))
            child.kill('SIGTERM')
            killTimer = setTimeout(() => child.kill('SIGKILL'), KILL_GRACE_MS)
          }, timeoutMs)

          child.on('error', (error) => finish(() => reject(error)))
          // After a timeout the child's exit is enough: a grandchild holding the output pipes must not delay it.
          child.on('exit', () => {
            if (timedOut) finish(() => reject(timeoutError))
          })
          // A normal exit settles once the output pipes have closed (`close`), stdin has closed and its write has
          // reported, since a failed write can be reported after the child's `close`.
          let exitStatus: { code: number | null; signal: NodeJS.Signals | null } | undefined
          let stdinClosed = false
          const settleExit = () => {
            if (exitStatus === undefined || !stdinClosed || !writeDone) return
            const { code, signal } = exitStatus
            finish(() => {
              if (timedOut) return reject(timeoutError)
              if (stdinError !== undefined) return reject(new Error(`could not write stdin: ${stdinError}`))
              resolve({
                stdout: out.text(),
                stderr: err.text(),
                // A signal death has no code; it reports a flat 128, which reads as failure like any nonzero value.
                exitCode: code ?? (signal === null ? 1 : 128),
                isStdoutTruncated: out.isTruncated(),
              })
            })
          }
          child.stdin.on('close', () => {
            stdinClosed = true
            settleExit()
          })
          child.on('close', (code, signal) => {
            exitStatus = { code, signal }
            settleExit()
          })

          // Last, so the write callback (which may run synchronously) finds everything above initialized.
          if (runOpts?.stdin === undefined) {
            child.stdin.end()
          } else {
            child.stdin.write(runOpts.stdin, (error) => {
              noteStdinError(error)
              writeDone = true
              settleExit()
            })
            child.stdin.end()
          }
        }),
    },
  }
}

/** Collects chunks up to `limit` bytes and remembers whether any were dropped. */
function capped(limit: number) {
  const chunks: Buffer[] = []
  let size = 0
  let truncated = false
  return {
    add(chunk: Buffer) {
      const room = limit - size
      if (chunk.length > room) truncated = true
      if (room <= 0) return
      const kept = chunk.length > room ? chunk.subarray(0, room) : chunk
      chunks.push(kept)
      size += kept.length
    },
    text: () => Buffer.concat(chunks).toString('utf8'),
    isTruncated: () => truncated,
  }
}
