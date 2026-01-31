export type Persona = {
  id: string;
  version: string;
  name: string;
  summary: string;
  responsibilities: string[];
  values: string[];
  nonGoals: string[];
  defaultKitIds: string[];
  allowedSkillIds: string[];
  forbiddenSkillIds: string[];
};

export type Kit = {
  id: string;
  version: string;
  name: string;
  summary: string;
  essentialIds: string[];
  intentTemplateIds?: string[];
  skillIds?: string[];
};

export type TaskStep = {
  text: string;
  requiresReview?: boolean;
};

export type TaskVerificationItem = {
  kind: string;
  text: string;
};

export type Task = {
  id: string;
  version: string;
  title: string;
  goal: string;
  steps: TaskStep[];
  acceptanceCriteria: string[];
  verification: TaskVerificationItem[];
  requiresIntentTemplateIds: string[];
  requiresSkillIds: string[];
};

export type IntentParameter = {
  name: string;
  type: string;
  required: boolean;
};

export type IntentRisk = {
  level: string;
  requiresHumanReview: boolean;
  notes: string[];
};

export type IntentTemplate = {
  id: string;
  version: string;
  name: string;
  description: string;
  parameters: IntentParameter[];
  includesEssentialIds: string[];
  requiresSkillIds: string[];
  risk: IntentRisk;
};

export type SkillRisk = {
  level: string;
  requiresHumanReview: boolean;
  notes: string[];
};

export type Skill = {
  id: string;
  version: string;
  name: string;
  description: string;
  providedBy: string[];
  risk: SkillRisk;
  notes: string[];
};

export type ResolvedEssential = {
  id: string;
  relPath: string;
  content?: string;
};

export type Registry = {
  personasById: Map<string, Persona>;
  kitsById: Map<string, Kit>;
  tasksById: Map<string, Task>;
  intentsById: Map<string, IntentTemplate>;
  skillsById: Map<string, Skill>;
};

export type ResolvedSession = {
  persona: Persona;
  task: Task;
  kits: Kit[];
  intents: IntentTemplate[];
  skills: Skill[];
  essentials: ResolvedEssential[];
};

export type SessionDefinition = {
  personaId: string;
  taskId: string;
  kitOverrides?: string[];
};
