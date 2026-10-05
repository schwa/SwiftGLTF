// Validates .gltf/.glb files with the Khronos glTF-Validator (JS API; the npm
// package has no CLI). Exits non-zero if any file has errors.
// Usage: node validate.mjs <file-or-directory>...
import { readFile, readdir, stat } from "node:fs/promises";
import path from "node:path";
import validator from "gltf-validator";

async function collect(target) {
  const info = await stat(target);
  if (!info.isDirectory()) {
    return [target];
  }
  const entries = await readdir(target);
  const files = await Promise.all(entries.map((entry) => collect(path.join(target, entry))));
  return files.flat().filter((file) => /\.(gltf|glb)$/i.test(file));
}

const targets = process.argv.slice(2);
if (targets.length === 0) {
  console.error("usage: node validate.mjs <file-or-directory>...");
  process.exit(2);
}

const files = (await Promise.all(targets.map(collect))).flat().sort();
let failed = 0;
for (const file of files) {
  const bytes = new Uint8Array(await readFile(file));
  const report = await validator.validateBytes(bytes, {
    uri: path.basename(file),
    // Resolve external buffers/images relative to the file.
    externalResourceFunction: async (uri) =>
      new Uint8Array(await readFile(path.join(path.dirname(file), decodeURIComponent(uri)))),
  });
  const { numErrors, numWarnings, messages } = report.issues;
  console.log(`${numErrors === 0 ? "ok  " : "FAIL"} ${file}: ${numErrors} error(s), ${numWarnings} warning(s)`);
  for (const message of messages.filter((m) => m.severity === 0)) {
    console.log(`       ${message.code} ${message.pointer ?? ""} ${message.message}`);
  }
  if (numErrors > 0) {
    failed += 1;
  }
}
console.log(`${files.length - failed}/${files.length} files passed`);
process.exit(failed === 0 ? 0 : 1);
