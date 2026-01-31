import path from "node:path";

export type PackMapping = {
  dir: string;
  suffix: string;
  uriPrefix: string;
  mimeType: string;
};

export const MAX_FILE_BYTES = 2 * 1024 * 1024;

export const PACK_MAPPINGS: PackMapping[] = [
  {
    dir: "personas",
    suffix: ".persona.json",
    uriPrefix: "personakit://packs/personas/",
    mimeType: "application/json",
  },
  {
    dir: "kits",
    suffix: ".kit.json",
    uriPrefix: "personakit://packs/kits/",
    mimeType: "application/json",
  },
  {
    dir: "tasks",
    suffix: ".task.json",
    uriPrefix: "personakit://packs/tasks/",
    mimeType: "application/json",
  },
  {
    dir: "intents",
    suffix: ".intent.json",
    uriPrefix: "personakit://packs/intents/",
    mimeType: "application/json",
  },
  {
    dir: "skills",
    suffix: ".skill.json",
    uriPrefix: "personakit://packs/skills/",
    mimeType: "application/json",
  },
];

export const ESSENTIALS_MAPPING: PackMapping = {
  dir: "essentials",
  suffix: ".md",
  uriPrefix: "personakit://essentials/",
  mimeType: "text/markdown",
};

export function uniqueSorted(values: string[]): string[] {
  return Array.from(new Set(values)).sort();
}

export function toPosixPath(value: string): string {
  return value.split(path.sep).join("/");
}
