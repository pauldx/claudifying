---
name: cf-tools-sast-eslint-security
description: "JavaScript/TypeScript SAST via eslint-plugin-security — scans for unsafe regex, eval, child_process, and crypto pitfalls. Trigger: /cf-tools-sast-eslint-security"
trigger: /cf-tools-sast-eslint-security
version: 1.0.0
---

# /cf-tools-sast-eslint-security

JS/TS static security analysis using the `eslint-plugin-security` ruleset (detect-eval-with-expression, detect-non-literal-fs-filename, detect-unsafe-regex, detect-child-process, etc.). Scanner-specific wrapper — produces severity counts + JSON. For broader review use `/cf-security-audit`.

## Usage

```
/cf-tools-sast-eslint-security                       # scan src/**/*.{js,ts,jsx,tsx}
/cf-tools-sast-eslint-security path/to/dir           # scan a specific dir
/cf-tools-sast-eslint-security . --ext .ts,.tsx      # limit to TS files
/cf-tools-sast-eslint-security . --ci                # exit non-zero on any HIGH error
/cf-tools-sast-eslint-security . --generate-config   # write minimal .eslintrc-security.json
```

Arguments:
1. `target-path` (optional, default `src`) — directory to scan
2. `--ext .js,.ts,...` (optional, default `.js,.ts,.jsx,.tsx`) — extensions
3. `--ci` — exit 1 if any rule fires at `error` severity
4. `--generate-config` — write a minimal config if the project has none
5. `--json-out PATH` (optional, default `./eslint-security-report.json`)

## What You Must Do When Invoked

### Step 1 — Preflight: verify eslint + plugin

```bash
# Local install (preferred) — runs via npx
if ! npx --no-install eslint --version >/dev/null 2>&1 && ! command -v eslint >/dev/null 2>&1; then
  echo "ERROR: eslint not installed."
  echo ""
  echo "Install in your project (recommended):"
  echo "  npm install --save-dev eslint eslint-plugin-security"
  echo ""
  echo "Or globally:"
  echo "  npm install -g eslint eslint-plugin-security"
  echo ""
  echo "Verify:"
  echo "  npx eslint --version && npm ls eslint-plugin-security"
  exit 2
fi

# Check the plugin is resolvable
if ! node -e "require.resolve('eslint-plugin-security')" 2>/dev/null; then
  echo "ERROR: eslint-plugin-security not installed."
  echo "Install: npm install --save-dev eslint-plugin-security"
  exit 2
fi

echo "eslint: $(npx eslint --version 2>&1)"
```

### Step 2 — Locate or generate config

Detect existing eslint config:

```bash
HAS_CONFIG=""
for f in eslint.config.js eslint.config.mjs eslint.config.cjs \
         .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml .eslintrc; do
  if [ -f "$f" ]; then HAS_CONFIG="$f"; break; fi
done

if [ -z "$HAS_CONFIG" ] && [ "$GEN_CONFIG" = "1" ]; then
  cat > .eslintrc-security.json <<'JSON'
{
  "root": true,
  "parserOptions": { "ecmaVersion": "latest", "sourceType": "module" },
  "plugins": ["security"],
  "extends": ["plugin:security/recommended"]
}
JSON
  HAS_CONFIG=".eslintrc-security.json"
  echo "Generated minimal config: $HAS_CONFIG"
elif [ -z "$HAS_CONFIG" ]; then
  echo "WARN: no eslint config found. Re-run with --generate-config or add one."
  exit 1
fi
```

If the project already has a config, **don't overwrite it**. Use `--config .eslintrc-security.json` only when generating one ourselves.

### Step 3 — Run eslint with security plugin

```bash
TARGET="${TARGET:-src}"
EXT="${EXT:-.js,.ts,.jsx,.tsx}"
JSON_OUT="${JSON_OUT:-./eslint-security-report.json}"

# Build the glob arg list from --ext
PATTERNS=""
IFS=',' read -ra EXTS <<< "$EXT"
for e in "${EXTS[@]}"; do
  PATTERNS="$PATTERNS \"$TARGET/**/*$e\""
done

# Use generated config only when we wrote one; otherwise use project default
CONFIG_FLAG=""
[ -f .eslintrc-security.json ] && [ "$GEN_CONFIG" = "1" ] && CONFIG_FLAG="--config .eslintrc-security.json --no-eslintrc"

eval npx eslint $CONFIG_FLAG \
  --ext "$EXT" \
  --format json \
  --output-file "$JSON_OUT" \
  $PATTERNS || true   # eslint exits 1 on findings; we parse JSON

if [ ! -s "$JSON_OUT" ]; then
  echo "ERROR: eslint produced no JSON output."
  exit 1
fi
```

### Step 4 — Parse + tabulate severity (eslint uses 1=warn, 2=error)

```bash
node - "$JSON_OUT" <<'JS'
const fs = require('fs');
const path = require('path');
const data = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));

let errors = 0, warns = 0;
const findings = [];
for (const file of data) {
  for (const m of file.messages || []) {
    if (m.severity === 2) errors++; else warns++;
    if ((m.ruleId || '').startsWith('security/')) {
      findings.push({
        sev: m.severity === 2 ? 'ERROR' : 'WARN',
        rule: m.ruleId,
        file: path.relative(process.cwd(), file.filePath),
        line: m.line,
        msg: m.message,
      });
    }
  }
}

console.log(`\n## Severity counts`);
console.log(`  ERROR:   ${errors}`);
console.log(`  WARN:    ${warns}`);
console.log(`  security/ rules fired: ${findings.length}`);

findings.sort((a, b) => (a.sev === 'ERROR' ? -1 : 1));
console.log(`\n## Top 5 security findings`);
for (const [i, f] of findings.slice(0, 5).entries()) {
  console.log(`${i + 1}. [${f.sev}] ${f.rule}`);
  console.log(`   ${f.file}:${f.line}`);
  console.log(`   ${f.msg.slice(0, 120)}`);
}
JS
```

### Step 5 — CI gate

```bash
if [ "$CI_MODE" = "1" ]; then
  ERR=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$JSON_OUT','utf8')).reduce((s,f)=>s+f.errorCount,0))")
  if [ "$ERR" -gt 0 ]; then
    echo "CI FAIL: $ERR ESLint errors."
    exit 1
  fi
fi
```

## Output Contract

```
## eslint-plugin-security SAST scan

**Target:**     <path>
**Extensions:** <list>
**Config:**     <path to eslintrc>
**JSON:**       <abs path>
**Runtime:**    <seconds>

## Severity counts
  ERROR:  <n>
  WARN:   <n>
  security/* rules fired: <n>

## Top 5 security findings
1. [ERROR] security/detect-non-literal-fs-filename
   src/util.ts:42
   <message>
...

CI gate: ✅ pass | ❌ fail (X errors)
```

## Config File

- `.eslintrc.*` / `eslint.config.{js,mjs,cjs}` in project root.
- Minimal config for this skill: extend `plugin:security/recommended` and add the `security` plugin.
- For monorepos with flat config (eslint 9+), use `eslint.config.js` with `import security from 'eslint-plugin-security'`.

## Gotchas

- **Flat config vs legacy `.eslintrc`**: eslint 9+ defaults to flat config. Generated config above is legacy `.eslintrc` shape — set `--no-eslintrc` flag along with `--config` when forcing it, or write a flat-config variant if the project uses eslint 9+.
- **TypeScript files**: requires `@typescript-eslint/parser`. Without it, eslint errors on TS syntax before security rules can run. Detect via `node -e "require.resolve('@typescript-eslint/parser')"` and warn.
- **Plugin recommended set is permissive**: `detect-object-injection` is famously noisy. Suppress per-line with `// eslint-disable-next-line security/detect-object-injection` only after manual review.
- **node_modules**: never scan; default eslint behavior excludes but be explicit if using `--no-eslintrc`.
- **`--ext` is deprecated in eslint 9+ flat config**: use glob patterns instead. Skill handles both via the assembled PATTERNS arg.
- **CI exit codes**: eslint exits 1 on any error and 2 on internal errors. `--ci` mode gates on errorCount only.

## Cross-Platform Notes

- **macOS / Linux / Windows**: identical — runs through `npx`. Project-local install is preferred to keep versions pinned in `package.json`.
- **CI**: cache `~/.npm` and install via `npm ci`. Don't `npm install -g` in CI — pin in devDependencies.
- **No Node installed**: fail fast with "Install Node.js 18+ first" message; this skill cannot help.
