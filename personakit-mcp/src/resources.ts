import fs from "node:fs/promises";
import path from "node:path";
import { assertPacksDirectory, resolveSafePath, ResourceNotFoundError } from "./fs-utils.js";
import { ESSENTIALS_MAPPING, PACK_MAPPINGS } from "./utils.js";

export type ResourceEntry = {
  uri: string;
  name: string;
};

function sortByUri(a: ResourceEntry, b: ResourceEntry): number {
  return a.uri.localeCompare(b.uri);
}

async function listDirFiles(dirPath: string): Promise<string[]> {
  const entries = await fs.readdir(dirPath, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile())
    .map((entry) => entry.name)
    .sort();
}

export async function listResources(root: string): Promise<ResourceEntry[]> {
  const packsDir = await assertPacksDirectory(root);
  const entries: ResourceEntry[] = [];

  for (const mapping of PACK_MAPPINGS) {
    const dirPath = path.join(packsDir, mapping.dir);
    let names: string[] = [];

    try {
      names = await listDirFiles(dirPath);
    } catch (error: any) {
      if (error?.code !== "ENOENT") {
        throw error;
      }
      continue;
    }

    for (const name of names) {
      if (!name.endsWith(mapping.suffix)) {
        continue;
      }
      const id = name.slice(0, -mapping.suffix.length);
      if (!id) {
        continue;
      }
      entries.push({
        uri: `${mapping.uriPrefix}${id}`,
        name: id,
      });
    }
  }

  const essentialsDir = path.join(packsDir, ESSENTIALS_MAPPING.dir);
  try {
    const names = await listDirFiles(essentialsDir);
    for (const name of names) {
      if (!name.endsWith(ESSENTIALS_MAPPING.suffix)) {
        continue;
      }
      const id = name.slice(0, -ESSENTIALS_MAPPING.suffix.length);
      if (!id) {
        continue;
      }
      entries.push({
        uri: `${ESSENTIALS_MAPPING.uriPrefix}${id}`,
        name: id,
      });
    }
  } catch (error: any) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
  }

  return entries.sort(sortByUri);
}

export function parseUri(uri: string): { relPath: string; mimeType: string } {
  let parsed: URL;
  try {
    parsed = new URL(uri);
  } catch {
    throw new Error(`Invalid URI: ${uri}`);
  }

  if (parsed.protocol !== "personakit:") {
    throw new Error(`Unsupported URI scheme: ${parsed.protocol}`);
  }

  const host = parsed.host;
  const segments = parsed.pathname
    .split("/")
    .filter(Boolean)
    .map((segment) => decodeURIComponent(segment));

  const ensureSegment = (segment: string) => {
    if (!segment || segment === "." || segment === "..") {
      throw new Error(`Invalid URI path segment: ${segment}`);
    }
    if (segment.includes(path.sep)) {
      throw new Error(`Invalid URI path segment: ${segment}`);
    }
  };

  if (host === "packs") {
    if (segments.length !== 2) {
      throw new Error(`Invalid packs URI: ${uri}`);
    }
    const [type, id] = segments;
    ensureSegment(type);
    ensureSegment(id);

    const mapping = PACK_MAPPINGS.find((entry) => entry.dir === type);
    if (!mapping) {
      throw new Error(`Unknown packs type: ${type}`);
    }

    return {
      relPath: path.join("Packs", mapping.dir, `${id}${mapping.suffix}`),
      mimeType: mapping.mimeType,
    };
  }

  if (host === "essentials") {
    if (segments.length !== 1) {
      throw new Error(`Invalid essentials URI: ${uri}`);
    }
    const [id] = segments;
    ensureSegment(id);

    return {
      relPath: path.join("Packs", "essentials", `${id}.md`),
      mimeType: ESSENTIALS_MAPPING.mimeType,
    };
  }

  throw new Error(`Unsupported URI host: ${host}`);
}

export async function readResource(
  root: string,
  uri: string
): Promise<{ text: string; mimeType: string; relPath: string }>
{
  const { relPath, mimeType } = parseUri(uri);
  await assertPacksDirectory(root);

  try {
    const safePath = await resolveSafePath(root, relPath);
    const text = await fs.readFile(safePath, "utf8");
    return { text, mimeType, relPath };
  } catch (error) {
    if (error instanceof ResourceNotFoundError) {
      throw new Error(`Resource not found for URI ${uri}; expected ${relPath}`);
    }
    throw error;
  }
}
