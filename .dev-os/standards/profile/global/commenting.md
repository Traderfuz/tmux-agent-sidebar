<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/commenting.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/commenting.md and re-run profile-sync. -->
# Commenting Standards

## Overview

Comments are a form of communication between the author of code and every future reader, including the author six months later. A comment that merely restates what the code does wastes attention; a comment that explains why a decision was made saves hours of archaeology. This standard defines when comments add value, when they create noise, and what form they must take when required.

## Scope

This standard covers inline comments, block comments, and function- or module-level documentation strings (docstrings/JSDoc) for internal code. It does NOT cover public API documentation intended for external consumers — OpenAPI specifications, JSDoc for published packages, or SDK reference docs belong in `api.md`.

## Principles

1. **Code explains what; comments explain why:** If a reader needs a comment to understand what the code is doing, that is a signal to rename or restructure, not to add a comment.
2. **Comments explain why:** The appropriate subject for a comment is intent, trade-off, constraint, or non-obvious domain knowledge — information the code itself cannot express.
3. **Comments must be evergreen:** A comment that becomes false after the next refactor is worse than no comment — it actively misleads. Comments must describe durable truths, not the history of changes.

## Rules

### Self-documenting naming first

Before adding a comment, ask whether the code can be made self-explanatory through naming and structure. This is the first and preferred approach.

OFF-STANDARD — comment compensates for a poor name:
```typescript
// increment counter for retries
x++;
```

ON-STANDARD — name makes the comment unnecessary:
```typescript
retryCount++;
```

OFF-STANDARD (Python) — comment explains a cryptic magic number:
```python
time.sleep(0.250)  # wait for rate limit window
```

ON-STANDARD (Python) — named constant communicates intent without a comment:
```python
RATE_LIMIT_WINDOW_SECONDS = 0.250
time.sleep(RATE_LIMIT_WINDOW_SECONDS)
```

Rename before commenting. If renaming alone is insufficient, add a comment.

### When to add a why-comment

Add a comment when any of the following is true:

- The code implements a non-obvious algorithm or business rule that would take a reader significant time to reverse-engineer from the implementation alone.
- A seemingly simpler approach was deliberately rejected — document why, so a future maintainer does not "improve" the code back into a known-broken state.
- The code works around a bug or limitation in an external library, platform, or specification — include a reference (issue URL, ticket number, RFC section).
- A domain-specific constraint (regulatory, legal, financial) is being enforced that is not apparent from the business logic.

OFF-STANDARD — comment restates what the code does:
```typescript
// loop through users
for (const user of users) {
```

ON-STANDARD — comment explains why a specific ordering is required:
```typescript
// Process admins before regular users: admin deactivation must propagate
// to their sub-accounts before those accounts are evaluated. See DEV-4521.
const ordered = [...admins, ...regularUsers];
for (const user of ordered) {
```

### What never to comment

The following are prohibited in committed code:

- **Change history in comments**: version control is the record of changes. Comments like `// Added 2024-01-15 — fixed bug` must be removed before merge.
- **Disabled code blocks**: commented-out code must not be committed. Delete it; use version control to recover it if needed.
- **TODO/FIXME without a ticket reference**: `// TODO` without a linked issue is noise that never gets resolved. Use `// TODO(DEV-1234):` with a mandatory tracker reference.
- **Restating what the code does**: `// call the save function` above `save()` adds zero information.

OFF-STANDARD:
```typescript
// TODO: fix this later
// const result = oldImplementation(data);
const result = newImplementation(data);
```

ON-STANDARD:
```typescript
// TODO(DEV-8812): migrate newImplementation to support batch mode before v3.0
const result = newImplementation(data);
```

### Docstring and JSDoc requirements for exported symbols

Every exported function, class, method, and module that is part of a non-trivial internal interface must have a documentation comment. "Non-trivial" means: more than one caller, or callable by a different team or service.

Required documentation comment elements:

- One-sentence summary of purpose (not implementation).
- `@param` / parameter descriptions for every parameter that is not self-evident from the name and type alone.
- `@returns` / return value description when the return type alone does not communicate the meaning.
- `@throws` / raised exceptions or error types, with the condition that triggers them.
- A usage example when the function has non-obvious call semantics (optional ordering, required preconditions, side effects).

OFF-STANDARD (TypeScript — no documentation on a public utility):
```typescript
export function chunkArray<T>(arr: T[], size: number): T[][] {
  return Array.from({ length: Math.ceil(arr.length / size) }, (_, i) =>
    arr.slice(i * size, i * size + size)
  );
}
```

ON-STANDARD:
```typescript
/**
 * Splits an array into consecutive chunks of at most `size` elements.
 * The final chunk may be smaller than `size` if the array length is not evenly divisible.
 *
 * @param arr - The source array to split. Not mutated.
 * @param size - Maximum number of elements per chunk. Must be a positive integer.
 * @returns An array of chunks, each of which is a sub-array of `arr`.
 * @throws {RangeError} If `size` is less than 1.
 *
 * @example
 * chunkArray([1, 2, 3, 4, 5], 2) // [[1, 2], [3, 4], [5]]
 */
export function chunkArray<T>(arr: T[], size: number): T[][] {
```

OFF-STANDARD (Python — no docstring on an exported function):
```python
def paginate(queryset, page: int, per_page: int):
    offset = (page - 1) * per_page
    return queryset[offset : offset + per_page]
```

ON-STANDARD:
```python
def paginate(queryset, page: int, per_page: int):
    """
    Return a slice of `queryset` corresponding to the requested page.

    Pages are 1-indexed. Requesting a page beyond the end of the queryset
    returns an empty slice rather than raising an error.

    Args:
        queryset: Any sequence or ORM queryset that supports slicing.
        page: 1-based page number.
        per_page: Number of items per page. Must be a positive integer.

    Returns:
        A sliced subset of `queryset` for the given page.

    Raises:
        ValueError: If `page` or `per_page` is less than 1.
    """
    if page < 1 or per_page < 1:
        raise ValueError(f"page and per_page must be >= 1, got page={page}, per_page={per_page}")
    offset = (page - 1) * per_page
    return queryset[offset : offset + per_page]
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Commented-out code blocks committed to the repository | Creates confusion about whether the code is relevant; version control already tracks deletions | Delete dead code; use git history to recover if needed |
| `// TODO` with no ticket reference | TODOs without accountability are never resolved; they become permanent fixtures | Use `// TODO(TICKET-ID): description` and file the ticket before merging |
| Comment restates what the code does | Doubles the maintenance burden without adding information; goes stale immediately | Remove the comment; improve the name if the code is unclear |
| Change history in comments (`// Fixed by @alex`) | Duplicates git blame; becomes stale and misleading after refactors | Remove from code; the information lives in `git log` |
| Docs on private helper functions with obvious single-site usage | Over-engineering; adds noise without value | Reserve docstrings for exported or multi-caller interfaces |

## Deviation guidance

- Teams MAY adopt a language-specific docstring tool (e.g., Sphinx for Python, TypeDoc for TypeScript) that enforces structure beyond this baseline, provided it is consistent across the project.
- Teams MAY omit parameter documentation in docstrings when every parameter is a primitive with a self-evident name and type (e.g., `(userId: string, limit: number)`).
- Teams MUST NOT merge commented-out code blocks regardless of the stated reason (debugging aid, "keeping for reference").
- Teams MUST NOT use comments as a substitute for renaming poorly named symbols. The rename must happen first.

## Compliance test

- [ ] Is every exported or multi-caller function, class, and module accompanied by a documentation comment (docstring / JSDoc)?
- [ ] Does every documentation comment include: summary, parameter descriptions, return description, and thrown errors where applicable?
- [ ] Is the codebase free of committed commented-out code blocks?
- [ ] Are all `TODO` comments linked to a tracker ticket (`TODO(TICKET-ID):` format)?
- [ ] Do inline comments explain why rather than restating what the adjacent code does?

## References

- [Clean Code — Robert C. Martin (Chapter 4: Comments)](https://www.oreilly.com/library/view/clean-code-a/9780136083238/) — the authoritative treatment of when comments help versus harm, including the "explaining intent" and "warning of consequences" categories that motivate this standard
- [Google Developer Documentation Style Guide — Code Comments](https://developers.google.com/style/code-comments) — practical conventions for comment style, imperative mood in summaries, and what belongs in reference documentation vs. inline comments
