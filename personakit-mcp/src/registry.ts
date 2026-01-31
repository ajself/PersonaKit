import fs from "node:fs/promises";
import path from "node:path";
import { assertPacksDirectory, relativePath } from "./fs-utils.js";
import {
  IntentTemplate,
  Kit,
  Persona,
  Registry,
  Skill,
  Task,
} from "./types.js";
import { ESSENTIALS_MAPPING, PACK_MAPPINGS, toPosixPath } from "./utils.js";

export type PackLoadError = {
  path: string;
  message: string;
};

export class PackLoadErrorList extends Error {
  errors: PackLoadError[];

  constructor(errors: PackLoadError[]) {
    super("Failed to load PersonaKit packs.");
    this.errors = errors;
  }
}

type DecodeResult<T> = { value: T } | { error: string };

type EntityDecoder<T> = (data: unknown) => DecodeResult<T>;

type LoadResult<T> = {
  entities: Map<string, T>;
  errors: PackLoadError[];
};

function asObject(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function readString(obj: Record<string, unknown>, field: string): DecodeResult<string> {
  const value = obj[field];
  if (typeof value !== "string") {
    return { error: `Expected string for field "${field}".` };
  }
  return { value };
}

function readBoolean(obj: Record<string, unknown>, field: string): DecodeResult<boolean> {
  const value = obj[field];
  if (typeof value !== "boolean") {
    return { error: `Expected boolean for field "${field}".` };
  }
  return { value };
}

function readStringArray(
  obj: Record<string, unknown>,
  field: string,
  required: boolean
): DecodeResult<string[]> {
  const value = obj[field];
  if (value === undefined || value === null) {
    if (required) {
      return { error: `Missing required field "${field}".` };
    }
    return { value: [] };
  }
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) {
    return { error: `Expected string array for field "${field}".` };
  }
  return { value };
}

function readOptionalStringArray(
  obj: Record<string, unknown>,
  field: string
): DecodeResult<string[] | undefined> {
  const value = obj[field];
  if (value === undefined || value === null) {
    return { value: undefined };
  }
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) {
    return { error: `Expected string array for field "${field}".` };
  }
  return { value };
}

function decodePersona(data: unknown): DecodeResult<Persona> {
  const obj = asObject(data);
  if (!obj) {
    return { error: "Expected object at root." };
  }

  const id = readString(obj, "id");
  if ("error" in id) return id;
  const version = readString(obj, "version");
  if ("error" in version) return version;
  const name = readString(obj, "name");
  if ("error" in name) return name;
  const summary = readString(obj, "summary");
  if ("error" in summary) return summary;
  const responsibilities = readStringArray(obj, "responsibilities", true);
  if ("error" in responsibilities) return responsibilities;
  const values = readStringArray(obj, "values", true);
  if ("error" in values) return values;
  const nonGoals = readStringArray(obj, "nonGoals", true);
  if ("error" in nonGoals) return nonGoals;
  const defaultKitIds = readStringArray(obj, "defaultKitIds", true);
  if ("error" in defaultKitIds) return defaultKitIds;
  const allowedSkillIds = readStringArray(obj, "allowedSkillIds", true);
  if ("error" in allowedSkillIds) return allowedSkillIds;
  const forbiddenSkillIds = readStringArray(obj, "forbiddenSkillIds", true);
  if ("error" in forbiddenSkillIds) return forbiddenSkillIds;

  return {
    value: {
      id: id.value,
      version: version.value,
      name: name.value,
      summary: summary.value,
      responsibilities: responsibilities.value,
      values: values.value,
      nonGoals: nonGoals.value,
      defaultKitIds: defaultKitIds.value,
      allowedSkillIds: allowedSkillIds.value,
      forbiddenSkillIds: forbiddenSkillIds.value,
    },
  };
}

function decodeKit(data: unknown): DecodeResult<Kit> {
  const obj = asObject(data);
  if (!obj) {
    return { error: "Expected object at root." };
  }

  const id = readString(obj, "id");
  if ("error" in id) return id;
  const version = readString(obj, "version");
  if ("error" in version) return version;
  const name = readString(obj, "name");
  if ("error" in name) return name;
  const summary = readString(obj, "summary");
  if ("error" in summary) return summary;
  const essentialIds = readStringArray(obj, "essentialIds", true);
  if ("error" in essentialIds) return essentialIds;
  const intentTemplateIds = readOptionalStringArray(obj, "intentTemplateIds");
  if ("error" in intentTemplateIds) return intentTemplateIds;
  const skillIds = readOptionalStringArray(obj, "skillIds");
  if ("error" in skillIds) return skillIds;

  return {
    value: {
      id: id.value,
      version: version.value,
      name: name.value,
      summary: summary.value,
      essentialIds: essentialIds.value,
      intentTemplateIds: intentTemplateIds.value,
      skillIds: skillIds.value,
    },
  };
}

function decodeTask(data: unknown): DecodeResult<Task> {
  const obj = asObject(data);
  if (!obj) {
    return { error: "Expected object at root." };
  }

  const id = readString(obj, "id");
  if ("error" in id) return id;
  const version = readString(obj, "version");
  if ("error" in version) return version;
  const title = readString(obj, "title");
  if ("error" in title) return title;
  const goal = readString(obj, "goal");
  if ("error" in goal) return goal;

  const stepsValue = obj["steps"];
  if (!Array.isArray(stepsValue)) {
    return { error: "Expected array for field \"steps\"." };
  }
  const steps = stepsValue.map((step, index) => {
    const stepObj = asObject(step);
    if (!stepObj) {
      return { error: `Expected object for steps[${index}].` };
    }
    const text = readString(stepObj, "text");
    if ("error" in text) return text;
    let requiresReview: boolean | undefined;
    if ("requiresReview" in stepObj) {
      const review = readBoolean(stepObj, "requiresReview");
      if ("error" in review) return review;
      requiresReview = review.value;
    }
    return { value: { text: text.value, requiresReview } };
  });
  const stepErrors = steps.filter((step) => "error" in step) as Array<{ error: string }>;
  if (stepErrors.length > 0) {
    return { error: stepErrors[0].error };
  }

  const acceptanceCriteria = readStringArray(obj, "acceptanceCriteria", true);
  if ("error" in acceptanceCriteria) return acceptanceCriteria;

  const verificationValue = obj["verification"];
  if (!Array.isArray(verificationValue)) {
    return { error: "Expected array for field \"verification\"." };
  }
  const verification = verificationValue.map((item, index) => {
    const itemObj = asObject(item);
    if (!itemObj) {
      return { error: `Expected object for verification[${index}].` };
    }
    const kind = readString(itemObj, "kind");
    if ("error" in kind) return kind;
    const text = readString(itemObj, "text");
    if ("error" in text) return text;
    return { value: { kind: kind.value, text: text.value } };
  });
  const verificationErrors = verification.filter(
    (item) => "error" in item
  ) as Array<{ error: string }>;
  if (verificationErrors.length > 0) {
    return { error: verificationErrors[0].error };
  }

  const requiresIntentTemplateIds = readStringArray(
    obj,
    "requiresIntentTemplateIds",
    true
  );
  if ("error" in requiresIntentTemplateIds) return requiresIntentTemplateIds;
  const requiresSkillIds = readStringArray(obj, "requiresSkillIds", true);
  if ("error" in requiresSkillIds) return requiresSkillIds;

  return {
    value: {
      id: id.value,
      version: version.value,
      title: title.value,
      goal: goal.value,
      steps: steps.map((step) => (step as { value: Task["steps"][number] }).value),
      acceptanceCriteria: acceptanceCriteria.value,
      verification: verification.map(
        (item) => (item as { value: Task["verification"][number] }).value
      ),
      requiresIntentTemplateIds: requiresIntentTemplateIds.value,
      requiresSkillIds: requiresSkillIds.value,
    },
  };
}

function decodeIntentTemplate(data: unknown): DecodeResult<IntentTemplate> {
  const obj = asObject(data);
  if (!obj) {
    return { error: "Expected object at root." };
  }

  const id = readString(obj, "id");
  if ("error" in id) return id;
  const version = readString(obj, "version");
  if ("error" in version) return version;
  const name = readString(obj, "name");
  if ("error" in name) return name;
  const description = readString(obj, "description");
  if ("error" in description) return description;

  const parametersValue = obj["parameters"];
  if (!Array.isArray(parametersValue)) {
    return { error: "Expected array for field \"parameters\"." };
  }
  const parameters = parametersValue.map((param, index) => {
    const paramObj = asObject(param);
    if (!paramObj) {
      return { error: `Expected object for parameters[${index}].` };
    }
    const paramName = readString(paramObj, "name");
    if ("error" in paramName) return paramName;
    const paramType = readString(paramObj, "type");
    if ("error" in paramType) return paramType;
    const required = readBoolean(paramObj, "required");
    if ("error" in required) return required;
    return {
      value: {
        name: paramName.value,
        type: paramType.value,
        required: required.value,
      },
    };
  });
  const paramErrors = parameters.filter(
    (param) => "error" in param
  ) as Array<{ error: string }>;
  if (paramErrors.length > 0) {
    return { error: paramErrors[0].error };
  }

  const includesEssentialIds = readStringArray(
    obj,
    "includesEssentialIds",
    true
  );
  if ("error" in includesEssentialIds) return includesEssentialIds;
  const requiresSkillIds = readStringArray(obj, "requiresSkillIds", true);
  if ("error" in requiresSkillIds) return requiresSkillIds;

  const riskValue = obj["risk"];
  const riskObj = asObject(riskValue);
  if (!riskObj) {
    return { error: "Expected object for field \"risk\"." };
  }
  const riskLevel = readString(riskObj, "level");
  if ("error" in riskLevel) return riskLevel;
  const requiresHumanReview = readBoolean(riskObj, "requiresHumanReview");
  if ("error" in requiresHumanReview) return requiresHumanReview;
  const riskNotes = readStringArray(riskObj, "notes", true);
  if ("error" in riskNotes) return riskNotes;

  return {
    value: {
      id: id.value,
      version: version.value,
      name: name.value,
      description: description.value,
      parameters: parameters.map(
        (param) => (param as { value: IntentTemplate["parameters"][number] }).value
      ),
      includesEssentialIds: includesEssentialIds.value,
      requiresSkillIds: requiresSkillIds.value,
      risk: {
        level: riskLevel.value,
        requiresHumanReview: requiresHumanReview.value,
        notes: riskNotes.value,
      },
    },
  };
}

function decodeSkill(data: unknown): DecodeResult<Skill> {
  const obj = asObject(data);
  if (!obj) {
    return { error: "Expected object at root." };
  }

  const id = readString(obj, "id");
  if ("error" in id) return id;
  const version = readString(obj, "version");
  if ("error" in version) return version;
  const name = readString(obj, "name");
  if ("error" in name) return name;
  const description = readString(obj, "description");
  if ("error" in description) return description;
  const providedBy = readStringArray(obj, "providedBy", true);
  if ("error" in providedBy) return providedBy;

  const riskValue = obj["risk"];
  const riskObj = asObject(riskValue);
  if (!riskObj) {
    return { error: "Expected object for field \"risk\"." };
  }
  const riskLevel = readString(riskObj, "level");
  if ("error" in riskLevel) return riskLevel;
  const requiresHumanReview = readBoolean(riskObj, "requiresHumanReview");
  if ("error" in requiresHumanReview) return requiresHumanReview;
  const riskNotes = readStringArray(riskObj, "notes", true);
  if ("error" in riskNotes) return riskNotes;

  const notes = readStringArray(obj, "notes", true);
  if ("error" in notes) return notes;

  return {
    value: {
      id: id.value,
      version: version.value,
      name: name.value,
      description: description.value,
      providedBy: providedBy.value,
      risk: {
        level: riskLevel.value,
        requiresHumanReview: requiresHumanReview.value,
        notes: riskNotes.value,
      },
      notes: notes.value,
    },
  };
}

async function loadEntities<T>(
  root: string,
  dirName: string,
  suffix: string,
  decoder: EntityDecoder<T>
): Promise<LoadResult<T>> {
  const packsDir = path.join(root, "Packs", dirName);
  let names: string[] = [];
  const errors: PackLoadError[] = [];

  try {
    const entries = await fs.readdir(packsDir, { withFileTypes: true });
    names = entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(suffix))
      .map((entry) => entry.name)
      .sort();
  } catch (error: any) {
    if (error?.code === "ENOENT") {
      return { entities: new Map(), errors };
    }
    errors.push({
      path: toPosixPath(path.join("Packs", dirName)),
      message: `Failed to read directory: ${error?.message ?? String(error)}`,
    });
    return { entities: new Map(), errors };
  }

  const entities = new Map<string, T>();
  const seenIds = new Map<string, string>();

  for (const name of names) {
    const filePath = path.join(packsDir, name);
    const relPath = relativePath(root, filePath);
    let data: string;
    try {
      data = await fs.readFile(filePath, "utf8");
    } catch (error: any) {
      errors.push({
        path: relPath,
        message: `Failed to read file: ${error?.message ?? String(error)}`,
      });
      continue;
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(data);
    } catch (error: any) {
      errors.push({
        path: relPath,
        message: `Failed to parse JSON: ${error?.message ?? String(error)}`,
      });
      continue;
    }

    const decoded = decoder(parsed);
    if ("error" in decoded) {
      errors.push({
        path: relPath,
        message: decoded.error,
      });
      continue;
    }

    const id = (decoded.value as { id: string }).id;
    const existing = seenIds.get(id);
    if (existing) {
      errors.push({
        path: relPath,
        message: `Duplicate id "${id}" (already defined in ${existing}).`,
      });
      continue;
    }
    seenIds.set(id, relPath);
    entities.set(id, decoded.value);
  }

  return { entities, errors };
}

export async function loadRegistry(root: string): Promise<Registry> {
  await assertPacksDirectory(root);

  const errors: PackLoadError[] = [];

  const personas = await loadEntities(root, "personas", ".persona.json", decodePersona);
  errors.push(...personas.errors);

  const kits = await loadEntities(root, "kits", ".kit.json", decodeKit);
  errors.push(...kits.errors);

  const tasks = await loadEntities(root, "tasks", ".task.json", decodeTask);
  errors.push(...tasks.errors);

  const intents = await loadEntities(
    root,
    "intents",
    ".intent.json",
    decodeIntentTemplate
  );
  errors.push(...intents.errors);

  const skills = await loadEntities(root, "skills", ".skill.json", decodeSkill);
  errors.push(...skills.errors);

  if (errors.length > 0) {
    const sorted = errors
      .map((error) => ({
        path: toPosixPath(error.path),
        message: error.message,
      }))
      .sort((a, b) => {
        if (a.path !== b.path) return a.path.localeCompare(b.path);
        return a.message.localeCompare(b.message);
      });
    throw new PackLoadErrorList(sorted);
  }

  return {
    personasById: personas.entities,
    kitsById: kits.entities,
    tasksById: tasks.entities,
    intentsById: intents.entities,
    skillsById: skills.entities,
  };
}

export const RESOURCE_DIRECTORIES = [
  ...PACK_MAPPINGS.map((mapping) => mapping.dir),
  ESSENTIALS_MAPPING.dir,
];
