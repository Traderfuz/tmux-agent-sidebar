<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/testing/verification-scope.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/testing/verification-scope.md and re-run profile-sync. -->
# Verification Scope Standards

## Overview

Fast verification matters, but false confidence is worse than slow feedback. This standard defines how to choose the right verification scope after a change: when a targeted test is enough for iteration, when an affected suite must run before claiming a fix, when a full regression run is required, and when smoke or E2E checks are mandatory because the risk is user-facing rather than purely internal.

This standard exists to stop two failure modes that waste time in opposite directions: running `make test-all` for every tiny edit, and claiming a change is safe after only one narrow test that never exercised the real blast radius.

## Scope

This standard covers test-execution scope selection for code changes in the default profile. It does NOT cover how to write individual tests (see `test-writing.md`) or how to design behavior-based E2E coverage (see `e2e.md` and `agent-browser.md`).

## Principles

1. **Fastest trustworthy signal first:** Start with the smallest check that can prove or disprove the change you just made.
2. **Blast radius determines final scope:** The wider the contract touched, the wider the verification scope required before completion.
3. **User-facing risk beats file count:** A one-line change in a critical workflow can require broader verification than a twenty-line refactor in an isolated helper.
4. **Completion claims require end-state verification:** Iteration may use targeted tests; completion requires the verification scope that matches the final risk.

## Framework Basis

This standard combines four named frameworks:

- **ISO Scope Pattern:** explicitly separates execution-scope selection from test-writing and E2E design.
- **RFC 2119 Normative Vocabulary:** MUST/SHOULD/MAY language makes the escalation rules testable.
- **Test Pyramid:** prefer fast, low-level verification first; escalate only when the change boundary demands it.
- **Risk-Based Testing:** final verification scope is chosen by impact, coupling, and customer-facing risk, not by developer convenience.

## Rules

### Rule 1: Use targeted verification during active iteration

After a local change, run the smallest relevant verification command first (`SHOULD`). This is the iteration loop, not the completion gate.

Use targeted verification when all of the following are true:

- the changed code is isolated to one module or one command surface
- the expected failure mode is local and already understood
- the change does not alter shared contracts, generated artifacts, or repo-wide behavior

**OFF-STANDARD**

```bash
# Tiny change to one BATS helper, but immediately run the full suite
make test-all
```

**ON-STANDARD**

```bash
# Narrow change: run the directly affected suite first
bats tests/bats/lib/standards-extractor.bats

# Narrow Python runtime change: run the owning suite first
bats tests/bats/lib/devos-agent-runtime.bats
```

Targeted verification is an iteration tool. It is not, by itself, permission to say the work is done.

### Rule 2: Run the affected suite before claiming a fix

Before saying a bug is fixed or a task is complete, run the suite that owns the changed behavior (`MUST`).

Examples:

- command router change → `bats tests/bats/lib/command-router-start.bats` and related command-router suite
- standards extraction change → `bats tests/bats/lib/standards-extractor.bats`
- profile activation change → `bats tests/bats/lib/profile-activation.bats`

**OFF-STANDARD**

```bash
# Only rerun one single test case or rely on reasoning
bats tests/bats/lib/standards-extractor.bats --filter "extract_tech_stack creates output file"
```

**ON-STANDARD**

```bash
# Run the owning suite for the changed behavior
bats tests/bats/lib/standards-extractor.bats
```

### Rule 3: Escalate to adjacent suites when the change crosses boundaries

Run adjacent suites (`SHOULD`) when the changed code is a shared helper, path contract, command surface, artifact writer, or anything read by multiple pipelines.

Escalate from one targeted suite to a small verification set when the change affects:

- shared library functions used by multiple commands
- output paths consumed by other systems
- start/resume/orchestrate/runtime surfaces
- file ownership, freshness, or sync semantics

**Example verification set**

```bash
bats tests/bats/lib/profile-activation.bats
bats tests/bats/lib/profile-activation-dynamic.bats
bats tests/bats/lib/standards-extractor.bats
bats tests/bats/lib/command-router-start.bats
```

If you changed a writer, verify at least one real reader.

### Rule 4: Run full regression for cross-cutting or release-risk changes

Run the full regression command (`MUST`) before completion when the change is cross-cutting, release-facing, or hard to bound locally.

Full regression is required for:

- dependency upgrades
- framework/runtime upgrades
- shared initialization flows
- repo-wide path migrations
- contract drift fixes that touch multiple commands and tests
- release hardening, merge gating, or deployment validation changes

Default full regression command:

```bash
make test-all
```

If `make test-all` is not runnable in the current environment, you MUST say so explicitly and list the targeted suites that were run instead.

### Rule 5: Use smoke or E2E verification for user-facing workflows

When the change affects a user flow, browser interaction, auth journey, CRUD path, or release-critical command, unit/integration coverage alone is insufficient. Run a smoke or E2E check (`MUST`).

Use smoke/E2E verification for:

- new or changed UI flows
- login, checkout, onboarding, and settings flows
- command workflows that orchestrate multiple steps
- changes where the failure mode is sequencing rather than pure logic

**Examples**

```bash
e2e --url http://localhost:3000

# Or targeted browser verification for one flow
agent-browser open http://localhost:3000/login
agent-browser snapshot -i
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password"
agent-browser click @e3
agent-browser wait --url "**/dashboard"
```

### Rule 6: Record any verification downgrade as a deviation

You MAY stop at targeted or adjacent suites only when a full run is blocked by environment, time budget, or unrelated suite instability. When that happens, you MUST record:

- what was intended
- what actually ran
- why the broader verification did not run
- the residual risk

Approved downgrade example:

```text
Intended: make test-all
Ran instead: standards-extractor, profile-activation, command-router-start
Blocked by: unrelated pre-existing suite failure in release-hardening fixtures
Residual risk: repo-wide regressions outside the touched standards pipeline are not ruled out
```

## Decision Ladder

Use this order:

1. **Targeted test** — prove the local edit behaves as intended
2. **Owning suite** — prove the changed behavior still works in its real test context
3. **Adjacent suites** — prove shared readers/writers/contracts still line up
4. **Full regression** — prove cross-cutting safety when blast radius is large
5. **Smoke/E2E** — prove the user-facing workflow still works when the change affects flows, not just units

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Running `make test-all` after every tiny local edit | Slows iteration so much that developers stop verifying often | Start with the narrowest targeted suite, then escalate only as risk grows |
| Claiming completion after one narrow test | Proves only the local symptom, not the owning behavior or shared contract | Run the owning suite before saying the fix is complete |
| Never running full regression on cross-cutting changes | Shared breakage only appears after merge or release | Escalate to `make test-all` for broad path, contract, or initialization changes |
| Skipping smoke/E2E for user-flow changes because unit tests passed | Sequencing and browser-state failures are invisible to local unit checks | Run `e2e` or an equivalent smoke flow |
| Quietly downgrading verification scope | Reviewers and future maintainers assume broader safety than was actually checked | State the downgrade, blocker, and residual risk explicitly |

## Deviation Guidance

You MAY stop at targeted + owning suite verification when:

- the change is isolated
- the blast radius is demonstrably local
- no shared paths, generated artifacts, or user-facing flows changed

You SHOULD add adjacent suites when:

- a shared helper changed
- a file path changed
- a command writes output another command reads

You MUST run full regression when:

- you cannot confidently bound the blast radius
- the change affects release, merge, bootstrap, or cross-command behavior
- the change updates canonical contracts or repo-wide defaults

You MUST run smoke/E2E verification when:

- the change affects a real user journey
- the change can fail because of orchestration, not just local logic

## Related Standards

- `test-writing.md` — how to structure tests and what good unit tests look like
- `e2e.md` — behavior-based E2E coverage rules
- `agent-browser.md` — DevOS browser verification workflow

## Compliance Test

- [ ] Did I start with the smallest relevant targeted verification command?
- [ ] Before claiming success, did I run the suite that owns the changed behavior?
- [ ] If the change crossed boundaries, did I run adjacent suites that read/write the same contract?
- [ ] If the blast radius was broad or release-facing, did I run `make test-all` or explicitly document why not?
- [ ] If the change affected a user flow, did I run smoke/E2E verification rather than relying only on unit or library tests?

If any answer is no, broaden the verification scope or document the deviation and residual risk before completion.

## References

- Martin Fowler, *The Practical Test Pyramid* — basis for preferring fast, lower-level verification first
- Kent C. Dodds, *The Testing Trophy and Testing Classifications* — reminder that test value comes from behavior confidence, not raw suite size
- RFC 2119, *Key words for use in RFCs to Indicate Requirement Levels* — basis for MUST/SHOULD/MAY compliance language
