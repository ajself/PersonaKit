import { spawn } from "node:child_process";
import { constants as fsConstants } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

type SessionCommand = {
  root: string;
  sessionId: string;
};

type PersonaDirectiveCommand = {
  root: string;
  personaId: string;
  directiveId: string;
  kitOverrides?: string[];
};

type ExportOrGraphCommand = SessionCommand | PersonaDirectiveCommand;

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

// Swift CLI invocation notes:
// - Default mode should NOT pass --root. The CLI then discovers project/global
//   scopes based on the subprocess cwd.
// - Override mode should pass --root explicitly, but only when the caller opts
//   in via PERSONAKIT_ROOT_OVERRIDE=1 (and provides PERSONAKIT_ROOT).
function buildArgs(command: PersonakitCommand, rootOverride?: string): string[] {
  const rootArg = rootOverride?.trim();

  if (command.kind === "validate") {
    const args: string[] = ["validate"];
    if (rootArg) {
      args.push("--root", rootArg);
    }
    return args;
  }

  const baseArgs: string[] = [command.kind];
  if (rootArg) {
    baseArgs.push("--root", rootArg);
  }

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
  if (!command.directiveId.trim()) {
    throw new Error("Directive id is required.");
  }

  baseArgs.push("--persona", command.personaId, "--directive", command.directiveId);

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
  args: string[],
  cwd: string
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  return new Promise((resolve, reject) => {
    const child = spawn(binPath, args, { stdio: ["ignore", "pipe", "pipe"], cwd });
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
  const root = command.root.trim();
  const overrideMode = process.env.PERSONAKIT_ROOT_OVERRIDE?.trim() === "1";
  if (overrideMode && !root) {
    throw new Error("PERSONAKIT_ROOT is required when PERSONAKIT_ROOT_OVERRIDE=1.");
  }
  const args = buildArgs(command, overrideMode ? root : undefined);
  const cwd = overrideMode ? process.cwd() : root || process.cwd();

  const { stdout, stderr, exitCode } = await spawnPersonakit(binPath, args, cwd);
  if (exitCode !== 0) {
    const message =
      stderr.trim() ||
      `personakit ${args.join(" ")} failed with exit code ${exitCode}.`;
    throw new PersonakitCLIError(message, stderr, exitCode);
  }

  return stdout;
}
