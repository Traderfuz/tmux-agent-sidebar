# Data Reset Gate

Pre-flight safety checklist that must pass before resetting a project's test database. This is the **point of no return** — once the reset executes, test data cannot be recovered.

## When to Include

Include this snippet in any workflow that resets, truncates, or wipes database tables after a QA cycle — before going to dogfooding or live clients.

```
{{include workflows/_shared/quality/data-reset-gate}}
```

## Gate Checklist

Before executing any `TRUNCATE`, `deleteMany`, or reset-account operation, verify ALL of the following:

### 1. Backup Confirmed

- [ ] Identify which data must be preserved (services, workflows, configuration tables — anything NOT in the TRUNCATE list)
- [ ] Confirm a human-readable backup exists: `docs/backups/YYYY-MM-DD-<entity>.md` (or equivalent)
- [ ] Confirm a raw JSON backup exists alongside it
- [ ] Verify the backup file is non-empty and contains expected row counts

**Gate:** If no backup exists → STOP. Create the backup first via `GET /api/settings/data/export?type=all` or equivalent export route.

### 2. QA Tests Passed

All of the following must be complete before wiping test data:

- [ ] Unit test suite: `bun run test:ci` (or equivalent) exits 0
- [ ] E2E tests: `bun run test:e2e` (or equivalent) exits 0 (or known flakes documented)
- [ ] CRUD smoke tests: all major entities pass create/edit/delete
- [ ] Export smoke test: all export types return correct data (run this BEFORE reset — empty-state export can be tested after)

**Gate:** If any test category has unexplained failures → STOP. Fix failures before resetting.

### 3. Performance Baseline Recorded

- [ ] Slow page baseline times recorded in `product/specs/<spec>/verification/performance-baseline.md` (or equivalent)
- [ ] At least one hot spot identified and either fixed or documented for v.next

**Gate:** Soft gate — if no performance triage done, note it and proceed with caution.

### 4. Protected Tables Identified

Before running the reset, explicitly list the tables that are **NOT** being reset:

```
Protected (do not truncate):
  - services / Service
  - workflows / Workflow
  - provider configs / ProviderConfig
  - user accounts / User
  - workspace settings
  [add project-specific protected tables here]
```

- [ ] Confirm these tables are excluded from the TRUNCATE/deleteMany statement
- [ ] After reset, manually verify protected tables still have their data

**Gate:** If protected tables are ambiguous → read the reset route source before proceeding.

### 5. Point-of-No-Return Confirmation

Display this prompt before executing the reset:

```
DATA RESET GATE — Final Confirmation

About to truncate the following tables:
  [list tables being reset]

Protected (will NOT be touched):
  [list protected tables]

Backups confirmed: YES / NO
All tests passed: YES / NO
Performance baseline: RECORDED / SKIPPED

Type RESET to proceed, or Ctrl+C to abort:
```

Require explicit user confirmation (`RESET` typed or equivalent dialog confirmed) before executing.

## Post-Reset Verification

After the reset completes, verify the slate is clean:

```sql
-- Run in Supabase SQL editor or equivalent
SELECT
  (SELECT COUNT(*) FROM "leads") as leads,
  (SELECT COUNT(*) FROM "clients") as clients,
  (SELECT COUNT(*) FROM "campaigns") as campaigns,
  (SELECT COUNT(*) FROM "tasks") as tasks,
  (SELECT COUNT(*) FROM "invoices") as invoices;
-- All should return 0
```

Then verify protected tables are intact:

```sql
SELECT COUNT(*) FROM "services";    -- should match pre-reset count
SELECT COUNT(*) FROM "workflows";   -- should match pre-reset count
```

## Error Handling

| Scenario | Action |
|----------|--------|
| Backup file missing | Stop. Run export first. Do NOT reset. |
| Test failures not explained | Stop. Fix failures first. |
| Protected tables unclear | Read the reset route source. Confirm before proceeding. |
| Reset partially fails | Check DB state before retrying. Do NOT double-reset. |
| Protected table accidentally wiped | Restore from backup immediately. |

## Usage in Workflows

This snippet is included in the `pre-launch-qa` spec (Phase G) and can be reused in any project that goes through the same QA → reset → dogfood cycle:

```markdown
## Phase G: Data Reset

{{include workflows/_shared/quality/data-reset-gate}}

After the gate passes, proceed to dogfooding setup.
```

## Project-Specific Configuration

When including this snippet, customize these sections for the project:

- **Protected tables list** — varies per project schema
- **Reset command** — `Settings > Data > Reset Account` in Boxi; `prisma.X.deleteMany()` in code-driven resets
- **Verification SQL** — adjust table names to match project schema
- **Backup location** — adjust path to match project conventions
