import fs from "node:fs/promises";
import path from "node:path";
import { ResolvedEssential, ResolvedSession } from "./types.js";
import { uniqueSorted } from "./utils.js";

function ensureTrailingNewline(content: string): string {
  if (content.endsWith("\n")) {
    return content;
  }
  return `${content}\n`;
}

async function loadEssentials(
  root: string,
  essentials: ResolvedEssential[]
): Promise<ResolvedEssential[]> {
  const result: ResolvedEssential[] = [];
  for (const essential of essentials) {
    const filePath = path.join(root, essential.relPath);
    const content = await fs.readFile(filePath, "utf8");
    result.push({
      id: essential.id,
      relPath: essential.relPath,
      content: ensureTrailingNewline(content),
    });
  }
  return result;
}

function appendListSection(
  title: string,
  items: string[],
  appendLine: (line?: string) => void
) {
  if (items.length === 0) {
    return;
  }
  appendLine("");
  appendLine(`${title}:`);
  for (const item of items) {
    appendLine(`- ${item}`);
  }
}

export function renderExport(session: ResolvedSession, essentials: ResolvedEssential[]): string {
  let output = "";
  const persona = session.persona;
  const task = session.task;

  const appendLine = (line = "") => {
    output += line;
    output += "\n";
  };

  appendLine("# Persona");
  appendLine(`Name: ${persona.name}`);
  appendLine(`Id: ${persona.id}`);
  if (persona.summary.length > 0) {
    appendLine(`Summary: ${persona.summary}`);
  }

  appendListSection("Responsibilities", persona.responsibilities, appendLine);
  appendListSection("Values", persona.values, appendLine);
  appendListSection("Non-goals", persona.nonGoals, appendLine);
  appendListSection(
    "Allowed Skills",
    persona.allowedSkillIds.slice().sort(),
    appendLine
  );
  appendListSection(
    "Forbidden Skills",
    persona.forbiddenSkillIds.slice().sort(),
    appendLine
  );

  appendLine();
  appendLine("# Applied Kits");
  for (const kit of session.kits) {
    appendLine(`- ${kit.name} (${kit.id})`);
  }

  appendLine();
  appendLine("# Essentials");
  const sortedEssentials = essentials.slice().sort((a, b) => a.id.localeCompare(b.id));
  sortedEssentials.forEach((essential, index) => {
    appendLine(`## ${essential.id}`);
    output += essential.content ?? "";
    if (index < sortedEssentials.length - 1) {
      appendLine();
    }
  });

  appendLine();
  appendLine("# Task");
  appendLine(`Title: ${task.title}`);
  appendLine(`Id: ${task.id}`);
  appendLine(`Goal: ${task.goal}`);

  if (task.steps.length > 0) {
    appendLine();
    appendLine("Steps:");
    task.steps.forEach((step, index) => {
      let line = `${index + 1}. ${step.text}`;
      if (step.requiresReview === true) {
        line += " (requires review)";
      }
      appendLine(line);
    });
  }

  appendListSection("Acceptance Criteria", task.acceptanceCriteria, appendLine);

  if (task.verification.length > 0) {
    appendLine();
    appendLine("Verification:");
    for (const item of task.verification) {
      appendLine(`- ${item.kind}: ${item.text}`);
    }
  }

  const stopPoints = task.steps
    .filter((step) => step.requiresReview === true)
    .map((step) => step.text);
  appendListSection("Stop Points", stopPoints, appendLine);

  appendLine();
  appendLine("# Intent Templates");
  session.intents.forEach((intent, index) => {
    appendLine(`## ${intent.id}`);
    appendLine(`Name: ${intent.name}`);
    appendLine(`Id: ${intent.id}`);
    appendLine(`Description: ${intent.description}`);

    if (intent.parameters.length > 0) {
      appendLine();
      appendLine("Parameters:");
      for (const parameter of intent.parameters) {
        const requiredLabel = parameter.required ? "required" : "optional";
        appendLine(`- ${parameter.name} (${parameter.type}, ${requiredLabel})`);
      }
    }

    appendLine();
    appendLine("Risk:");
    appendLine(`- Level: ${intent.risk.level}`);
    appendLine(`- Requires human review: ${intent.risk.requiresHumanReview}`);
    if (intent.risk.notes.length > 0) {
      appendLine("- Notes:");
      for (const note of intent.risk.notes) {
        appendLine(`  - ${note}`);
      }
    }

    appendListSection(
      "Required Skills",
      intent.requiresSkillIds.slice().sort(),
      appendLine
    );
    appendListSection(
      "Included Essentials",
      intent.includesEssentialIds.slice().sort(),
      appendLine
    );

    if (index < session.intents.length - 1) {
      appendLine();
    }
  });

  appendLine();
  appendLine("# Skill Awareness");
  session.skills.forEach((skill, index) => {
    appendLine(`## ${skill.id}`);
    appendLine(`Name: ${skill.name}`);
    appendLine(`Id: ${skill.id}`);
    appendLine(`Description: ${skill.description}`);

    if (skill.providedBy.length > 0) {
      appendLine();
      appendLine("Provided By:");
      for (const provider of skill.providedBy) {
        appendLine(`- ${provider}`);
      }
    }

    appendLine();
    appendLine("Risk:");
    appendLine(`- Level: ${skill.risk.level}`);
    appendLine(`- Requires human review: ${skill.risk.requiresHumanReview}`);
    if (skill.risk.notes.length > 0) {
      appendLine("- Notes:");
      for (const note of skill.risk.notes) {
        appendLine(`  - ${note}`);
      }
    }

    if (skill.notes.length > 0) {
      appendLine();
      appendLine("Notes:");
      for (const note of skill.notes) {
        appendLine(`- ${note}`);
      }
    }

    if (index < session.skills.length - 1) {
      appendLine();
    }
  });

  return output;
}

export async function buildExportOutput(
  root: string,
  session: ResolvedSession
): Promise<string> {
  const essentials = await loadEssentials(root, session.essentials);
  return renderExport(session, essentials);
}

export function renderGraph(session: ResolvedSession, kitOverrides: string[]): string {
  const persona = session.persona;
  const task = session.task;
  const overrides = uniqueSorted(kitOverrides);
  const overrideDisplay = overrides.length === 0 ? "none" : overrides.join(", ");

  const appliedKits = session.kits.slice().sort((a, b) => a.id.localeCompare(b.id));
  const kitById = new Map(appliedKits.map((kit) => [kit.id, kit]));

  const defaultKitIds = uniqueSorted(persona.defaultKitIds);
  const defaultKitLines = defaultKitIds.map((kitId) => {
    const kit = kitById.get(kitId);
    if (kit) {
      return `- ${formatLine(kit.id, kit.name)}`;
    }
    return `- ${kitId}`;
  });

  const appliedKitLines = appliedKits.map((kit) => `- ${formatLine(kit.id, kit.name)}`);

  const kitsToEssentialsLines = appliedKits.flatMap((kit) => {
    const lines = [kit.id];
    const essentials = uniqueSorted(kit.essentialIds);
    lines.push(...essentials.map((id) => `  - essential:${id}`));
    return lines;
  });

  const kitsToIntentLines = appliedKits.flatMap((kit) => {
    const lines = [kit.id];
    const intents = uniqueSorted(kit.intentTemplateIds ?? []);
    lines.push(...intents.map((id) => `  - intent:${id}`));
    return lines;
  });

  const kitsToSkillLines = appliedKits.flatMap((kit) => {
    const lines = [kit.id];
    const skills = uniqueSorted(kit.skillIds ?? []);
    lines.push(...skills.map((id) => `  - skill:${id}`));
    return lines;
  });

  const taskIntentLines = uniqueSorted(task.requiresIntentTemplateIds).map(
    (id) => `- intent:${id}`
  );
  const taskSkillLines = uniqueSorted(task.requiresSkillIds).map((id) => `- skill:${id}`);

  const resolvedEssentialLines = session.essentials
    .map((essential) => essential.id)
    .sort()
    .map((id) => `- ${id}`);
  const resolvedIntentLines = session.intents
    .map((intent) => intent.id)
    .sort()
    .map((id) => `- ${id}`);
  const resolvedSkillLines = session.skills
    .map((skill) => skill.id)
    .sort()
    .map((id) => `- ${id}`);

  const lines: string[] = [];
  lines.push("# Graph");
  lines.push(`Persona: ${formatLine(persona.id, persona.name)}`);
  lines.push(`Task: ${formatLine(task.id, task.title)}`);
  lines.push(`Kit overrides: ${overrideDisplay}`);

  appendSection(lines, "## Persona default kits", defaultKitLines);
  appendSection(lines, "## Applied kits (after overrides)", appliedKitLines);
  appendSection(lines, "## Kits → Essentials", kitsToEssentialsLines);
  appendSection(lines, "## Kits → Intent templates", kitsToIntentLines);
  appendSection(lines, "## Kits → Skills", kitsToSkillLines);
  appendSection(lines, "## Task → Intent templates", taskIntentLines);
  appendSection(lines, "## Task → Skills", taskSkillLines);

  const finalLines = ["Essentials:", ...resolvedEssentialLines, "Intents:", ...resolvedIntentLines, "Skills:", ...resolvedSkillLines];
  appendSection(lines, "## Final resolved sets", finalLines);

  return lines.join("\n");
}

function formatLine(id: string, name?: string): string {
  const trimmed = name?.trim() ?? "";
  if (!trimmed) {
    return id;
  }
  return `${id} — ${trimmed}`;
}

function appendSection(lines: string[], heading: string, body: string[]) {
  lines.push("");
  lines.push(heading);
  lines.push(...body);
}
