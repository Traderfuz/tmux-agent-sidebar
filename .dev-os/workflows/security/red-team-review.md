# Red-Team Security Review Workflow

Perform a security review of implemented code to identify potential vulnerabilities. This review produces WARNINGS only - it does not block commits or deployment.

## When to Use

This workflow is invoked during the verification phase after implementation is complete but before merging to main.



Do not use this workflow as a substitute for a full security audit on production systems — it is a pre-deployment defensive review, not a penetration test.

## Process

## Process

1. Identify attack surfaces in the spec (inputs, auth boundaries, data flows, third-party integrations).
2. Apply OWASP Top 10 threat model to each surface.
3. Score findings by severity (CRITICAL / HIGH / MEDIUM / LOW).
4. Produce a red team report; block merge on CRITICAL findings.

### 1. Identify Changed Files

Get the list of files that were modified in the current feature:

```bash
git diff main...HEAD --name-only
```

### 2. Review Each Changed File

For each file, check for the following security concerns:

#### Web Security (OWASP Top 10)

- **Injection vulnerabilities:**
  - SQL injection: Unsanitized user input concatenated into queries
  - Command injection: User input passed to shell commands
  - LDAP injection: Unvalidated input in LDAP queries

- **Authentication & Authorization:**
  - Missing authentication checks on sensitive endpoints
  - Hardcoded credentials or API keys
  - Weak password requirements
  - Session management issues

- **Cross-Site Scripting (XSS):**
  - Unescaped user input rendered in HTML
  - DOM XSS via unsafe JavaScript methods
  - Stored XSS in user-generated content

- **Insecure Dependencies:**
  - Outdated packages with known vulnerabilities
  - Unmaintained dependencies

#### Code Security

- **Secrets Management:**
  - Hardcoded API keys, tokens, passwords
  - Secrets committed to git (check git history too)
  - Sensitive data in config files

- **Input Validation:**
  - Missing validation on user input
  - Trusting client-side validation only
  - Type confusion vulnerabilities

- **Error Handling:**
  - Stack traces exposed to users
  - Sensitive information in error messages
  - Verbose error messages aiding attackers

- **Cryptography:**
  - Weak encryption algorithms (MD5, SHA1, DES)
  - Hardcoded encryption keys
  - Missing HTTPS enforcement

### 3. Generate Report

Create a security review report in `product/specs/[this-spec]/verification/security-review.md` with the following format:

```markdown
# Security Review Report

**Date:** [ISO 8601 date]
**Branch:** [feature branch name]
**Reviewer:** Automated Red-Team Review

## Files Reviewed

- [file1]
- [file2]
- [file3]

## Findings

### 🔴 Critical (0)
None

### 🟠 High (0)
None

### 🟡 Medium (0)
None

### 🔵 Low (0)
None

### ℹ️ Informational (0)
None

## Summary

No security concerns found. Code is safe to merge.

---

## Finding Templates

### 🔴 Critical

**[File]:[Line] - [Vulnerability Name]**

**Description:** [What the vulnerability is]

**Risk:** [Why this is dangerous]

**Recommendation:** [How to fix it]

**Example:**
```javascript
// Vulnerable code
const query = `SELECT * FROM users WHERE id = ${userId}`;
```

**Fix:**
```javascript
// Fixed code using parameterized query
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [userId]);
```
```

### 4. Display Summary

After the review, output a summary to the user:

```
🔒 Security Review Complete

Files reviewed: [number]
Findings: [X critical, X high, X medium, X low, X informational]

Full report: product/specs/[spec]/verification/security-review.md

⚠️ Warnings do not block merge. Review at your discretion.
```

## Severity Guidelines

| Severity | Definition | Example |
|----------|------------|---------|
| 🔴 Critical | Remote code execution, full data breach | SQL injection with admin privileges |
| 🟠 High | Significant data exposure, authentication bypass | Hardcoded AWS credentials in repo |
| 🟡 Medium | Limited impact, requires specific conditions | Missing rate limiting on API |
| 🔵 Low | Minor issues, best practice violations | Verbose error messages |
| ℹ️ Informational | No vulnerability, but worth noting | Consider adding security headers |

## Automated Checks

When possible, run automated security tools:

**JavaScript/TypeScript:**
```bash
npm audit
npx snyk test
```

**Python:**
```bash
pip-audit
bandit -r .
```

**General:**
```bash
# Check for secrets in git history
git log --all --full-history --source -- "**/config.js" "**/.env" "**/secrets.*"
```

## Notes

- This is a WARNINGS-ONLY review. Findings do not block commits.
- Focus on actionable, specific recommendations.
- If uncertain about a finding, mark it as Informational and explain the concern.
- For solo devs, this review is an extra set of eyes - use your judgment.
- False positives are acceptable - better to warn and dismiss than miss a real issue.

## Display Format

```
Red Team Review — [spec-name]
  Attack surfaces checked: [N]
  Critical findings:       [N]
  High findings:           [N]
  Verdict: [proceed | BLOCKED — [N] critical findings require remediation]
```
