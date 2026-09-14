<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/testing/e2e-testing-standards.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/testing/e2e-testing-standards.md and re-run profile-sync. -->
# E2E Testing Standards (Behavior-Based)

## Primary E2E Entry Point

For DevOS projects, **`e2e` is the canonical command** for end-to-end testing. It uses `agent-browser` as the primary browser automation tool and orchestrates parallel research, per-journey task tracking, DB validation, and responsive testing in a single run.

```
e2e [--url <base-url>] [--export-report] [--dry-run]
```

See `profiles/default/standards/testing/agent-browser.md` for the full `agent-browser` command reference.

The Playwright/Cypress patterns documented below remain valid for projects that use those frameworks. For all new DevOS-scaffolded projects, use `e2e` with `agent-browser`.

---

## Summary

These standards enforce behavior-based E2E tests. Tests must simulate real user actions and verify outcomes. Presence-only assertions (e.g. `toBeVisible()` without interaction) are not acceptable for interactive features.

## Required Skill

Use the `e2e` skill for:
- Writing or reviewing Playwright/Cypress E2E tests
- Auditing existing E2E suites for false-positive risk
- Defining E2E coverage for new features

**Skill location:** `.claude/skills/e2e/SKILL.md`

## Non-Negotiables

- Every interactive element test must include a user action **and** a resulting state change assertion.
- Happy path tests must verify a success signal (UI state, navigation, data persistence).
- Error paths must be tested when the feature can fail.
- Avoid tests that only verify static UI presence for interactive features.

## Standard Test Structure

Follow the structure defined in the skill:
1. Smoke test (page loads)
2. Happy path
3. Error handling
4. Edge cases (as needed)

## Templates

Copy-paste templates live in:
`.claude/skills/e2e/references/test-templates.md`
