import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { filterTasks, readinessSummary } from "../src/releaseRules.js";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const releaseData = JSON.parse(await readFile(resolve(root, "data/release.json"), "utf8"));

function test(name, body) {
  try {
    body();
    console.log(`ok - ${name}`);
  } catch (error) {
    console.error(`not ok - ${name}`);
    throw error;
  }
}

test("blocked security review keeps release from ready", () => {
  const summary = readinessSummary(releaseData.tasks);

  assert.equal(summary.isReady, false);
  assert.equal(summary.incompleteRequiredCount, 1);
});

test("area filtering returns the matching task group", () => {
  const securityTasks = filterTasks(releaseData.tasks, "security");

  assert.equal(securityTasks.length, 1);
  assert.equal(securityTasks[0].id, "security-review");
});

