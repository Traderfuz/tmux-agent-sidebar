<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/verification-before-implementation.md and re-run profile-sync. -->
# Verification Before Implementation Standards

## Overview

Fixing a failing test without first reading the failure is not debugging — it is guessing with extra steps. Every guess that happens to work leaves an untested hypothesis in the codebase. Every guess that fails produces a new symptom that obscures the original root cause. Verification before implementation breaks this pattern by requiring evidence of the actual failure state before any code is written.

This standard governs the diagnostic gate that runs before implementing any fix, patch, or workaround for a failing test, build error, or unexpected runtime behavior in this project. It does NOT govern completion claims after a fix is applied (see `verify` skill), nor the full root cause investigation process (see `systematic-debugging` skill). This standard is the pre-flight step that makes both of those effective.

## Scope

This standard covers the mandatory diagnostic steps that must be completed before writing any code in response to: a failing BATS test, a failing CI run, a shell library bug, a hook misbehavior, or any other observable failure in the dev-os codebase. It does NOT cover how to write the fix itself, how to verify the fix after it is written, or how to write new tests from scratch.

## Principles

1. **Failure is a data source, not a problem to escape:** The error output, exit code, and failure context are the inputs to a diagnostic process — not noise to be cleared by trying fixes. Read the failure completely before forming any theory about its cause.
2. **Reproduce before hypothesize:** A failure you cannot reproduce consistently is not understood. A fix for an irreproducible failure is not a fix — it is a coincidence. Reproduction must be confirmed before a root cause hypothesis is formed.
3. **One hypothesis, tested to falsification:** A single testable hypothesis is more useful than three plausible theories. State what you believe is the root cause and what evidence would prove it wrong — then test that specific thing, not a bundle of speculative changes.
4. **Recent changes are the most likely culprits:** The failure appeared after something changed. `git log --oneline -10` and `git diff` cost 5 seconds and answer the most common root cause question before any other investigation is needed.
5. **The gate is non-negotiable:** Time pressure, confidence, and "obvious" fixes are not exceptions to this standard. The cost of one false fix — a new symptom, a masked bug, a regression — exceeds the cost of a 2-minute pre-flight every time.

## The Four-Step Gate

Before writing any code in response to a failure, complete all four steps in order. Do not proceed to writing a fix until Step 4 is recorded.

### Step 1 — Read the full failure output

Run the failing command fresh. Read the complete output: error message, line number, file path, exit code, and any context printed before the failure line.

**Required action:** Paste or record the exact failing test name / error message / exit code. Do not paraphrase.

```bash
# BATS: run the specific failing test to isolate output
bats tests/bats/bundle-manager.bats --filter "test name"

# Or run the full suite and read from the top of the failure block
make test-all 2>&1 | grep -A 20 "not ok"
```

**Gate:** Can you state the exact error message and the exact line it points to? If no → re-run and read again.

### Step 2 — Confirm reproduction

Run the exact same command a second time. Confirm the failure is consistent — same error, same location, same exit code.

**Gate:** Does the failure reproduce on two consecutive fresh runs? If no → the failure is intermittent. Stop. Document the flakiness rather than fixing a symptom. Intermittent failures have environmental root causes, not code logic root causes.

### Step 3 — Check recent changes

Run `git log --oneline -10` and `git diff HEAD~1` to identify what changed since the last known-good state. Cross-reference the changed files with the failing test's scope.

```bash
git log --oneline -10
git diff HEAD~1 -- scripts/lib/bundle-manager.sh  # scope to the relevant file
```

**Gate:** Can you name the most recent change that touched code in the failure's scope? If the failure appeared after a specific commit, that commit is the primary suspect.

### Step 4 — Form one falsifiable hypothesis

State a single root cause hypothesis in this form:

> "I believe the failure is caused by [X] because [Y evidence from steps 1–3]. This hypothesis is wrong if [Z — what would disprove it]."

Write this down before opening any file to edit. If you cannot complete the form, return to Step 1 — the failure has not been understood yet.

**Gate:** Is the hypothesis specific enough to test with a single targeted change? "The regex pattern doesn't match the new output format" is testable. "Something is broken in the library" is not.

---

## Rules

### R1 — No code edits before the four-step gate is complete (`MUST`)

The sequence is: run → read → reproduce → check git → hypothesize → then edit. Reversing any part of this sequence (e.g., editing first to "see what happens") is a violation. `git diff HEAD` should show zero changes at the point the hypothesis is written.

### R2 — Run the test fresh in the same environment it fails in (`MUST`)

Do not run a subset of the suite and extrapolate to the whole. Do not run in a different shell or with different env vars. Run the exact command CI would run.

```bash
# CORRECT — same invocation CI uses
make test-all

# WRONG — scoped to one file, may not catch dependencies
bats tests/bats/bundle-manager.bats
```

Exception: once the failing test is identified, run the isolated test to speed iteration. But the initial read must be from the full invocation that fails.

### R3 — Record the hypothesis before the fix (`SHOULD`)

Write the hypothesis in a comment above the first line of the fix, in a session note, or in the commit message body. This creates an audit trail and forces the hypothesis to be explicit rather than implicit.

```bash
# Root cause: _bm_registry_path() returns path with trailing newline
# because command substitution in bash preserves trailing whitespace
# from jq -r output when the value itself contains a newline.
# Falsified by: checking that path comparisons work after trimming.
```

### R4 — Do not bundle multiple hypotheses into one fix (`MUST NOT`)

If you are making more than one unrelated change to fix a failure, you are testing multiple hypotheses simultaneously. This makes it impossible to know which change fixed the problem and guarantees regressions go undetected.

```bash
# WRONG — two unrelated changes bundled
# "Fixed: changed regex AND updated path variable AND added guard"

# CORRECT — one change, run, observe; then next change if needed
# "Fixed: trimmed trailing newline from path variable"
# (run tests) → if still failing → next hypothesis
```

### R5 — Apply `systematic-debugging` Mode 2 (Layer Probe) when the failure spans more than one file (`SHOULD`)

BATS failures that involve sourcing multiple library files require layer-by-layer isolation. Check the source chain before hypothesizing: is the failure in the function under test, in a dependency it calls, or in the test fixture setup?

```bash
# Check if the failure is in setup vs. the test itself
# Add a debug echo to setup() and teardown() to confirm the fixture state
# before concluding the library function is wrong
```

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Edit → run → "see what happens" | Produces new symptoms with no baseline; masks root cause | Run → read failure → form hypothesis → edit |
| "I know what's wrong" without running the test | Confidence is not evidence; the failure may be in a different location than expected | Run the test, read the output, confirm the location |
| Changing two things at once to "be efficient" | Cannot attribute fix to a cause; second change may mask a regression | One change, one test run, observe result |
| Running a subset of the suite after a fix | Partial verification proves nothing about the full suite | `make test-all` after every fix attempt |
| Treating a flaky test as a logic bug | Flaky tests have environmental/ordering root causes; logic fixes don't address them | Document the flakiness, investigate environment |
| Reading only the last line of test output | BATS failure output contains the full `run` context above the assertion; the root cause is usually in lines 3–8, not the last line | Read from the `not ok N` line down through the `# (in test file)` block |

---

## Deviation guidance

You MAY skip Steps 2–4 (reproduction + git check + hypothesis) when ALL of the following are true:
- The failure is a typo (off-by-one character in a string literal, wrong variable name)
- The exact error message names the exact line and the fix is a one-character correction
- `git diff HEAD` shows no other changes in scope

When deviating: record in the commit message body that Steps 2–4 were skipped and why. Run `make test-all` after the typo fix — a typo fix that causes another failure was not a typo.

---

## Profile inheritance notes

This standard is authored at the `general` level and is inherited by all downstream profiles (cli, webapp, pwa, business, installable-os, cloudflare-workers, astro-*, boxi-ops, agents, skills). The diagnostic gate applies universally — it is not specific to Bash, CLI tooling, or BATS test suites. The BATS-specific guidance section below is an illustrative example for CLI/shell projects; the four-step gate applies equally to any test runner, build system, or runtime failure in any profile.

The `verify` skill (`.claude/skills/verify/SKILL.md`) governs what happens *after* a fix is applied. This standard governs what happens *before*. The two form a bracket:

```
[verification-before-implementation] → write fix → [verify]
```

The `systematic-debugging` skill governs the full 4-phase root cause process for complex failures. This standard is the abbreviated pre-flight for routine failures. When Step 4 of this standard cannot produce a falsifiable hypothesis after two attempts, escalate to `systematic-debugging`.

---

## BATS-specific guidance

This project's primary test runner is BATS. The following patterns apply this standard's rules to BATS-specific failure modes.

### Reading a BATS failure

```
not ok 7 bundle_audit detects registry-only drift
# (in test file /home/tafadzwa/projects/os/dev-os/tests/bats/bundle-manager.bats, line 89)
#   `[ "$status" -eq 0 ]' failed
# output:
#   /path/to/registry.json: line 1: unexpected token
```

Read from `not ok N` down through the `output:` block. The error is usually in the `output:` lines — the `[ "$status" -eq 0 ]` assertion line tells you *that* it failed, not *why*.

### Isolating BATS fixture failures from library failures

If the failure appears in `setup()`:
- The library is not the suspect — the fixture is
- Check `TEST_ROOT`, `mkdir -p` calls, and sourced library paths

If the failure appears in the test body after `run <function>`:
- Check `$status` vs `$output` — `status` is exit code, `output` is stdout
- A wrong `$status` means the function exited wrong; wrong `$output` means it exited correctly but printed wrong content

### Env var isolation

BATS tests in this project use env vars (`BUNDLE_REGISTRY_PATH`, `BUNDLE_MANIFEST_PATH`, `BUNDLES_DIR`) to override paths. If a test fails only in isolation but passes in the full suite (or vice versa), check whether these vars are being inherited across tests. `setup()` must unset or re-export them for each test.

---

## Compliance test

- [ ] Did you run the failing test or command fresh (not from a cached output) before forming any theory?
- [ ] Can you state the exact error message and the exact line/file it points to?
- [ ] Did you confirm the failure reproduces on two consecutive runs?
- [ ] Did you run `git log --oneline -10` and identify the most recent change in scope?
- [ ] Did you write a single falsifiable hypothesis before opening any file to edit?

If any check is unchecked: return to the corresponding step. Do not proceed to writing a fix.

If all five pass and the fix attempt fails: increment the attempt counter, return to Step 1 with fresh eyes, and escalate to `systematic-debugging` if attempt 3 produces no new diagnostic information.

---

## References

- [Verification Before Completion skill](.claude/skills/verify/SKILL.md) — the post-fix verification gate; complements this standard
- [Systematic Debugging skill](.claude/skills/systematic-debugging/SKILL.md) — full 4-phase root cause investigation; use when this standard's 4-step gate cannot produce a falsifiable hypothesis
- [Scientific Method — Karl Popper, falsificationism](https://plato.stanford.edu/entries/popper/) — one hypothesis, falsifiable, tested with the minimum change
- [BATS documentation](https://bats-core.readthedocs.io/) — `$status`, `$output`, `--filter` flag for test isolation
- Diagnose-First workflow (`profiles/general/workflows/implementation/diagnose-first.md`) — the automated 4-step variant embedded in `implement-tasks`
