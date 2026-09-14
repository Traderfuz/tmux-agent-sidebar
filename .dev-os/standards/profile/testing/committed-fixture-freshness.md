<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/testing/committed-fixture-freshness.md and re-run profile-sync. -->
# Committed Fixture Freshness Standards

## Overview

A committed fixture is a file checked into the repository that stands in for real data — a JSON manifest, a golden output, a seed record, a recorded HTTP response. Its structure is usually validated on load, so it fails loudly when its *shape* drifts. Its **currency** is validated by nobody: when the schema, the enum, the template key, or the provider contract it imitates moves on, the fixture keeps parsing and the tests keep passing. The suite goes green while proving something about a world that no longer exists.

This standard makes fixture currency an owned, checked property. Every committed fixture carries a version stamp and a named producer, and something in CI fails when the producer moves and the fixture does not.

## Scope

This standard covers committed fixtures — files stored in the repository that imitate real data or real responses, including JSON/YAML manifests, seed definitions, golden/approval files, and recorded provider payloads. It does NOT cover ephemeral test data created and torn down inside a run; that is owned by `test-data-lifecycle.md`. For detectors, this standard also governs the evaluation protocol for detector changes: the provenance of test fixtures (recorded, never invented) and the required precision and recall reporting.

## Principles

1. **Structural validity is not currency.** A fixture that parses proves its shape, not that the shape is still the one production uses. Parsing answers "is this well-formed?", never "is this still true?"
2. **Every fixture has a named producer.** A fixture imitates something specific — a schema, an API contract, a config loader. If nobody can name what it imitates, nobody can tell when it went stale.
3. **Drift must fail, not accumulate.** An unenforced checker is documentation. If the only thing standing between a stale fixture and a green build is somebody remembering a command, the fixture is unguarded.
4. **Refresh is deliberate.** A fixture updated as a side effect of an unrelated commit has not been reviewed. Re-approval is an explicit act with an explicit stamp.

## Rules

### Every committed fixture declares a version stamp (`MUST`)

The fixture carries a machine-readable field recording when its shape was last reconciled with its producer — `fixtureVersion`, `definitionVersion`, `schemaVersion`, or equivalent. A fixture with no stamp cannot be audited for staleness.

```json
// OFF-STANDARD — no stamp; staleness is invisible
{
  "client": "fixture-client",
  "definitions": [{ "formIdentifier": "fixture-client:checklist", "isActive": true }]
}

// ON-STANDARD — stamped and attributable
{
  "client": "fixture-client",
  "definitionVersion": "2026-08-14",
  "producer": "prisma/schema.prisma:CaptureDefinition + CaptureDefinitionManifestSchema",
  "definitions": [{ "formIdentifier": "fixture-client:checklist", "isActive": true }]
}
```

### Every fixture names its producer (`MUST`)

Record the schema, contract, or loader the fixture imitates — in the fixture itself, in a sibling `README.md`, or in a fixture registry. The producer is what the freshness check compares against.

### A freshness check runs in CI (`MUST`)

Drift detection is wired into the automated pipeline, not left to memory. The check compares each fixture's stamp and content against its producer and fails when the producer moved and the fixture did not.

```yaml
# OFF-STANDARD — a checker exists but nothing invokes it
# scripts/check-capture-definitions.ts  ← no package script, no workflow reference

# ON-STANDARD — wired and failing-closed
- name: Fixture freshness
  run: bun run check:fixtures
```

### Semantic references resolve, not just parse (`MUST`)

When a fixture references something by key — a template key, a sequence key, an enum member, a foreign id — the check resolves that key against the real source. A syntactically valid key pointing at a deleted template is exactly the failure this standard exists to catch.

```ts
// OFF-STANDARD — shape is validated, references are assumed
const manifest = ManifestSchema.parse(await Bun.file(path).json())

// ON-STANDARD — shape validated, then references resolved
const manifest = ManifestSchema.parse(await Bun.file(path).json())
for (const def of manifest.definitions) {
  assertTemplateExists(def.acknowledgementTemplateKey)
  assertSequenceExists(def.nurtureSequenceKey)
}
```

### A fixture used as reuse evidence is refreshed before it is trusted (`MUST`)

When a fixture is the control case proving something is generic, portable, or backwards-compatible, its freshness is verified *before* the validation that depends on it. A stale control case makes a passing portability test meaningless.

### Refresh is a deliberate, stamped commit (`SHOULD`)

Fixture content changes in a commit whose message says the fixture was refreshed, with the stamp bumped in the same change. A fixture whose last touch was a `chore(wip)` or an unrelated context refresh has not been reviewed.

### Producer changes carry a fixture checklist item (`SHOULD`)

A migration, schema change, or provider-contract change includes an explicit decision about affected fixtures — refresh, or record why no refresh is needed. Silence is not a decision.

### A detector fixture is copied from a recorded failure, never invented (`MUST`)

A fixture for a detector — regex, matcher, gate, classifier, lint rule — is the verbatim string from a recorded real failure. An invented example that "looks like" the failure tests the test, not the detector.

Fixture staleness elsewhere in this standard is a fixture that was real and drifted. This is its twin: a fixture that was never real at all. Both are "the fixture does not correspond to reality"; they differ only in whether it ever did.

```bash
# OFF-STANDARD — invented fixture, passes for the wrong reason
PATTERN='no api|there is no'
run "There is no keyword API available"     # green: matched 'there is no'

# ON-STANDARD — verbatim string from the recorded incident
PATTERN='no (\w+ ){0,2}(tool|api|server|capability)s?\b'
run "no keyword API mounted"                # the string that actually escaped
```

The off-standard case is a real defect. A flat `no api` alternative cannot span the intervening word in `no keyword API mounted` — the exact claim the gate was built to catch. The invented fixture tripped a different alternative, so the suite went green over a pattern that did not work, and the gate was reported as verified.

### A detector fixture is verified to fail before the fix (`MUST`)

Run the fixture against the *pre-fix* detector and confirm it fails. A fixture that already passes before the fix is not reproducing the defect, and its green after the fix proves nothing about the change.

### A detector change reports precision and recall, never one alone (`MUST`)

A detector is a binary classifier, so single-metric evaluation is not evaluation.

- **Precision** — hit rate on a real corpus. Guards against noise that trains readers to ignore the gate.
- **Recall** — hit rate on recorded true positives. Guards against a pattern too restrictive to fire at all.

Report both, with corpus size. Tightening a pattern to improve precision silently costs recall; that tradeoff is made visible at change time rather than discovered after an escape.

```text
# ON-STANDARD
corpus:     656 assistant turns / 121 transcripts
precision:  6.9%          (noise threshold ~20%)
recall:     6/6 recorded errors  (3/6 before tuning)
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Relying on schema parsing alone | Proves shape, never currency; stale fixtures parse perfectly | Add a producer-comparison check on top of parsing |
| Unwired checker script | Runs only when remembered; drift accumulates silently between runs | Invoke it from a package script and CI |
| No version stamp | Staleness is unmeasurable; git mtime lies after unrelated touches | Stamp the fixture and bump on refresh |
| Fixture refreshed inside an unrelated commit | Change was never reviewed as a fixture decision | Dedicated refresh commit with the stamp bump |
| Stale fixture used as portability evidence | Green test proves compatibility with a past version of the system | Refresh the fixture before the test that depends on it |
| Keys validated as strings only | A well-formed key pointing at a deleted record passes | Resolve every referenced key against its source |
| Invented fixture for a detector | Passes for a different reason than the real input; green over a broken pattern | Copy the verbatim string from the recorded failure |
| Detector fixture never seen to fail | A test green both before and after the fix measures nothing | Confirm the fixture fails against the pre-fix detector |
| Reporting only precision | A pattern too restrictive to fire looks clean because it never fires | Report recall on recorded positives alongside precision |

## Deviation guidance

You MAY skip the CI freshness check for a fixture that is deliberately frozen — a regression case pinned to a historical payload, or a golden file recording a bug's exact past output. When you do: the fixture MUST state that it is intentionally frozen, name the behavior it pins, and be excluded from the freshness check by an explicit allowlist entry rather than by omission.

## Profile inheritance notes

Standalone testing standard for the `general` profile; inherited by all child profiles. Complements `test-data-lifecycle.md`, which owns ephemeral run-scoped data — this standard owns persistent committed fixtures. Composes with `backend/migrations.md`: a migration is the most common producer change that strands a fixture.

## Compliance Test

- [ ] Does every committed fixture carry a version stamp field?
- [ ] Does every committed fixture name the schema, contract, or loader it imitates?
- [ ] Is a fixture freshness check invoked from CI (not only available as a script)?
- [ ] Does the check resolve referenced keys against their real source, rather than validating them as strings?
- [ ] Was every fixture whose content changed in the last release refreshed in a commit that says so and bumped its stamp?
- [ ] Is every fixture excluded from the freshness check listed in an explicit frozen-fixture allowlist with a stated reason?
- [ ] For any fixture used as portability or reuse evidence, is its freshness verified before the test that depends on it?
- [ ] Is every detector fixture copied verbatim from a recorded real failure rather than invented?
- [ ] Was each detector fixture confirmed to fail against the pre-fix detector before the fix landed?
- [ ] Does every detector change report both precision (real corpus) and recall (recorded positives), with corpus size?

If any check fails: add the missing stamp and producer, wire the check into CI, or record the fixture in the frozen allowlist with its justification.

## References

- Gerard Meszaros, *xUnit Test Patterns* (2007) — **Fragile Test / Fragile Fixture**: a fixture coupled to a moving system breaks or misleads when that system changes. **Shared Fixture** and **Standard Fixture** describe the reuse pressure that makes committed fixtures attractive and stale.
- Ian Robinson / Pact — **Consumer-Driven Contracts** and provider verification: the consumer's recorded expectations are replayed against the *current* provider so producer drift fails the pipeline instead of surfacing in production.
- Llewellyn Falco et al., **Approval / Golden Master testing** — a checked-in expected artifact is authoritative only while it is deliberately re-approved; approval is an explicit act.
- Alexis King, *Parse, Don't Validate* — parsing establishes a shape at the boundary. It is the reason structural validation feels like verification while proving nothing about semantic currency.
- Shigeo Shingo — **poka-yoke** (mistake-proofing): a control that depends on a human remembering it is not a control. Wiring the check into CI is the mistake-proofing step.
- Kent Beck, *Test-Driven Development: By Example*; Martin Fowler, **Self-Testing Code** — **Defect-Driven Testing**: build the test from the actual defect report rather than invented or speculative scenarios, and confirm it fails before the fix. A test that passes immediately is not reproducing the defect.
- C.J. van Rijsbergen, *Information Retrieval* (SIGIR) — **precision, recall, and the F-measure**: both metrics are required because the tradeoff between them is adjustable by threshold. A false negative means the pattern was too restrictive to match a valid variation.
