<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/no-silent-warnings.md and re-run profile-sync. -->
# No Silent Warnings

## Overview

Diagnostic output from automated runs (BATS, pytest, lint, type-check, build) is evidence. Silencing it — by hand-waving, by attributing it to "pre-existing conditions," or by letting it scroll past — degrades the rigor budget until warnings stop meaning anything at all. This standard governs how implementers (human or AI) must surface, classify, and resolve every non-trivial diagnostic emitted during implementation work.

## Scope

This standard covers diagnostic output emitted during any automated run invoked as part of implementation, testing, build, lint, or type-check. It applies to warnings, deprecation notices, advisories, `not ok` BATS cases with explicit exit-code mismatches, `WARN` log lines, and non-zero stderr output that does not produce an outright failure exit. It does NOT cover expected log noise from production services, third-party library debug output that is silenced via configuration, or output from a fresh toolchain installation.

## Principles

1. **Warnings are evidence, not noise:** A warning observed during a run tells you something the toolchain noticed. Naming it "unrelated" without reading it is a refusal to take evidence.
2. **Zero unclassified warnings at completion:** When implementation work reports "done," every warning emitted during the run is classified (gap, acknowledged-with-justification, or false-positive-with-reason) or the work is not done.
3. **Broken windows decay:** One ignored warning normalizes ignoring the next. By the third ignored warning, the run is not actually green even if `exit 0` is true.
4. **Capture before classify:** Silently deciding a warning is "pre-existing" while it scrolls past is exactly the failure mode this standard prevents. Capture it first, then classify it, then act on the classification.

## Rules

### Rule 1: Capture every diagnostic emitted during a run

Every `WARN`, `BW0N`, `not ok`, deprecation, `WARN[xxx]`, stderr line from a tool, or non-zero sub-exit during an implementation-phase run is captured into a structured record before the implementer proceeds to the next phase. (`MUST`)

```
# OFF-STANDARD (silenced)
"Pre-existing warning — unrelated to this work. Continuing."

# ON-STANDARD (captured)
"Warning BW01: tests/test-discover-wrapper.bats:17 — env DEVOS_OS_WORKSPACE=... mos-discover.sh --query os_id=definitely-not-installed --quiet exits 127. Test does not use run -127 check. Captured as gap:warning-silenced, routed to dev-os inbox."
```

### Rule 2: Classify each warning into one of three buckets

Each captured warning gets exactly one classification:

- **`gap:warning-silenced`** — The warning reveals a defect the implementer must own (typically: the test fails its own contract, the lint rule fires, the deprecation will break). Surface via `capture --project <origin-os>` for triage.
- **`gap:acknowledged-with-justification`** — The warning is real but the implementer has a documented reason for not fixing it now (e.g., fix is in-flight in another branch, dependency update pending). Justification must include: why it can wait, what unblocks it, and the issue/PR tracking it.
- **`gap:false-positive-with-reason`** — The warning is genuinely wrong (false alarm, misconfigured tool, known upstream bug with issue link). Reason must be specific — "I think it's fine" is not a reason.

`MUST NOT` leave a warning uncaptured and `MUST NOT` classify it without reading its content.

```
# OFF-STANDARD (unclassified)
"Test passes despite warning. Moving on."

# ON-STANDARD (classified)
"Warning X: classify as gap:acknowledged-with-justification —
  remediation tracked in #<issue>, target merge window 2026-08-15,
  unrelated to current slice per <link>."
```

### Rule 3: Block completion on silenced warnings

Implementation work reports completion only when zero warnings remain uncaptured and unclassified. If a warning is classified `gap:warning-silenced`, completion blocks until the captured capture record is filed and triaged. (`MUST`)

```
# OFF-STANDARD
"Step 3 of 6 done. Next: step 4."
# (Warning observed, not classified, work moves on)

# ON-STANDARD
"Step 3 of 6 done. 1 warning observed during step 3:
  - tests/test-x.bats:N — classified gap:warning-silenced, captured to inbox.
  Step 4 blocks until capture is triaged."
```

### Rule 4: Do not dismiss warnings as "pre-existing" without proof

The phrase "pre-existing warning — unrelated" is itself a classification and requires Rule 2 evidence. `MUST NOT` use "pre-existing" as a reason to skip capture. A warning observed during the current run is the current run's responsibility regardless of when the underlying defect was introduced. (`MUST`)

### Rule 5: Tools emit warnings; humans classify them

Implementer judgment is the classifier. Tooling can capture and route, but the classification decision is not automatable — it requires reading the warning and forming a position. `MUST` classify in writing (in the run log, commit message, or capture record), not silently.

## Stack Examples

The following before/after pairs cover the four toolchains used most across Marketing OS and dev-os projects. Each demonstrates the same Capture → Classify → Act arc applied to a real warning type.

### BATS (Bash test runner)

```bash
# OFF-STANDARD — warning scrolls past, implementation declared done
$ bats tests/test-discover-wrapper.bats 2>&1
BW01: `run`'s command `env DEVOS_OS_WORKSPACE=... mos-discover.sh \
  --query os_id=definitely-not-installed --quiet` exited with code 127,
  indicating 'Command not found'. Use run's return code checks, e.g.
  `run -127`, to fix this message.
# Implementer: "Pre-existing — unrelated. Continuing."
# Result: defect shipped, gate violated.

# ON-STANDARD — captured and classified before next phase
$ bats tests/test-discover-wrapper.bats 2>&1
BW01: ... (same text)

[warnings-captured] 1 diagnostic observed:
  1. tests/test-discover-wrapper.bats:17 — BW01 exit-127 check missing
     classification: gap:warning-silenced
     action: capture --project dev-os --type bug --priority P1 \
       --area discover-wrapper "BW01: test line 17 expects exit 127 \
       but does not use run -127; mask defect"
     capture-id: 20260807-fe87f8
Phase 12 proceeds — warning captured and routed.
```

### pytest (Python)

```python
# OFF-STANDARD — DeprecationWarning scrolled past
$ pytest tests/
PytestDeprecationWarning: The configuration option "asyncio_mode" is unset.
# ... 40 lines later ...
===== 22 passed, 1 warning =====
# Implementer: "Tests green. Done."
# Result: asyncio_mode will be required in pytest-asyncio 0.22.x — breaks CI on upgrade.

# ON-STANDARD — classified before completion
$ pytest tests/
PytestDeprecationWarning: The configuration option "asyncio_mode" is unset,
  and the default value will change to "strict" in future.
===== 22 passed, 1 warning =====

[warnings-captured] 1 diagnostic observed:
  1. conftest.py — PytestDeprecationWarning: asyncio_mode unset
     classification: gap:acknowledged-with-justification
     reason: pytest-asyncio 0.22.x not yet pinned in this project;
       fix is to add asyncio_mode = "auto" to pyproject.toml
     tracking: #847 — target: next dependency-update window
Phase 12 proceeds — warning classified, tracked.
```

### ESLint / TypeScript (Node/Bun)

```typescript
// OFF-STANDARD — lint advisory suppressed mid-run
$ bun run lint
/src/lib/copy-generator.ts:42:9: warning  'result' is assigned a value
  but never used  @typescript-eslint/no-unused-vars
# Implementer adds `// eslint-disable-next-line` inline and re-runs.
# Warning gone. Defect: dead code never investigated, probably a missing return.

// ON-STANDARD — advisory captured; suppress considered after classification
$ bun run lint
/src/lib/copy-generator.ts:42:9: warning  'result' is assigned a value
  but never used  @typescript-eslint/no-unused-vars

[warnings-captured] 1 diagnostic observed:
  1. src/lib/copy-generator.ts:42 — no-unused-vars: 'result' assigned, never used
     classification: gap:warning-silenced
     action: investigate — is this a missing return statement or dead assignment?
     capture: --type bug --priority P2 --area copy-generator \
       "'result' assigned but never used in copy-generator.ts:42; \
        likely missing return"
     capture-id: cap-20260807-a1b2
// Suppress only added after root cause is understood and tracked.
```

### Shell / Makefile (stderr non-zero sub-exit)

```bash
# OFF-STANDARD — non-zero stderr from sub-command ignored because outer exits 0
$ bash scripts/export-handoff.sh
jq: error (at <stdin>:0): null (null) and string ("") cannot be iterated over
Handoff export complete: output/handoff.json
# exit 0 because the script continues after the jq failure.
# Implementer: "Script exited 0. Done."
# Result: handoff.json contains a null block. Downstream importer silently skips it.

# ON-STANDARD — non-zero stderr is a warning even under exit 0
$ bash scripts/export-handoff.sh
jq: error (at <stdin>:0): null (null) and string ("") cannot be iterated over
Handoff export complete: output/handoff.json

[warnings-captured] 1 diagnostic observed:
  1. scripts/export-handoff.sh — jq: null cannot be iterated over (stderr, non-fatal)
     classification: gap:warning-silenced
     impact: handoff.json produced with null block; importer behavior unknown
     action: capture --type bug --priority P1 --area export-handoff \
       "jq null-iteration error in export-handoff.sh — output/handoff.json \
        may be malformed"
     capture-id: cap-20260807-c3d4
# Gate blocks until capture is triaged; exit 0 is not "green" here.
```
## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| "Pre-existing warning, unrelated to this work, continuing." | Uses "pre-existing" as a skip mechanism. Leaves the warning unowned. | Capture, classify as `gap:acknowledged-with-justification` with explicit reason and tracking issue. |
| Skipping warnings because the run exited 0 | Exit 0 ≠ green. Broken-window decay makes warnings stop meaning anything. | Capture every warning. Block completion on uncaptured ones. |
| Burying warning capture in a commit message trailer | Trailers are easy to skip. The capture evidence should be visible at the phase boundary. | Surface the warning at the phase boundary (in chat, run log, or completion summary). |
| Grouping all warnings into one "warnings observed" line | Hides individual classifications. Forces the reader to re-classify. | One capture record per warning, each with its own classification and routing. |
| Adding `--ignore-warnings` flags to test runners | Suppresses the signal at the source. Future implementers lose the evidence entirely. | Keep the warning visible. Capture it. Fix or justify it. |

## Deviation guidance

You MAY deviate from this standard when:

- **The warning is from a third-party library's debug output** that is silenced via runtime configuration (not test runner output). Document the silencing in the project's `package.json` / `setup.py` / equivalent with a comment explaining why.
- **The warning is from a tool version that is mid-upgrade** (e.g., you pinned a specific tool version knowing it emits a known-bad warning until the next release). Pin the version in the lockfile and link the upstream tracking issue.
- **You are running an existing test suite that pre-dates this standard and you are not the implementer of the suite.** Capture the warnings, classify them in your run log, and route them to the suite owner. Do not modify the suite to silence them.

You MAY NOT deviate by:

- Skipping capture because the warning is "obvious."
- Skipping classification because fixing the warning is out of scope for the current slice.
- Bypassing the gate by claiming "the warning was there before I started."

## Profile inheritance notes

This standard applies across all DevOS profiles. It is global, not profile-specific. Child profiles do not override it. Profiles MAY add profile-specific examples to the Anti-patterns section but cannot relax any of the five rules.

## Compliance test

- [ ] Was every `WARN`, `BW0N`, `not ok` (with exit-code mismatch), deprecation, advisory, and non-zero stderr line from the implementation run captured into a structured record?
- [ ] Does each captured record carry one of the three classifications: `gap:warning-silenced`, `gap:acknowledged-with-justification`, or `gap:false-positive-with-reason`?
- [ ] For each `gap:acknowledged-with-justification` record: is there a tracked issue/PR and a stated unblock condition?
- [ ] For each `gap:false-positive-with-reason` record: is the reason specific (issue link, upstream bug, configuration cause) — not "looks fine" or "probably fine"?
- [ ] Was the phrase "pre-existing" never used as the sole justification for skipping a warning?
- [ ] Was implementation completion blocked on any uncaptured or unclassified warning from the current run?

If any check fails: the run is not yet complete. Either capture+classify the warnings or stop and route them to the inbox.

## References

- [Broken Windows Theory — Wilson & Kelling (1982)](https://www.jstor.org/stable/20043835) — One visible ignored warning normalizes ignoring the next. The theoretical basis for treating warning capture as a rigor-budget concern, not a politeness concern.
- [`capture` skill](../../../../.claude/skills/capture/SKILL.md) — The mechanical capture path used by Rule 1. Routes classified warnings to the owning project's inbox.
- [`implement-tasks` skill, Phase 11c](../../../../.claude/skills/implement-tasks/SKILL.md) — The Warning Capture Gate that enforces Rules 1–4 at the completion boundary.
- [`verify-before-surface`](verify-before-surface.md) — Companion standard. That one reconciles *stored backlog items* against source-of-truth before surfacing; this one captures *live diagnostic output* before completion. Together they close both ends of the evidence loop.