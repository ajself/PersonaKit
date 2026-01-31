import {
  buildExportOutput,
  renderGraph,
} from "./renderers.js";
import { loadRegistry, PackLoadErrorList } from "./registry.js";
import { resolveSession, ResolverErrorList } from "./resolver.js";
import { SessionDefinition } from "./types.js";
import { uniqueSorted } from "./utils.js";

export type PromptDefinition = {
  id: string;
  name: string;
  description: string;
  arguments: Array<{ name: string; description: string; required?: boolean }>;
};

const PROMPTS: PromptDefinition[] = [
  {
    id: "personakit.session.export",
    name: "Session Export",
    description: "Assemble Persona+Kits+Task into a single Markdown prompt.",
    arguments: [
      { name: "personaId", description: "Persona id", required: true },
      { name: "taskId", description: "Task id", required: true },
      { name: "kits", description: "Comma-separated kit ids" },
    ],
  },
  {
    id: "personakit.session.graph",
    name: "Session Graph",
    description: "Print a readable dependency graph for a session.",
    arguments: [
      { name: "personaId", description: "Persona id", required: true },
      { name: "taskId", description: "Task id", required: true },
      { name: "kits", description: "Comma-separated kit ids" },
    ],
  },
];

export function listPrompts(): PromptDefinition[] {
  return PROMPTS.slice().sort((a, b) => a.id.localeCompare(b.id));
}

function parseKitOverrides(value: string | undefined): string[] {
  if (!value) {
    return [];
  }
  return value
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function requireArg(args: Record<string, unknown>, name: string): string {
  const value = args[name];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`Missing required argument: ${name}`);
  }
  return value.trim();
}

export async function getPromptContent(
  root: string,
  promptId: string,
  args: Record<string, unknown>
): Promise<string> {
  const personaId = requireArg(args, "personaId");
  const taskId = requireArg(args, "taskId");
  const kitOverrides = parseKitOverrides(
    typeof args.kits === "string" ? args.kits : undefined
  );

  const definition: SessionDefinition = {
    personaId,
    taskId,
    kitOverrides: kitOverrides.length > 0 ? kitOverrides : undefined,
  };

  const registry = await loadRegistry(root);
  const session = await resolveSession(root, definition, registry);

  if (promptId === "personakit.session.export") {
    return await buildExportOutput(root, session);
  }

  if (promptId === "personakit.session.graph") {
    return renderGraph(session, uniqueSorted(kitOverrides));
  }

  throw new Error(`Unknown prompt id: ${promptId}`);
}

export function formatPromptError(error: unknown): string {
  if (error instanceof PackLoadErrorList) {
    return error.errors
      .map((entry) => `${entry.path}: ${entry.message}`)
      .join("\n");
  }
  if (error instanceof ResolverErrorList) {
    return error.errors
      .map(
        (entry) =>
          `${entry.entityType} ${entry.entityId} ${entry.field}: missing ${entry.missingId}`
      )
      .join("\n");
  }
  return error instanceof Error ? error.message : String(error);
}
