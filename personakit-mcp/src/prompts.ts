import { PersonakitCLIError, runPersonakit } from "./personakit-cli.js";
import { loadSession } from "./sessions.js";

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
      { name: "sessionId", description: "Session id (alternative to persona/task)" },
      { name: "personaId", description: "Persona id" },
      { name: "taskId", description: "Task id" },
      { name: "kits", description: "Comma-separated kit ids" },
    ],
  },
  {
    id: "personakit.session.graph",
    name: "Session Graph",
    description: "Print a readable dependency graph for a session.",
    arguments: [
      { name: "sessionId", description: "Session id (alternative to persona/task)" },
      { name: "personaId", description: "Persona id" },
      { name: "taskId", description: "Task id" },
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

type PromptSessionInput = {
  personaId: string;
  taskId: string;
  kitOverrides: string[];
};

async function resolvePromptSessionInput(
  root: string,
  args: Record<string, unknown>
): Promise<PromptSessionInput> {
  const sessionId = typeof args.sessionId === "string" ? args.sessionId.trim() : "";
  const hasSession = sessionId.length > 0;

  if (hasSession) {
    if (args.personaId || args.taskId || args.kits) {
      throw new Error("Provide sessionId or personaId/taskId/kits, not both.");
    }
    const session = await loadSession(root, sessionId);
    return {
      personaId: session.personaId,
      taskId: session.taskId,
      kitOverrides: session.kitOverrides ?? [],
    };
  }

  const personaId = requireArg(args, "personaId");
  const taskId = requireArg(args, "taskId");
  const kitOverrides = parseKitOverrides(
    typeof args.kits === "string" ? args.kits : undefined
  );

  return {
    personaId,
    taskId,
    kitOverrides,
  };
}

export async function getPromptContent(
  root: string,
  promptId: string,
  args: Record<string, unknown>
): Promise<string> {
  const sessionInput = await resolvePromptSessionInput(root, args);

  if (promptId === "personakit.session.export") {
    return await runPersonakit({
      kind: "export",
      root,
      personaId: sessionInput.personaId,
      taskId: sessionInput.taskId,
      kitOverrides: sessionInput.kitOverrides,
    });
  }

  if (promptId === "personakit.session.graph") {
    return await runPersonakit({
      kind: "graph",
      root,
      personaId: sessionInput.personaId,
      taskId: sessionInput.taskId,
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
