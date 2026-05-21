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
    .filter((href) => !href.startsWith("http"))
    .sort();
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

  if (missing.length || stale.length) {
    failures.push({
      exampleName,
      missing,
      stale,
    });
  }
}

if (failures.length) {
  console.error("Example root index drift detected:");
  console.error(JSON.stringify(failures, null, 2));
  process.exit(1);
}
