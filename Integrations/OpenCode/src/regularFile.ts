import { closeSync, constants, fstatSync, openSync, readSync } from 'node:fs'
import { open } from 'node:fs/promises'

// The one bounded reader for the enforcement manifest (server, v2 setup, TUI) and a tool's saved full output (TUI).

/** The largest file read; past it a file reads as none. */
export const MAX_READ_BYTES = 4 * 1024 * 1024

// Opened without blocking, so a FIFO or device answers at once; what was opened is then checked to be a regular file.
const READ_FLAGS = constants.O_RDONLY | constants.O_NONBLOCK

/** A regular file of at most 4 MiB; anything else (a FIFO, a device, a directory), or any error, is `undefined`. */
export function readRegularFileSync(file: string): Buffer | undefined {
  let fd: number | undefined
  try {
    fd = openSync(file, READ_FLAGS)
    const info = fstatSync(fd)
    if (!info.isFile() || info.size > MAX_READ_BYTES) return undefined
    const buffer = Buffer.alloc(MAX_READ_BYTES + 1)
    let length = 0
    while (length < buffer.length) {
      const bytesRead = readSync(fd, buffer, length, buffer.length - length, length)
      if (bytesRead === 0) break
      length += bytesRead
    }
    return length > MAX_READ_BYTES ? undefined : buffer.subarray(0, length)
  } catch {
    return undefined
  } finally {
    if (fd !== undefined) closeSync(fd)
  }
}

/** A regular file of at most 4 MiB, as text; anything else, or any error, is `undefined`. */
export async function readRegularFileText(file: string): Promise<string | undefined> {
  let handle: Awaited<ReturnType<typeof open>> | undefined
  try {
    handle = await open(file, READ_FLAGS)
    const info = await handle.stat()
    if (!info.isFile() || info.size > MAX_READ_BYTES) return undefined
    const buffer = Buffer.alloc(MAX_READ_BYTES + 1)
    let length = 0
    while (length < buffer.length) {
      const { bytesRead } = await handle.read(buffer, length, buffer.length - length, length)
      if (bytesRead === 0) break
      length += bytesRead
    }
    return length > MAX_READ_BYTES ? undefined : buffer.subarray(0, length).toString('utf8')
  } catch {
    return undefined
  } finally {
    await handle?.close().catch(() => {})
  }
}
