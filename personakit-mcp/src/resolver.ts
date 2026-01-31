import fs from "node:fs/promises";
import path from "node:path";
import {
  IntentTemplate,
  Kit,
  Registry,
  ResolvedEssential,
  ResolvedSession,
  SessionDefinition,
  Skill,
} from "./types.js";
import { uniqueSorted } from "./utils.js";

export type ResolverError = {
  entityType: string;
  entityId: string;
  field: string;
  missingId: string;
  message: string;
};

export class ResolverErrorList extends Error {
  errors: ResolverError[];

  constructor(errors: ResolverError[]) {
    super("Failed to resolve PersonaKit session.");
    this.errors = errors;
  }
}

function pushMissing(
  errors: ResolverError[],
  entityType: string,
  entityId: string,
  field: string,
  missingId: string
) {
  errors.push({
    entityType,
    entityId,
    field,
    missingId,
    message: `Missing ${field} id "${missingId}" in ${entityType} ${entityId}.`,
  });
}

function sortErrors(errors: ResolverError[]): ResolverError[] {
  return errors.sort((a, b) => {
    if (a.entityType !== b.entityType) return a.entityType.localeCompare(b.entityType);
    if (a.entityId !== b.entityId) return a.entityId.localeCompare(b.entityId);
    if (a.field !== b.field) return a.field.localeCompare(b.field);
    return a.missingId.localeCompare(b.missingId);
  });
}

async function ensureEssentialFiles(
  root: string,
  essentials: Array<{ id: string; source: { entityType: string; entityId: string; field: string } }>
): Promise<{ essentials: ResolvedEssential[]; errors: ResolverError[] }> {
  const errors: ResolverError[] = [];
  const resolved: ResolvedEssential[] = [];

  for (const entry of essentials) {
    const relPath = path.join("Packs", "essentials", `${entry.id}.md`);
    const absolutePath = path.join(root, relPath);
    try {
      const stat = await fs.stat(absolutePath);
      if (!stat.isFile()) {
        pushMissing(
          errors,
          entry.source.entityType,
          entry.source.entityId,
          entry.source.field,
          entry.id
        );
        continue;
      }
      resolved.push({ id: entry.id, relPath });
    } catch (error: any) {
      if (error?.code === "ENOENT") {
        pushMissing(
          errors,
          entry.source.entityType,
          entry.source.entityId,
          entry.source.field,
          entry.id
        );
        continue;
      }
      throw error;
    }
  }

  return { essentials: resolved, errors };
}

function resolveIntents(
  registry: Registry,
  kitIntents: { id: string; source: { entityType: string; entityId: string; field: string } }[],
  taskIntents: { id: string; source: { entityType: string; entityId: string; field: string } }[]
): { intents: IntentTemplate[]; errors: ResolverError[] } {
  const errors: ResolverError[] = [];
  const intentIds = uniqueSorted([
    ...kitIntents.map((entry) => entry.id),
    ...taskIntents.map((entry) => entry.id),
  ]);

  const intents: IntentTemplate[] = [];
  for (const id of intentIds) {
    const intent = registry.intentsById.get(id);
    if (!intent) {
      const source = kitIntents.find((entry) => entry.id === id)?.source ??
        taskIntents.find((entry) => entry.id === id)?.source;
      if (source) {
        pushMissing(errors, source.entityType, source.entityId, source.field, id);
      } else {
        pushMissing(errors, "session", "session", "intentTemplateIds", id);
      }
      continue;
    }
    intents.push(intent);
  }

  return { intents, errors };
}

function resolveSkills(
  registry: Registry,
  skillEntries: { id: string; source: { entityType: string; entityId: string; field: string } }[]
): { skills: Skill[]; errors: ResolverError[] } {
  const errors: ResolverError[] = [];
  const skillIds = uniqueSorted(skillEntries.map((entry) => entry.id));
  const skills: Skill[] = [];

  for (const id of skillIds) {
    const skill = registry.skillsById.get(id);
    if (!skill) {
      const source = skillEntries.find((entry) => entry.id === id)?.source;
      if (source) {
        pushMissing(errors, source.entityType, source.entityId, source.field, id);
      } else {
        pushMissing(errors, "session", "session", "skillIds", id);
      }
      continue;
    }
    skills.push(skill);
  }

  return { skills, errors };
}

export async function resolveSession(
  root: string,
  definition: SessionDefinition,
  registry: Registry
): Promise<ResolvedSession> {
  const errors: ResolverError[] = [];

  const persona = registry.personasById.get(definition.personaId);
  if (!persona) {
    pushMissing(errors, "session", definition.personaId, "personaId", definition.personaId);
  }

  const task = registry.tasksById.get(definition.taskId);
  if (!task) {
    pushMissing(errors, "session", definition.taskId, "taskId", definition.taskId);
  }

  if (errors.length > 0) {
    throw new ResolverErrorList(sortErrors(errors));
  }

  const kitOverrides = definition.kitOverrides ?? [];
  const baseKitIds = persona ? persona.defaultKitIds : [];
  const appliedKitIds = uniqueSorted([...baseKitIds, ...kitOverrides]);

  const kits: Kit[] = [];
  for (const kitId of appliedKitIds) {
    const kit = registry.kitsById.get(kitId);
    if (!kit) {
      const source = baseKitIds.includes(kitId)
        ? { entityType: "persona", entityId: persona!.id, field: "defaultKitIds" }
        : { entityType: "session", entityId: "kitOverrides", field: "kitOverrides" };
      pushMissing(errors, source.entityType, source.entityId, source.field, kitId);
      continue;
    }
    kits.push(kit);
  }

  const kitIntentEntries: { id: string; source: { entityType: string; entityId: string; field: string } }[] = [];
  const kitSkillEntries: { id: string; source: { entityType: string; entityId: string; field: string } }[] = [];
  const kitEssentialEntries: { id: string; source: { entityType: string; entityId: string; field: string } }[] = [];

  for (const kit of kits) {
    for (const intentId of kit.intentTemplateIds ?? []) {
      kitIntentEntries.push({
        id: intentId,
        source: { entityType: "kit", entityId: kit.id, field: "intentTemplateIds" },
      });
    }
    for (const skillId of kit.skillIds ?? []) {
      kitSkillEntries.push({
        id: skillId,
        source: { entityType: "kit", entityId: kit.id, field: "skillIds" },
      });
    }
    for (const essentialId of kit.essentialIds) {
      kitEssentialEntries.push({
        id: essentialId,
        source: { entityType: "kit", entityId: kit.id, field: "essentialIds" },
      });
    }
  }

  const taskIntentEntries = task!.requiresIntentTemplateIds.map((id) => ({
    id,
    source: { entityType: "task", entityId: task!.id, field: "requiresIntentTemplateIds" },
  }));

  const taskSkillEntries = task!.requiresSkillIds.map((id) => ({
    id,
    source: { entityType: "task", entityId: task!.id, field: "requiresSkillIds" },
  }));

  const { intents, errors: intentErrors } = resolveIntents(
    registry,
    kitIntentEntries,
    taskIntentEntries
  );
  errors.push(...intentErrors);

  const intentSkillEntries: { id: string; source: { entityType: string; entityId: string; field: string } }[] = [];
  const intentEssentialEntries: { id: string; source: { entityType: string; entityId: string; field: string } }[] = [];

  for (const intent of intents) {
    for (const skillId of intent.requiresSkillIds) {
      intentSkillEntries.push({
        id: skillId,
        source: { entityType: "intent", entityId: intent.id, field: "requiresSkillIds" },
      });
    }
    for (const essentialId of intent.includesEssentialIds) {
      intentEssentialEntries.push({
        id: essentialId,
        source: { entityType: "intent", entityId: intent.id, field: "includesEssentialIds" },
      });
    }
  }

  const { skills, errors: skillErrors } = resolveSkills(registry, [
    ...kitSkillEntries,
    ...taskSkillEntries,
    ...intentSkillEntries,
  ]);
  errors.push(...skillErrors);

  const essentialSources = new Map<
    string,
    { entityType: string; entityId: string; field: string }
  >();
  for (const entry of [...kitEssentialEntries, ...intentEssentialEntries]) {
    if (!essentialSources.has(entry.id)) {
      essentialSources.set(entry.id, entry.source);
    }
  }
  const essentialResult = await ensureEssentialFiles(
    root,
    Array.from(essentialSources.entries()).map(([id, source]) => ({ id, source }))
  );
  errors.push(...essentialResult.errors);

  if (errors.length > 0) {
    throw new ResolverErrorList(sortErrors(errors));
  }

  return {
    persona: persona!,
    task: task!,
    kits: kits.sort((a, b) => a.id.localeCompare(b.id)),
    intents: intents.sort((a, b) => a.id.localeCompare(b.id)),
    skills: skills.sort((a, b) => a.id.localeCompare(b.id)),
    essentials: essentialResult.essentials.sort((a, b) => a.id.localeCompare(b.id)),
  };
}
