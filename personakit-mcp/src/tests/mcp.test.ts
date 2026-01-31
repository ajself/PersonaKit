import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { test } from "node:test";
import { getPromptContent, listPrompts } from "../prompts.js";
import { readResource } from "../resources.js";

const fixtureRoot = path.resolve(process.cwd(), "fixtures/kit-root");
const expectedExportPath = path.resolve(process.cwd(), "fixtures/expected/export.md");
const expectedGraphPath = path.resolve(process.cwd(), "fixtures/expected/graph.md");

const expectedExport = await fs.readFile(expectedExportPath, "utf8");
const expectedGraph = await fs.readFile(expectedGraphPath, "utf8");

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
  assert.equal(output, expectedExport);
});

test("prompts/get graph returns deterministic output", async () => {
  const output = await getPromptContent(fixtureRoot, "personakit.session.graph", {
    personaId: "senior-swiftui-engineer",
    taskId: "apply-style",
  });
  assert.equal(output, expectedGraph);
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
