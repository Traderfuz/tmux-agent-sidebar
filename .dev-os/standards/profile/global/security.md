<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/security.md and re-run profile-sync. -->
# Security Standards

## Overview

Security failures cascade. A single hardcoded credential in a commit reaches every fork, mirror, and CI cache within seconds and cannot be revoked by deleting the file. A missing parameterised query turns a search box into a database admin console. A force-push to main that bypasses hooks silently removes the safety net that would have caught both. These are not hypothetical risks — they are the documented root causes behind the majority of breaches in web applications (OWASP Top 10, 2021) and open-source supply chain attacks (Sonatype State of the Software Supply Chain, 2024).

DevOS projects operate with AI-assisted development where agents read, write, and commit code autonomously. This raises the stakes: an agent that commits a `.env` file or interpolates user input into a shell command creates a vulnerability at machine speed. This standard consolidates every security rule previously scattered across CLAUDE.md safety sections, validation standards, observability standards, and shell safety standards into a single enforceable document with a machine-parseable compliance checklist.

**Sibling standards:**
- [`observability.md`](./observability.md) — logging hygiene rules that prevent secrets leaking into logs (Rule 6); trace correlation for security event attribution
- [`shell-safety.md`](./shell-safety.md) — alias bypass and pipefail discipline that prevents shell injection at the invocation layer
- [`otel-instrumentation.md`](./otel-instrumentation.md) — secrets MUST NOT appear in span attributes or events; same rule as Rule 3 here applies to OTEL telemetry

## Scope

This standard covers application security (injection prevention, input validation at trust boundaries, output encoding), secrets management (credential storage, commit hygiene, environment variable handling), git workflow safety (force-push restrictions, hook enforcement), authentication and session handling, and dependency supply chain security. It does NOT cover infrastructure hardening (firewall rules, OS patching, container security), network security (TLS configuration, certificate management), or physical access controls.

## Named Frameworks

### OWASP Top 10 (2021)
The Open Worldwide Application Security Project's consensus ranking of the ten most critical web application security risks. Categories A01 (Broken Access Control) through A10 (Server-Side Request Forgery) provide the taxonomy used throughout this standard.
**Applied here:** Rules 1-5 map directly to OWASP categories A01, A03, A07, A08, and A09.

### OWASP Application Security Verification Standard (ASVS) v4.0
A framework of security requirements and controls organized into three verification levels (L1 opportunistic, L2 standard, L3 advanced). Provides the binary pass/fail compliance model used in this standard's checklist.
**Applied here:** The compliance test section follows ASVS's binary verification model.

### CWE/SANS Top 25 Most Dangerous Software Weaknesses
The Common Weakness Enumeration's ranked list of the most frequent and exploitable software bugs. CWE-78 (OS Command Injection), CWE-79 (XSS), CWE-89 (SQL Injection), and CWE-798 (Hardcoded Credentials) are directly addressed by rules in this standard.
**Applied here:** Each rule cites the relevant CWE identifier.

### The RFC 2119 Normative Vocabulary Model
MUST, SHOULD, MAY, MUST NOT, SHOULD NOT — precisely defined authority levels so compliance is checkable rather than interpretable.
**Applied here:** Every rule uses RFC 2119 keywords to distinguish mandatory controls from recommended practices.

## Principles

1. **Defence in depth.** No single control is sufficient. Validate input, encode output, parameterise queries, restrict permissions, and monitor — each layer catches what the previous one missed.
2. **Least privilege.** Every process, user, token, and service account operates with the minimum permissions required for its function. Broad permissions are revoked, not left dormant.
3. **Secrets are ephemeral, not embedded.** Credentials, API keys, and tokens are injected at runtime from a secrets manager. They never exist in source code, commit history, logs, or error messages.
4. **Fail closed.** When a security check cannot determine whether access should be granted, it denies access. The default state is "no access" — permission is granted explicitly, not assumed.
5. **Trust boundaries are explicit.** Data that crosses a boundary — from user input, external API, webhook, file upload, or inter-service call — is untrusted until validated. Internal code trusts internal code; everything else is validated at entry.

## Rules

### Rule 1 — Injection Prevention (CWE-78, CWE-79, CWE-89)

All injection vectors — SQL, OS command, XSS, LDAP, template — share one root cause: untrusted data is concatenated into an interpreted string. The fix is always the same: use the platform's structured API instead of string interpolation.

**MUST** use parameterised queries or ORM-generated queries for all database interactions. String interpolation into SQL is prohibited.

```python
# OFF-STANDARD — SQL injection via f-string (CWE-89)
query = f"SELECT * FROM users WHERE email = '{user_input}'"
db.execute(query)

# ON-STANDARD — parameterised query
db.execute("SELECT * FROM users WHERE email = %s", (user_input,))
```

**MUST** use the platform's HTML escaping library for all user-supplied data rendered in HTML. Never build HTML via string concatenation with user data.

```typescript
// OFF-STANDARD — XSS via innerHTML (CWE-79)
element.innerHTML = `<p>Welcome, ${userName}</p>`;

// ON-STANDARD — use textContent or a framework's auto-escaping
element.textContent = `Welcome, ${userName}`;
// Or in React/JSX (auto-escaped by default):
return <p>Welcome, {userName}</p>;
```

**MUST** use shell quoting utilities or array-based command execution for any shell command that includes external input. Never interpolate user data into shell strings.

```bash
# OFF-STANDARD — command injection via unquoted variable (CWE-78)
eval "grep $user_pattern /var/log/app.log"

# ON-STANDARD — no eval, properly quoted
command grep -F -- "$user_pattern" /var/log/app.log
```

```typescript
// OFF-STANDARD — command injection via template literal
exec(`ffmpeg -i ${userFilename} output.mp4`);

// ON-STANDARD — array-based execution
execFile('ffmpeg', ['-i', userFilename, 'output.mp4']);
```

**MUST NOT** use `eval`, `exec` (dynamic code execution), `Function()`, or equivalent constructs with user-supplied data under any circumstances.

### Rule 2 — Secrets Management (CWE-798)

Hardcoded credentials in source code are the single most common cause of credential leaks in public repositories. Once committed, a secret persists in git history even after the file is deleted.

**MUST NOT** commit files containing secrets to git. The following patterns are prohibited in tracked files:
- `.env`, `.env.local`, `.env.production`, `.env.*`
- `credentials.json`, `service-account.json`, `*-key.json`
- Files containing `PRIVATE KEY`, `sk-`, `Bearer `, or base64-encoded tokens

**MUST** use a secrets manager (Doppler is the DevOS default) or environment variables injected at runtime. Secrets are never hardcoded in source, configuration files, or CI/CD pipeline definitions.

```bash
# OFF-STANDARD — hardcoded API key
export STRIPE_KEY="sk_live_abc123..."

# ON-STANDARD — injected from secrets manager
# In .env.example (committed, no real values):
STRIPE_KEY=

# At runtime (via Doppler or CI secrets):
doppler run -- bun run dev
```

**MUST** include secret-pattern rules in `.gitignore`:
```gitignore
.env
.env.*
!.env.example
*.pem
*-key.json
credentials.json
```

**MUST NOT** log, print, or include secrets in error messages, stack traces, or API responses. See the observability standard (`observability.md`, Rule 6) for the full logging hygiene requirement.

**SHOULD** rotate credentials immediately if a secret is accidentally committed. Treat the credential as compromised — revoke and reissue, do not simply delete the file.

### Rule 3 — Git Workflow Safety

Git operations performed by AI agents and automated pipelines carry higher risk because they execute without human review unless guardrails are enforced.

**MUST NOT** force-push (`git push --force`, `git push -f`) to `main` or `master` branches. Force-push rewrites public history and can destroy other contributors' work.

**MUST NOT** skip pre-commit hooks (`--no-verify`) unless the user has explicitly requested it for a documented reason. Hooks are the last automated gate before code enters the repository.

**MUST NOT** use destructive git operations (`git reset --hard`, `git checkout .`, `git clean -f`, `git branch -D`) without explicit user approval. These operations discard uncommitted work irreversibly.

**MUST** create new commits rather than amending existing commits when a pre-commit hook fails. After hook failure, the commit did not happen — `--amend` would modify the previous commit, potentially destroying prior changes.

**MUST** stage files explicitly by name rather than using `git add -A` or `git add .`, which can accidentally stage secrets files, large binaries, or unrelated changes.

**SHOULD** verify that all staged files are inside the git repository root before committing. Files outside the repo root indicate a path resolution error.

### Rule 4 — Input Validation at Trust Boundaries

This rule summarises input validation requirements for the security context. The `validation.md` standard (available in `default` and `installable-os` profiles) covers the full treatment including field-specific error messages, business rule separation, and allowlist patterns. In the `general` profile, the rules below are the authoritative guidance.

**MUST** validate all data at every trust boundary — HTTP endpoints, CLI argument parsers, webhook receivers, background job payloads, file upload handlers, and inter-service calls. Client-side validation is a UX convenience, not a security control.

**MUST** use allowlist validation (define what is permitted) rather than blocklist validation (define what is forbidden). Blocklists are always incomplete.

**MUST** canonicalise and validate file paths against an allowed base directory before any file system operation. Reject path traversal attempts (`../`).

**MUST NOT** trust JWT claims, cookies, or request headers without server-side verification against the authoritative data source.

```typescript
// OFF-STANDARD — trusting a JWT claim directly
if (decodedToken.role === 'admin') { performAdminAction(); }

// ON-STANDARD — verify against authoritative source
const user = await db.users.findById(decodedToken.sub);
if (user?.role !== 'admin') throw new ForbiddenError();
performAdminAction();
```

### Rule 5 — Authentication and Session Handling (OWASP A07)

**MUST** enforce authentication on every protected endpoint. Authentication middleware runs before any business logic. There is no "internal only" exception — internal endpoints are reachable after initial compromise.

**MUST** store session tokens and API keys in `httpOnly`, `secure`, `sameSite=strict` cookies or in server-side session stores. Never store tokens in `localStorage` or expose them in URLs.

```typescript
// OFF-STANDARD — token in localStorage (accessible to XSS)
localStorage.setItem('authToken', token);

// ON-STANDARD — httpOnly cookie (not accessible to JavaScript)
res.cookie('session', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict',
  maxAge: 3600000,
});
```

**MUST** implement session expiration. Sessions without expiration remain valid indefinitely after compromise.

**SHOULD** implement rate limiting on authentication endpoints to prevent brute-force attacks.

**SHOULD** use established authentication libraries (Clerk, NextAuth, Passport, Lucia) rather than hand-rolling authentication. Custom auth implementations are a top source of security vulnerabilities.

### Rule 6 — Dependency Supply Chain Security (OWASP A06)

**MUST** pin dependency versions in lockfiles (`bun.lockb`, `package-lock.json`, `Pipfile.lock`, `Cargo.lock`). Unpinned dependencies allow silent upgrades that may introduce vulnerabilities or malicious code.

**MUST** run dependency audit checks (`bun audit`, `npm audit`, `pip-audit`, `cargo audit`) before each release. Known vulnerabilities in dependencies are exploitable the moment they are published.

**SHOULD** enable automated dependency scanning (Dependabot, Renovate, Snyk) to receive alerts for newly disclosed CVEs in the dependency tree.

**SHOULD** review new dependencies before adding them. Check: maintenance status (last commit date, open issue count), download count, known CVEs, and whether the package is a direct dependency or a transitive one that can be avoided.

**MUST NOT** install packages from unverified registries or use `--ignore-scripts` to bypass install-time security checks without understanding what scripts are being skipped.

### Rule 7 — Output Encoding and Content Security

**MUST** set appropriate security headers on all HTTP responses:
- `Content-Security-Policy` — restrict script sources to prevent XSS
- `X-Content-Type-Options: nosniff` — prevent MIME-type sniffing
- `X-Frame-Options: DENY` or `SAMEORIGIN` — prevent clickjacking
- `Strict-Transport-Security` — enforce HTTPS

**MUST** encode output according to the context it is rendered in. HTML context requires HTML encoding, JavaScript context requires JavaScript encoding, URL context requires URL encoding. Context-incorrect encoding is equivalent to no encoding.

**MUST NOT** disable CORS protections or set `Access-Control-Allow-Origin: *` on endpoints that serve authenticated data.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| String interpolation into SQL, shell, or HTML | Creates injection vectors (SQLi, RCE, XSS) exploitable by any user input | Parameterised queries, `execFile` arrays, framework auto-escaping |
| Hardcoded API keys or passwords in source files | Persists in git history forever; reaches forks, CI caches, mirrors within seconds | Doppler or environment variables injected at runtime |
| `git push --force` to main | Rewrites shared history; destroys other contributors' work | `git push` (normal); rebase or merge instead |
| `git add .` or `git add -A` | Stages `.env`, credentials, large binaries, unrelated changes | Stage specific files by name |
| `--no-verify` on git commit | Bypasses pre-commit hooks that catch secrets, lint errors, and test failures | Fix the hook failure; only skip with explicit user approval |
| Storing tokens in `localStorage` | Accessible to any JavaScript running on the page, including XSS payloads | `httpOnly` + `secure` + `sameSite=strict` cookies |
| Trusting client-side validation as a security control | Bypassed trivially with curl, Postman, or browser dev tools | Validate server-side independently at every boundary |
| Blocklist-based input filtering | Always incomplete; attackers iterate on encoding variants until bypass is found | Allowlist validation — define what is permitted, reject everything else |
| `eval()` or `exec()` with user-supplied data | Arbitrary code execution — the most severe vulnerability class | Structured APIs, parameterised queries, array-based command execution |
| Unpinned dependencies (`^` or `*` versions) | Silent upgrades may introduce vulnerabilities or supply chain attacks | Pin versions in lockfiles; audit before release |
| `Access-Control-Allow-Origin: *` on authenticated endpoints | Any origin can make credentialed requests; session hijacking becomes trivial | Restrict CORS to known origins; never wildcard authenticated endpoints |
| Generic error messages that leak stack traces | Reveals internal paths, library versions, and query structure to attackers | Return structured error responses; log details server-side only |

## Deviation Guidance

- **MAY** relax `sameSite=strict` to `sameSite=lax` for cookies that must work with OAuth redirect flows, provided the cookie does not grant write access.
- **MAY** use `Access-Control-Allow-Origin: *` on endpoints that serve exclusively public, unauthenticated data (e.g., a public API catalogue).
- **MAY** omit `Content-Security-Policy` headers in local development environments where inline scripts are required for hot-module-reload, provided the production configuration enforces a strict CSP.
- **MUST NOT** deviate from parameterised queries, secrets management, or force-push restrictions under any circumstances. These rules have no safe exception.
- **MAY** use `--no-verify` when the user has explicitly requested it and the reason is documented in the commit message or conversation.

## Profile Inheritance Notes

This standard lives in the `general` profile and is inherited by all child profiles: `webapp`, `pwa`, `cli`, `business`, `boxi-ops`, `cloudflare-workers`, `installable-os`, `skills`, and `agents`. Child profiles do not need to restate these rules. Child profiles that handle additional security concerns (e.g., `webapp` adding CSP nonce generation, `cloudflare-workers` adding edge-specific token validation) SHOULD extend this standard in a profile-specific `security.md` that references this document rather than duplicating its rules.

## Compliance Test

The following checklist is machine-parseable. Each item is a binary yes/no question. A project passes this standard when all items are checked.

### Injection Prevention
- [ ] All database queries use parameterised queries or ORM-generated queries (no string interpolation into SQL)?
- [ ] All user-supplied data rendered in HTML uses the framework's auto-escaping or an explicit escaping library?
- [ ] All shell commands that include external input use array-based execution or proper quoting (no `eval` with user data)?
- [ ] No use of `eval()`, `exec()`, `Function()`, or equivalent dynamic code execution with user-supplied input?

### Secrets Management
- [ ] No `.env`, `credentials.json`, `*-key.json`, or files containing API keys/tokens are tracked in git?
- [ ] All secrets are injected at runtime via a secrets manager (Doppler) or environment variables?
- [ ] `.gitignore` includes rules for `.env`, `.env.*`, `*.pem`, `*-key.json`, and `credentials.json`?
- [ ] No secrets appear in log output, error messages, stack traces, or API responses?

### Git Safety
- [ ] No `git push --force` to `main` or `master` in any script, CI pipeline, or agent workflow?
- [ ] No `--no-verify` on git commit without explicit user approval documented in context?
- [ ] Files are staged by name (not `git add -A` or `git add .`) in automated workflows?
- [ ] New commits are created (not amended) after pre-commit hook failures?

### Input Validation
- [ ] All API endpoints, CLI parsers, webhook receivers, and job handlers validate input server-side?
- [ ] Input validation uses allowlist patterns (not blocklists)?
- [ ] File path inputs are canonicalised and checked against an allowed base directory?
- [ ] JWT claims and request headers are verified against the authoritative data source before granting access?

### Authentication and Sessions
- [ ] Every protected endpoint enforces authentication via middleware before business logic executes?
- [ ] Session tokens are stored in `httpOnly`, `secure`, `sameSite` cookies (not `localStorage`)?
- [ ] All sessions have an expiration configured?
- [ ] Authentication endpoints have rate limiting enabled?

### Dependency Security
- [ ] All dependency versions are pinned in a lockfile?
- [ ] Dependency audit (`bun audit`, `npm audit`, or equivalent) runs before each release?
- [ ] New dependencies are reviewed for maintenance status, CVEs, and necessity before addition?

### Output Encoding and Headers
- [ ] Security headers (`CSP`, `X-Content-Type-Options`, `X-Frame-Options`, `HSTS`) are set on HTTP responses?
- [ ] Output encoding matches the rendering context (HTML, JavaScript, URL)?
- [ ] `Access-Control-Allow-Origin: *` is not set on any authenticated endpoint?

## References

- [OWASP Top 10 (2021)](https://owasp.org/Top10/) — consensus ranking of the ten most critical web application security risks; provides the category taxonomy (A01–A10) referenced throughout this standard
- [OWASP Application Security Verification Standard v4.0](https://owasp.org/www-project-application-security-verification-standard/) — three-tier security requirements framework providing the binary pass/fail compliance model used in the checklist
- [CWE/SANS Top 25 (2023)](https://cwe.mitre.org/top25/archive/2023/2023_top25_list.html) — ranked list of most dangerous software weaknesses; CWE-78, CWE-79, CWE-89, CWE-798 are directly addressed
- [RFC 2119 — Key words for use in RFCs](https://www.rfc-editor.org/rfc/rfc2119) — defines MUST, SHOULD, MAY normative vocabulary used in this standard's rules
- [Sonatype State of the Software Supply Chain (2024)](https://www.sonatype.com/state-of-the-software-supply-chain) — documents the scale and growth of supply chain attacks motivating Rule 6
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/) — practitioner-level guidance for injection prevention, session management, input validation, and secure headers
