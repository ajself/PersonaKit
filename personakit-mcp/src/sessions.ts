import fs from "node:fs/promises";
import path from "node:path";
import { ResourceNotFoundError, resolveSafePath } from "./fs-utils.js";

export type SessionSpec = {
  id: string;
  personaId: string;
  taskId: string;
  kitOverrides?: string[];
};

function assertString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`Session field ${field} must be a non-empty string.`);
  }
  return value.trim();
}

function assertStringArray(value: unknown, field: string): string[] {
  if (value === undefined) {
    return [];
  }
  if (!Array.isArray(value)) {
    throw new Error(`Session field ${field} must be an array of strings.`);
  }
  const result: string[] = [];
  for (const entry of value) {
    if (typeof entry !== "string" || entry.trim().length === 0) {
      throw new Error(`Session field ${field} must contain only strings.`);
    }
    result.push(entry.trim());
  }
  return result;
}

export async function loadSession(root: string, sessionId: string): Promise<SessionSpec> {
  const trimmedId = sessionId.trim();
  if (!trimmedId) {
    throw new Error("Session id is required.");
  }

  const relPath = path.join("Sessions", `${trimmedId}.session.json`);
  let absPath: string;
  try {
    absPath = await resolveSafePath(root, relPath);
  } catch (error) {
    if (error instanceof ResourceNotFoundError) {
      throw new Error(`Session file not found for ${trimmedId}. Expected ${relPath}.`);
    }
    throw error;
  }

  const content = await fs.readFile(absPath, "utf8");
  let data: any;
  try {
    data = JSON.parse(content);
  } catch (error: any) {
    throw new Error(
      `Failed to decode session file for ${trimmedId}: ${error?.message ?? String(error)}`
    );
  }

  const id = assertString(data.id, "id");
  if (id !== trimmedId) {
    throw new Error(`Session id mismatch in ${relPath}. Expected ${trimmedId}, got ${id}.`);
  }

  const personaId = assertString(data.personaId, "personaId");
  const taskId = assertString(data.taskId, "taskId");
  const kitOverrides = assertStringArray(data.kitOverrides, "kitOverrides");

  return {
    id,
    personaId,
    taskId,
    kitOverrides: kitOverrides.length > 0 ? kitOverrides : undefined,
  };
}
