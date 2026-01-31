import fs from "node:fs/promises";
import path from "node:path";
import { MAX_FILE_BYTES, toPosixPath } from "./utils.js";

export class ResourceNotFoundError extends Error {
  relPath: string;

  constructor(relPath: string) {
    super("Resource not found.");
    this.relPath = relPath;
  }
}

export function getRootFromEnv(): string {
  const root = process.env.PERSONAKIT_ROOT?.trim();
  if (!root) {
    throw new Error("PERSONAKIT_ROOT is required.");
  }
  return root;
}

export async function assertPacksDirectory(root: string): Promise<string> {
  const packsDir = path.join(root, "Packs");
  const stat = await fs.stat(packsDir).catch(() => null);
  if (!stat || !stat.isDirectory()) {
    throw new Error("PERSONAKIT_ROOT must contain a Packs/ directory.");
  }
  return packsDir;
}

export async function resolveSafePath(root: string, relPath: string): Promise<string> {
  if (path.isAbsolute(relPath)) {
    throw new Error("Absolute paths are not allowed.");
  }

  const rootReal = await fs.realpath(root);
  const absPath = path.resolve(rootReal, relPath);
  let realPath: string;

  try {
    realPath = await fs.realpath(absPath);
  } catch (error: any) {
    if (error?.code === "ENOENT") {
      throw new ResourceNotFoundError(relPath);
    }
    throw error;
  }

  if (realPath !== rootReal && !realPath.startsWith(rootReal + path.sep)) {
    throw new Error("Resolved path escapes PERSONAKIT_ROOT.");
  }

  const stat = await fs.stat(realPath);
  if (!stat.isFile()) {
    throw new Error("Resource is not a file.");
  }
  if (stat.size > MAX_FILE_BYTES) {
    throw new Error("Resource exceeds maximum size.");
  }

  return realPath;
}

export function relativePath(root: string, filePath: string): string {
  return toPosixPath(path.relative(root, filePath));
}
