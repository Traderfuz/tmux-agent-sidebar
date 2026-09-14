<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/validation.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/validation.md and re-run profile-sync. -->
# Validation Standards

## Overview

Every point where external data enters a system is a potential attack surface. Validation is the practice of asserting that data meets the structural, type, range, and business-rule requirements before it is processed, stored, or passed to dependent systems. Skipping or weakening validation at any boundary opens the system to injection attacks, data corruption, and undefined behaviour that is difficult to diagnose after the fact. Validation is not a UX convenience — it is a trust boundary.

## Scope

This standard covers input validation at all system boundaries: HTTP API endpoints, CLI argument parsing, message queue and background job payloads, webhook receivers, and file upload handlers. It does NOT cover database-level constraints such as NOT NULL, UNIQUE, or CHECK clauses (see `models.md`), and it does NOT cover authentication or session token validation (see auth standards).

## Principles

1. **Validate at every boundary:** Any data that crosses a trust boundary — from user, from external service, from another process — must be validated before use, regardless of how trustworthy the source claims to be.
2. **Allowlist over blocklist:** Define precisely what is permitted; reject everything else. A blocklist is always incomplete; there is always a payload variant that bypasses it.
3. **Fail early with specific messages:** Reject invalid input at the earliest possible point and return a message that tells the caller exactly which field is wrong and why, not a generic failure indicator.

## Rules

### Server-side validation is always required

Client-side validation (browser form validation, CLI pre-checks) exists only to improve user experience. It is not a security control. Every validation performed on the client must be independently performed on the server before the data is processed.

OFF-STANDARD — server trusts a field because the client validated it:
```typescript
// Client sent isVerifiedEmail: true — assumed to be trustworthy
if (req.body.isVerifiedEmail) {
  await grantAccessWithoutVerification(req.body.userId);
}
```

ON-STANDARD — server independently verifies the claim:
```typescript
const user = await db.users.findById(req.body.userId);
if (!user?.emailVerifiedAt) {
  throw new ValidationError("email", "Email address has not been verified");
}
await grantAccess(user.id);
```

OFF-STANDARD (Python — no server-side validation, trusting a JWT claim directly):
```python
user_role = jwt_payload.get("role")  # JWT not re-validated against DB
if user_role == "admin":
    perform_admin_action()
```

ON-STANDARD (Python — role re-verified from authoritative source):
```python
user = db.query(User).filter_by(id=jwt_payload["sub"]).first()
if not user or user.role != "admin":
    raise PermissionDenied("Admin role required")
perform_admin_action()
```

### Input sanitisation

Sanitise input to neutralise injection vectors before it is used in dynamic contexts (SQL queries, shell commands, HTML output, file paths).

- Use parameterised queries or prepared statements for all database interactions. String interpolation into SQL is prohibited.
- Use the platform's escaping library for HTML output; never build HTML via string concatenation with user data.
- Reject or strip null bytes (`\0`) from string inputs.
- Resolve and validate file paths against an allowed base directory before any file operation; prevent path traversal (`../`) by canonicalising the path and checking it starts with the expected prefix.

OFF-STANDARD (SQL injection via string interpolation):
```python
query = f"SELECT * FROM users WHERE email = '{user_input}'"
db.execute(query)
```

ON-STANDARD (parameterised query):
```python
db.execute("SELECT * FROM users WHERE email = %s", (user_input,))
```

OFF-STANDARD (TypeScript — path traversal risk):
```typescript
const filePath = path.join(UPLOAD_DIR, req.params.filename);
fs.readFile(filePath, ...);  // "../../../etc/passwd" bypasses UPLOAD_DIR
```

ON-STANDARD:
```typescript
const filePath = path.resolve(UPLOAD_DIR, req.params.filename);
if (!filePath.startsWith(path.resolve(UPLOAD_DIR))) {
  throw new ValidationError("filename", "Invalid file path");
}
fs.readFile(filePath, ...);
```

### Allowlist patterns

Define what is permitted, not what is forbidden.

- For string inputs with a finite set of valid values, validate against an explicit allowlist (enum, set, array) rather than trying to block known-bad values.
- For format-constrained strings (email, URL, UUID, phone number), use a well-tested parser or RFC-compliant regex rather than a hand-written pattern.
- For numeric inputs, validate type, minimum, maximum, and whether the value must be an integer.
- For free-text fields, validate maximum length and reject null bytes. Apply additional sanitisation rules based on the downstream context (HTML rendering, logging, storage).

OFF-STANDARD — blocklist approach for file extension:
```typescript
const BLOCKED = [".exe", ".sh", ".bat"];
if (BLOCKED.includes(ext)) throw new Error("Blocked file type");
// Attacker uploads ".Exe" or ".exe " or encodes differently
```

ON-STANDARD — allowlist approach:
```typescript
const ALLOWED_EXTENSIONS = new Set([".jpg", ".jpeg", ".png", ".pdf", ".csv"]);
if (!ALLOWED_EXTENSIONS.has(ext.toLowerCase())) {
  throw new ValidationError("file", `File type '${ext}' is not permitted. Allowed: jpg, jpeg, png, pdf, csv`);
}
```

### Field-specific error messages

Validation errors must identify the specific field and the specific rule that was violated. A single generic "validation failed" response forces the caller to guess.

OFF-STANDARD — generic, non-actionable error:
```typescript
throw new Error("Invalid input");
```

ON-STANDARD — field-specific, rule-specific errors (RFC 7807 style):
```typescript
const errors = [];
if (!body.email || !isEmail(body.email)) {
  errors.push({ field: "email", message: "Must be a valid email address" });
}
if (!body.age || body.age < 18 || body.age > 120) {
  errors.push({ field: "age", message: "Must be a number between 18 and 120" });
}
if (errors.length > 0) {
  throw new ValidationError("Request validation failed", { errors });
}
```

Return all validation errors in a single response where possible, not one at a time. This prevents the caller from needing multiple round trips to discover all problems.

OFF-STANDARD (Python — stops at first error, hides remaining issues):
```python
if not data.get("email"):
    raise ValueError("email required")
if not data.get("name"):
    raise ValueError("name required")
```

ON-STANDARD (Python — collects all errors before raising):
```python
errors = {}
if not data.get("email") or not is_valid_email(data["email"]):
    errors["email"] = "Must be a valid email address"
if not data.get("name") or len(data["name"]) > 200:
    errors["name"] = "Required; must be 200 characters or fewer"
if errors:
    raise ValidationError(errors)
```

### Business rule validation layer

Structural validation (type, format, length) and business rule validation (sufficient account balance, non-overlapping date ranges, foreign key existence) are separate concerns and must be handled in separate layers.

- Structural validation happens at the boundary handler (controller, route handler, CLI argument parser) before the request reaches business logic.
- Business rule validation happens in the domain or service layer, after the request is structurally valid.
- Do not embed business rules in form validators or schema definitions; they change at different rates than structural constraints and belong in testable domain logic.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Relying solely on client-side validation | Bypassed trivially with any HTTP client; provides no security guarantee | Independently validate every field server-side before processing |
| String interpolation into SQL, shell commands, or HTML | Creates injection vulnerabilities (SQLi, RCE, XSS) | Use parameterised queries, shell quoting utilities, and output-escaping libraries |
| Blocklist-based filtering ("remove dangerous characters") | Incomplete; attackers iterate on encoding variations until bypass is found | Define and enforce an allowlist of permitted values and formats |
| Generic validation error responses ("Bad Request") | Forces the caller into a debugging loop; increases support burden | Return field-level, rule-level error messages for every failed constraint |
| Validating only at the top-level API layer | Data that arrives via background jobs, webhooks, or inter-service calls bypasses the check | Validate at every boundary where external data enters, not only at the HTTP layer |
| Mixing business rule validation with structural validation | Business rules change frequently; coupling them to schema definitions makes rules untestable in isolation | Separate structural validation (boundary) from business rule validation (domain layer) |

## Deviation guidance

- Teams MAY use a schema validation library (e.g., Zod, Pydantic, Joi, Marshmallow) to implement structural validation, provided the library is pinned and its error output conforms to the field-specific message requirement.
- Teams MAY defer validation of computationally expensive business rules (e.g., checking live inventory across distributed stores) to an async step, provided the caller receives a clear "pending validation" status and is notified of the outcome.
- Teams MUST NOT skip server-side validation on any endpoint, even endpoints that are described as "internal only" or "not user-facing". Internal endpoints are reachable after initial compromise and must be hardened.
- Teams MUST NOT use `eval`, dynamic `exec`, or equivalent constructs with user-supplied data under any circumstances.

## Compliance test

- [ ] Is every API endpoint, CLI argument parser, webhook receiver, and background job payload handler validated server-side before the data is processed?
- [ ] Are all database queries that include user-supplied values written using parameterised queries or an ORM that prevents interpolation?
- [ ] Does every validation failure return a response that identifies the specific field(s) and the specific rule(s) that were violated?
- [ ] Are file path inputs canonicalised and checked against an allowed base directory before any file system operation?
- [ ] Are string inputs with a finite set of valid values validated against an explicit allowlist rather than a blocklist?

## References

- [OWASP Input Validation Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html) — the authoritative practitioner reference for input validation strategy, allowlist/blocklist trade-offs, and context-specific sanitisation rules
- [CWE-20: Improper Input Validation](https://cwe.mitre.org/data/definitions/20.html) — the Common Weakness Enumeration entry that classifies the root cause of a large proportion of exploitable vulnerabilities as inadequate or missing input validation
- [RFC 7807 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc7807) — the standard format for structured, machine-readable validation error responses at HTTP boundaries, motivating the field-specific error message requirement
