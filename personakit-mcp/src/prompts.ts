import { PersonakitCLIError, runPersonakit } from "./personakit-cli.js";

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
    description: "Assemble Persona+Kits+Directive into a single Markdown prompt.",
    arguments: [
      { name: "sessionId", description: "Session id (alternative to persona/directive)" },
      { name: "personaId", description: "Persona id" },
      { name: "directiveId", description: "Directive id" },
      { name: "kits", description: "Comma-separated kit ids" },
    ],
  },
  {
    id: "personakit.session.graph",
    name: "Session Graph",
    description: "Print a readable dependency graph for a session.",
    arguments: [
      { name: "sessionId", description: "Session id (alternative to persona/directive)" },
      { name: "personaId", description: "Persona id" },
      { name: "directiveId", description: "Directive id" },
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

type PromptSessionInput =
  | { mode: "session"; sessionId: string }
  | { mode: "persona"; personaId: string; directiveId: string; kitOverrides: string[] };

async function resolvePromptSessionInput(
  args: Record<string, unknown>
): Promise<PromptSessionInput> {
  const sessionId = typeof args.sessionId === "string" ? args.sessionId.trim() : "";
  const hasSession = sessionId.length > 0;

  if (hasSession) {
    if (args.personaId || args.directiveId || args.kits) {
      throw new Error("Provide sessionId or personaId/directiveId/kits, not both.");
    }
    return {
      mode: "session",
      sessionId,
    };
  }

  const personaId = requireArg(args, "personaId");
  const directiveId = requireArg(args, "directiveId");
  const kitOverrides = parseKitOverrides(
    typeof args.kits === "string" ? args.kits : undefined
  );

  return {
    mode: "persona",
    personaId,
    directiveId,
    kitOverrides,
  };
}

export async function getPromptContent(
  root: string,
  promptId: string,
  args: Record<string, unknown>
): Promise<string> {
  const sessionInput = await resolvePromptSessionInput(args);

  if (promptId === "personakit.session.export") {
    if (sessionInput.mode === "session") {
      return await runPersonakit({
        kind: "export",
        root,
        sessionId: sessionInput.sessionId,
      });
    }
    return await runPersonakit({
      kind: "export",
      root,
      personaId: sessionInput.personaId,
      directiveId: sessionInput.directiveId,
      kitOverrides: sessionInput.kitOverrides,
    });
  }

  if (promptId === "personakit.session.graph") {
    if (sessionInput.mode === "session") {
      return await runPersonakit({
        kind: "graph",
        root,
        sessionId: sessionInput.sessionId,
      });
    }
    return await runPersonakit({
      kind: "graph",
      root,
      personaId: sessionInput.personaId,
      directiveId: sessionInput.directiveId,
      kitOverrides: sessionInput.kitOverrides,
    });
  }

  throw new Error(`Unknown prompt id: ${promptId}`);
}

export function formatPromptError(error: unknown): string {
  if (error instanceof PersonakitCLIError) {
    return error.message;
  }
  return error instanceof Error ? error.message : String(error);
}
