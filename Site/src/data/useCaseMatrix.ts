export type UseCaseFit = "High" | "Medium" | "Low";

export interface UseCaseRow {
  alternative: string;
  fit: UseCaseFit;
  primaryValue: string;
  surface: string;
  useCase: string;
}

export const useCaseMatrix: UseCaseRow[] = [
  {
    alternative: "Use the agent directly for one-off edits",
    fit: "High",
    primaryValue: "Role scope stop points and authorized adapter matter",
    surface: "CLI validate, contract, run dry-run",
    useCase: "Small repeatable CLI changes",
  },
  {
    alternative: "Manual prompt if no MCP client exists",
    fit: "High",
    primaryValue: "Agent needs read-only contract and provenance",
    surface: "MCP resources and context tools",
    useCase: "MCP-aware agent grounding",
  },
  {
    alternative: "Ad-hoc review checklist for a one-time review",
    fit: "High",
    primaryValue: "Review identity, acceptance criteria, and stop points matter",
    surface: "CLI export, MCP contract, or Studio preview",
    useCase: "Behavior-preserving bugfix review",
  },
  {
    alternative: "Plain checklist for one release",
    fit: "High",
    primaryValue: "Repeatable review persona and checklist are durable",
    surface: "CLI export or Studio session preview",
    useCase: "Release readiness review",
  },
  {
    alternative: "Repo policy docs only",
    fit: "High",
    primaryValue: "Shared rules prevent repeated prompt setup",
    surface: "Pack format plus CLI validate",
    useCase: "Public contributor starter root",
  },
  {
    alternative: "Manual JSON editing for one-off pack changes",
    fit: "High",
    primaryValue: "Reduces repeated setup, schema rediscovery, and repair-loop overhead",
    surface: "CLI create dry-run, validate, contract",
    useCase: "PersonaKit pack authoring",
  },
  {
    alternative: "Policy docs alone when no AI agent is involved",
    fit: "High",
    primaryValue: "Forbidden capabilities should be visible before work starts",
    surface: "CLI contract or MCP trace",
    useCase: "High-risk repo coding session",
  },
  {
    alternative: "Slash skill or saved prompt",
    fit: "Medium",
    primaryValue: "Useful only if it becomes a repeated work mode",
    surface: "Possibly CLI export",
    useCase: "One-time prompt helper",
  },
  {
    alternative: "Notes, design docs, and discussion",
    fit: "Medium",
    primaryValue: "Wait until recurring work modes are known",
    surface: "Possibly Studio for drafting",
    useCase: "New project exploration",
  },
  {
    alternative: "Chat, notes, whiteboard, or design doc",
    fit: "Low",
    primaryValue: "Boundaries are not known yet",
    surface: "None",
    useCase: "Open-ended product ideation",
  },
  {
    alternative: "Editor formatter, script, or slash skill",
    fit: "Low",
    primaryValue: "No durable contract needed",
    surface: "None",
    useCase: "Formatter invocation",
  },
  {
    alternative: "CI/CD pipeline with human approval",
    fit: "Low",
    primaryValue: "Execution and approvals belong in CI/CD",
    surface: "None",
    useCase: "Deployment workflow",
  },
  {
    alternative: "Dedicated orchestration platform",
    fit: "Low",
    primaryValue: "V1 explicitly excludes orchestration, memory, and continuation",
    surface: "None",
    useCase: "Long-running agent swarm",
  },
  {
    alternative: "Secret manager",
    fit: "Low",
    primaryValue: "PersonaKit is not a vault or permission broker",
    surface: "None",
    useCase: "Secret retrieval",
  },
  {
    alternative: "Issue tracker or project board",
    fit: "Low",
    primaryValue: "Sessions are contracts, not mutable work items",
    surface: "None",
    useCase: "Ticket tracking",
  },
];
