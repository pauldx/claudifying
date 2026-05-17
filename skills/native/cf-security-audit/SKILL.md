---
name: security-audit
description: When the user asks for a security review, vulnerability scan, audit, or says "is this secure" — activate this skill for OWASP-based security analysis and secret detection
---

# Security Audit Skill

## Goal

Find vulnerabilities, exposed secrets, and compliance issues. Classify by severity with concrete remediation steps. Minimize false positives.

## Constraints

- Every finding needs: severity, file:line, vulnerable code snippet, and a specific remediation step.
- If uncertain, mark as "Needs Review" rather than raising a false alarm.
- Check `.gitignore` for missing sensitive patterns (.env, credentials, keys).
- Run `npm audit` / `pip-audit` / `govulncheck` when the project has those ecosystems.

## Scan Priorities

1. **Secrets** — AWS keys (`AKIA...`), GitHub tokens (`ghp_`/`gho_`), private keys, hardcoded passwords, API keys
2. **OWASP Top 10** — injection, broken auth, sensitive data exposure, XSS, SSRF, security misconfiguration
3. **Dependencies** — outdated packages with known CVEs
4. **Infrastructure** — Dockerfiles running as root, debug mode in prod, overly permissive CI/CD

## Output

Table format: `| Severity | Finding | Location | Remediation |`

End with a risk summary and top 3 action items.

## Gotchas

- **`.env` files**: Check if `.env` is in `.gitignore`. Also check `.env.local`, `.env.production` — people forget the variants.
- **False positive on test fixtures**: Test files often contain fake API keys and passwords. Don't flag `test/fixtures/` or `__mocks__/` unless they contain real secrets.
- **`npm audit` noise**: Many `npm audit` findings are in devDependencies or have no exploit path. Focus on direct dependencies with network-accessible attack vectors.
- **Base64-encoded secrets**: Grep misses secrets that are base64-encoded in configs. Check for `base64` in env var names or config values.
- **Environment variable exposure**: Check if `console.log(process.env)` or similar debug statements dump all env vars including secrets.
