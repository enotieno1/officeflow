import { readdirSync, readFileSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const dashboard = join(root, "dashboard");
const temp = mkdtempSync(join(tmpdir(), "officeflow-inline-js-"));
const failures = [];
let checked = 0;

function walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.isFile() && entry.name.toLowerCase().endsWith(".html")) checkHtml(full);
  }
}

function checkHtml(file) {
  const html = readFileSync(file, "utf8");
  const pattern = /<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi;
  let match;
  let number = 0;
  while ((match = pattern.exec(html))) {
    const attrs = match[1] || "";
    const source = match[2] || "";
    if (/\bsrc\s*=/.test(attrs) || !source.trim()) continue;
    const type = (attrs.match(/\btype\s*=\s*["']([^"']+)["']/i) || [])[1] || "text/javascript";
    if (!/(text|application)\/(javascript|ecmascript)|\bmodule\b/i.test(type)) continue;
    number++;
    checked++;
    const tempFile = join(temp, `script-${checked}.js`);
    writeFileSync(tempFile, source, "utf8");
    const result = spawnSync(process.execPath, ["--check", tempFile], { encoding: "utf8" });
    if (result.status !== 0) {
      failures.push({
        file: relative(root, file),
        inlineScript: number,
        error: (result.stderr || result.stdout || "Node syntax check failed").trim()
      });
    }
  }
}

try {
  walk(dashboard);
  if (failures.length) {
    for (const item of failures) {
      process.stderr.write(`FAIL ${item.file} (inline script ${item.inlineScript})\n${item.error}\n`);
    }
    process.stderr.write(`\nChecked ${checked} inline scripts; ${failures.length} failed.\n`);
    process.exitCode = 1;
  } else {
    process.stdout.write(`PASS: JavaScript syntax checked in ${checked} inline scripts across dashboard HTML pages.\n`);
  }
} finally {
  rmSync(temp, { recursive: true, force: true });
}
