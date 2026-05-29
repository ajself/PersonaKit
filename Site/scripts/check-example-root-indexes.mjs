import fs from "node:fs";
import path from "node:path";

const examplesDirectory = path.join(process.cwd(), "public", "examples");

function listFiles(directory, root = directory) {
  return fs.readdirSync(directory, {
    withFileTypes: true,
  }).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      return listFiles(entryPath, root);
    }

    const relativePath = path.relative(root, entryPath);

    return relativePath === "index.html" ? [] : [relativePath];
  }).sort();
}

function indexHrefs(indexPath) {
  const html = fs.readFileSync(indexPath, "utf8");

  return [...html.matchAll(/href="([^"]+)"/g)]
    .map((match) => match[1])
    .map((href) => href.replace(/^\.\//, ""))
    .filter((href) => !href.startsWith("http"))
    .filter((href) => !href.startsWith("../"))
    .sort();
}

function checkInlineScripts(indexPath) {
  const html = fs.readFileSync(indexPath, "utf8");
  const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];

  for (const [scriptTag, script] of scripts) {
    try {
      new Function(script);
    } catch (error) {
      return {
        error: error.message,
        script: scriptTag.slice(0, 80),
      };
    }
  }

  return null;
}

const failures = [];

for (const exampleName of fs.readdirSync(examplesDirectory).sort()) {
  const rootDirectory = path.join(examplesDirectory, exampleName, "personakit-root");

  if (!fs.existsSync(rootDirectory)) {
    continue;
  }

  const indexPath = path.join(rootDirectory, "index.html");
  const expected = listFiles(rootDirectory);
  const actual = fs.existsSync(indexPath) ? indexHrefs(indexPath) : [];
  const missing = expected.filter((file) => !actual.includes(file));
  const stale = actual.filter((href) => !expected.includes(href));
  const scriptFailure = fs.existsSync(indexPath) ? checkInlineScripts(indexPath) : null;

  if (missing.length || stale.length || scriptFailure) {
    failures.push({
      exampleName,
      missing,
      scriptFailure,
      stale,
    });
  }
}

if (failures.length) {
  console.error("Example root index drift detected:");
  console.error(JSON.stringify(failures, null, 2));
  process.exit(1);
}
