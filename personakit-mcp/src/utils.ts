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
    dir: "directives",
    suffix: ".directive.json",
    uriPrefix: "personakit://packs/directives/",
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
