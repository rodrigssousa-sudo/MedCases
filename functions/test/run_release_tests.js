"use strict";
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const root = path.resolve(__dirname, "../..");
const manifest = require("./release_test_manifest.json");
const args = process.argv.slice(2);
if (args.some(x => !["--functions-only", "--historical"].includes(x)) || args.length > 1) throw Error("Unknown test suite option");
const actual = fs.readdirSync(__dirname, { recursive: true }).filter(x => /test\.js$/.test(x)).map(x => "functions/test/" + x).sort();
const listed = [...manifest.releaseFunctions, ...manifest.historicalPipelineArchaeology].map(x => x.file).sort();
if (new Set(listed).size !== listed.length || JSON.stringify(actual) !== JSON.stringify(listed)) throw Error("Every Functions test must be classified exactly once");
const groups = args.includes("--historical")
  ? [{ id: "HISTORICAL_NON_RELEASE", runtime: "node", files: manifest.historicalPipelineArchaeology.map(x => x.file) }]
  : manifest.releaseGroups.filter(g => !args.includes("--functions-only") || g.id === "functions");
let failed = false;
for (const group of groups) {
  for (const file of group.files) if (!fs.existsSync(path.join(root, file))) throw Error("Missing release test: " + file);
  const executable = group.runtime === "node" ? process.execPath : (process.env.FLUTTER_BIN || "flutter");
  const command = group.runtime === "node" ? ["--test", ...group.files] : ["test", "--no-pub", "--reporter", "expanded", ...(group.platform ? ["--platform", group.platform] : []), ...group.files];
  console.log("RELEASE_GROUP=" + group.id);
  const result = spawnSync(executable, command, { cwd: root, env: process.env, stdio: "inherit", timeout: 300000 });
  if (result.error) console.error("TEST_RUNNER_ERROR=" + result.error.code);
  console.log("GROUP_EXIT=" + (result.status ?? "ERROR"));
  if (result.status !== 0) failed = true;
}
process.exitCode = failed ? 1 : 0;
