import { spawn } from "node:child_process";
import { constants as fsConstants } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

type SessionCommand = {
  root: string;
  sessionId: string;
};

type PersonaTaskCommand = {
  root: string;
  personaId: string;
  taskId: string;
  kitOverrides?: string[];
};

type ExportOrGraphCommand = SessionCommand | PersonaTaskCommand;

export type PersonakitCommand =
  | { kind: "validate"; root: string }
  | ({ kind: "export" } & ExportOrGraphCommand)
  | ({ kind: "graph" } & ExportOrGraphCommand);

export class PersonakitCLIError extends Error {
  readonly stderr: string;
  readonly exitCode: number;

  constructor(message: string, stderr: string, exitCode: number) {
    super(message);
    this.name = "PersonakitCLIError";
    this.stderr = stderr;
    this.exitCode = exitCode;
  }
}

function packageRoot(): string {
  const currentDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(currentDir, "..");
}

function defaultBinCandidates(): string[] {
  const repoRoot = path.resolve(packageRoot(), "..");
  return [
    path.resolve(repoRoot, ".build", "debug", "personakit"),
    path.resolve(repoRoot, ".build", "release", "personakit"),
  ];
}

async function ensureExecutable(binPath: string): Promise<void> {
  await fs.access(binPath, fsConstants.X_OK);
}

export async function resolvePersonakitBin(): Promise<string> {
  const envBin = process.env.PERSONAKIT_BIN?.trim();
  if (envBin) {
    const resolved = path.resolve(envBin);
    if (path.basename(resolved) !== "personakit") {
      throw new Error("PERSONAKIT_BIN must point to the personakit binary.");
    }
    try {
      await ensureExecutable(resolved);
    } catch (error: any) {
      throw new Error(
        `PERSONAKIT_BIN is not executable: ${resolved} (${error?.message ?? String(error)})`
      );
    }
    return resolved;
  }

  const candidates = defaultBinCandidates();
  for (const candidate of candidates) {
    try {
      await ensureExecutable(candidate);
      return candidate;
    } catch {
      continue;
    }
  }

  throw new Error(
    "Unable to locate the personakit binary. Set PERSONAKIT_BIN or build it at " +
      candidates.join(" or ") +
      "."
  );
}

function buildArgs(command: PersonakitCommand): string[] {
  if (!command.root.trim()) {
    throw new Error("Root path is required.");
  }

  if (command.kind === "validate") {
    return ["validate", "--root", command.root];
  }

  const baseArgs = [command.kind, "--root", command.root];

  if ("sessionId" in command) {
    const sessionId = command.sessionId.trim();
    if (!sessionId) {
      throw new Error("Session id is required.");
    }
    baseArgs.push("--session", sessionId);
    return baseArgs;
  }

  if (!command.personaId.trim()) {
    throw new Error("Persona id is required.");
  }
  if (!command.taskId.trim()) {
    throw new Error("Task id is required.");
  }

  baseArgs.push("--persona", command.personaId, "--task", command.taskId);

  const kitOverrides = (command.kitOverrides ?? [])
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
  if (kitOverrides.length > 0) {
    baseArgs.push("--kits", kitOverrides.join(","));
  }

  return baseArgs;
}

function spawnPersonakit(
  binPath: string,
  args: string[]
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  return new Promise((resolve, reject) => {
    const child = spawn(binPath, args, { stdio: ["ignore", "pipe", "pipe"] });
    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];

    child.stdout.on("data", (chunk) => stdout.push(Buffer.from(chunk)));
    child.stderr.on("data", (chunk) => stderr.push(Buffer.from(chunk)));

    child.on("error", (error) => {
      reject(error);
    });

    child.on("close", (code) => {
      const output = Buffer.concat(stdout).toString("utf8");
      const errOutput = Buffer.concat(stderr).toString("utf8");
      resolve({
        stdout: output,
        stderr: errOutput,
        exitCode: code ?? 1,
      });
    });
  });
}

export async function runPersonakit(command: PersonakitCommand): Promise<string> {
  const binPath = await resolvePersonakitBin();
  const args = buildArgs(command);

  const { stdout, stderr, exitCode } = await spawnPersonakit(binPath, args);
  if (exitCode !== 0) {
    const message =
      stderr.trim() ||
      `personakit ${args.join(" ")} failed with exit code ${exitCode}.`;
    throw new PersonakitCLIError(message, stderr, exitCode);
  }

  return stdout;
}
