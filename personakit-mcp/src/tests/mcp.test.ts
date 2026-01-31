import assert from "node:assert/strict";
import path from "node:path";
import { test } from "node:test";
import { resolvePersonakitBin, runPersonakit } from "../personakit-cli.js";
import { getPromptContent, listPrompts } from "../prompts.js";
import { listResources, readResource } from "../resources.js";

const cwd = process.cwd();
const repoRoot = path.basename(cwd) === "personakit-mcp" ? path.resolve(cwd, "..") : cwd;
const fixtureRoot = path.resolve(repoRoot, "Fixtures/kit-root");
const exportOutput = await runPersonakit({
  kind: "export",
  root: fixtureRoot,
  personaId: "senior-swiftui-engineer",
  taskId: "apply-style",
});

const graphOutput = await runPersonakit({
  kind: "graph",
  root: fixtureRoot,
  personaId: "senior-swiftui-engineer",
  taskId: "apply-style",
});

test("prompts/list returns stable prompt ids", () => {
  const prompts = listPrompts();
  const ids = prompts.map((prompt) => prompt.id);
  assert.deepEqual(ids, ["personakit.session.export", "personakit.session.graph"]);
});

test("prompts/get export returns deterministic output", async () => {
  const output = await getPromptContent(fixtureRoot, "personakit.session.export", {
    personaId: "senior-swiftui-engineer",
    taskId: "apply-style",
  });
  assert.equal(output, exportOutput);
});

test("prompts/get export supports sessionId", async () => {
  const output = await getPromptContent(fixtureRoot, "personakit.session.export", {
    sessionId: "senior-swiftui-engineer_apply-style",
  });
  assert.equal(output, exportOutput);
});

test("prompts/get graph returns deterministic output", async () => {
  const output = await getPromptContent(fixtureRoot, "personakit.session.graph", {
    personaId: "senior-swiftui-engineer",
    taskId: "apply-style",
  });
  assert.equal(output, graphOutput);
});

test("prompts/get graph supports sessionId", async () => {
  const output = await getPromptContent(fixtureRoot, "personakit.session.graph", {
    sessionId: "senior-swiftui-engineer_apply-style",
  });
  assert.equal(output, graphOutput);
});

test("resources/read returns correct mime types", async () => {
  const persona = await readResource(
    fixtureRoot,
    "personakit://packs/personas/senior-swiftui-engineer"
  );
  assert.equal(persona.mimeType, "application/json");

  const essential = await readResource(
    fixtureRoot,
    "personakit://essentials/swiftui-style-guide"
  );
  assert.equal(essential.mimeType, "text/markdown");
});

test("resources/list returns sorted URIs", async () => {
  const resources = await listResources(fixtureRoot);
  const uris = resources.map((resource) => resource.uri);
  const sorted = uris.slice().sort((a, b) => a.localeCompare(b));
  assert.deepEqual(uris, sorted);
});

test("resources/read not found error includes URI and expected path", async () => {
  const uri = "personakit://packs/personas/missing-persona";
  try {
    await readResource(fixtureRoot, uri);
    assert.fail("Expected error");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    assert.ok(message.includes(uri));
    assert.ok(message.includes("Packs/personas/missing-persona.persona.json"));
  }
});

test("personakit cli rejects non-personakit binaries", async () => {
  const original = process.env.PERSONAKIT_BIN;
  process.env.PERSONAKIT_BIN = "/bin/ls";
  try {
    await assert.rejects(
      async () => resolvePersonakitBin(),
      /personakit binary/
    );
  } finally {
    if (original === undefined) {
      delete process.env.PERSONAKIT_BIN;
    } else {
      process.env.PERSONAKIT_BIN = original;
    }
  }
});
