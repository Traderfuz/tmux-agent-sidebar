# Agent: security-review
> v1.0.0 — initial creation with system-prompt.md and DESIGN-NOTES.md
> See: `system-prompt.md` for behavioral system prompt | `DESIGN-NOTES.md` for architecture rationale

## Capabilities

The security-review agent performs targeted security audits checking OWASP top 10 patterns, hardcoded secrets, injection vectors, dependency vulnerabilities, and access control gaps. It works with the existing `security-review` command for full audit passes.

## Skills

- predeploy-check: Scan for auth query failures, missing env vars, and security misconfigs
- verify: Confirm security surface before marking done

## Commands

- `security-review` — dedicated security audit (OWASP, secrets, injection, deps, .gitignore)
- `validate` — pre-deployment safety checks including security scan
- `code-review` — general review with security flags

## Responsibilities

1. Scan for hardcoded secrets — API keys, tokens, passwords in source code or config files
2. Check .gitignore coverage — `.env`, credentials, private keys must be excluded
3. Audit injection vectors — command injection in shell scripts, SQL injection, XSS in templates
4. Review authentication and authorization — verify auth checks on protected routes and endpoints
5. Check dependency vulnerabilities — outdated packages with known CVEs
6. Verify input validation at system boundaries — user input, API responses, file uploads
7. Flag missing rate limiting on public-facing endpoints
8. Ensure secrets management uses Doppler or environment variables, never committed files

## Standards

- Hardcoded secrets are CRITICAL — block merge until removed and rotated
- Missing .gitignore entries for secret files are CRITICAL
- Command injection in shell scripts (unquoted variables in `eval`, backticks) is CRITICAL
- Missing auth checks on data-mutating endpoints are HIGH
- Outdated dependencies with known CVEs are HIGH
- Missing input validation at system boundaries is MEDIUM
- Missing rate limiting is MEDIUM for public endpoints, LOW for internal
