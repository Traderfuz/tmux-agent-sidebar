<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/specification-enforcement-parity.md and re-run profile-sync. -->
# Specification–Enforcement Parity

**Status:** Active
**Applies to:** every DevOS standard, skill contract, chain gate, and creator rule
**Failure mode this prevents:** Specification–Enforcement Drift

## The failure mode

A rule is written into a specification, a `SKILL.md`, a standard, or a creator
workflow — and nothing mechanically checks it. The rule reads as governance but
behaves as a suggestion. It is obeyed while someone remembers it and silently
abandoned the moment attention moves.

This is **Specification–Enforcement Drift**: the gap between what a system
declares and what it verifies. The declared rule is not wrong. It is
unenforced, which over time is indistinguishable from absent.

The drift is invisible by construction. Nothing fails. No error appears. The
artifact ships, validation passes, and the rule quietly stops being true.
Detection normally happens by accident, long after the violations have
accumulated.

### Worked incident (2026-08-11)

`bx-skill-creator` required a CHANGELOG entry for every version bump in Mode 2.
The rule was written at line 703 of the skill. `validate-skill.sh` ran 22
structural checks and none of them looked at CHANGELOG.md.

Three skills were upgraded in one session. All three bumped `1.0.0 → 1.1.0`.
Zero changelog entries were written. Every skill passed `--strict` validation.
The drift surfaced only when a human asked why the version number did not
explain what changed.

Adding the check (SK23) immediately exposed a fourth skill,
`ui-gap-analysis`, sitting at version `1.2.2` with no changelog entry at all —
drift that predated the session and would otherwise have continued indefinitely.

The same audit found four more unenforced rules in the same creator: declared
audience/output posture, routing-index registration, knowledge-freshness
expiry, and wiring-reference resolution. All four were documented. None were
checked. Two produced real defects the moment a check existed: a 56-day-stale
knowledge stamp and two dead skill references pointing at names that had been
renamed months earlier.

## The rule

**Every enforceable rule ships with its enforcement in the same change.**

A rule is enforceable when a machine can decide pass or fail without human
judgment. If a rule is enforceable, a check is mandatory. If a rule is not
enforceable, it must be labelled as guidance so nobody mistakes it for a gate.

Three permitted states, and no fourth:

| State | Meaning | Allowed |
|---|---|---|
| **Enforced** | rule + automated check, shipped together | yes |
| **Guidance** | explicitly labelled advisory, no check claimed | yes |
| **Declared-but-unchecked** | reads as a rule, nothing verifies it | **no** |

The third state is the defect. It is worse than having no rule, because it
manufactures false confidence: the specification says the property holds, the
validator says PASS, and neither statement is grounded.

## Named frameworks

### Poka-yoke (Shigeo Shingo)

Mistake-proofing designs the error out of the process rather than instructing
people to avoid it. A rule that depends on remembering is not mistake-proofed;
a rule that fails the build is.

**Use this when:** deciding whether a documented rule needs a check. If the only
thing standing between the rule and its violation is attention, it needs a
check. **Not when:** the rule requires genuine judgment — that is guidance, and
must be labelled as such.

### Executable Specification (Gojko Adzic)

A specification that cannot be run against the system will drift from it. The
same document must both describe the intent and verify it, or the two diverge
without signal.

**Use this when:** writing any standard, contract, or creator rule — pair each
clause with the command that proves it. **Not when:** the artifact is a
rationale or design-history document with no normative claims.

### Test the Test (mutation-testing principle)

An assertion that cannot fail proves nothing. A check that passes on a known
violation is a false gate — more dangerous than no gate, since it is trusted.

**Use this when:** adding any new check — introduce the violation deliberately
and confirm the check fails before shipping. **Not when:** the check is a
report-only signal that does not gate.

## Requirements

1. **Ship rule and check together.** A pull request that adds an enforceable
   rule without its check is incomplete. Do not defer the check to a follow-up.

2. **Prove the check fails.** Before shipping, run the check against a
   deliberate violation and confirm a FAIL. A check verified only against
   passing input is unverified.

3. **Label unenforceable rules.** Any rule that cannot be mechanically checked
   is marked `[guidance]` in the source text. It must not appear in a section
   that reads as a gate.

4. **Audit the corpus when a drift is found.** One unenforced rule predicts
   others in the same artifact. When you find drift, enumerate every other rule
   in that specification and classify each as enforced, guidance, or drifted.

5. **New checks start non-blocking.** Introduce a check at warning tier, measure
   the violation rate across the existing corpus, then promote it to blocking.
   A check that instantly fails a large corpus gets disabled rather than fixed.

6. **Name the enforcing check in the rule text.** The rule states which check
   enforces it — `SK23`, a test id, a CI job. A reader must be able to go from
   rule to gate without searching.

## Anti-patterns

### The Documented Gate

A specification says "must" and nothing checks it.

```text
BAD:
  "Versioning: After writing, draft a CHANGELOG entry."
  (nothing verifies the entry exists)

GOOD:
  "Versioning: After writing, draft a CHANGELOG entry.
   Enforced by SK23 — a version with no matching
   '## [version]' heading fails --strict."
```

### The Deferred Check

The rule ships now and the check ships "next sprint." The check never ships,
and the interval between them is pure drift.

### The Untested Check

The check is added, observed passing, and shipped. Nobody confirms it can fail.
Half of these are inert — matching nothing, or silently skipping when a path
does not resolve.

### The Big-Bang Blocker

A new check ships as must-fix against a corpus with hundreds of violations. The
team disables it within a day. Ship at warning tier first.

### The Orphan Rule

A rule survives a rename or refactor that removed the thing it governed. It
still reads as normative and now enforces nothing, but continues to be cited.

## Compliance test

1. Does every "must" clause in this artifact name an enforcing check, or carry
   a `[guidance]` label?
2. For each named check, has it been observed FAILING on a deliberate violation?
3. Are there rules in this artifact whose subject no longer exists?
4. When the last drift was found here, was the rest of the artifact audited, or
   only the one rule fixed?
5. Was the newest check introduced at warning tier before being promoted?

Any "no" is a Specification–Enforcement Drift finding. Classify it:

| Class | Meaning | Route |
|---|---|---|
| `direct_fix_allowed` | check is mechanical, add it now | implement in this change |
| `spec_required` | check needs design or new tooling | route to `write-spec` |
| `manual` | rule is genuinely judgment-based | relabel as `[guidance]` |

## Wiring

- **Upstream:** `bx-standards-creator`, `bx-skill-creator`, `write-spec` — any
  surface that writes normative rules.
- **Downstream:** `validate-standards`, `standards-validator`, and per-artifact
  validators such as `validate-skill.sh`.
- **Detection:** `gap-analysis --dalio` surfaces drift at the designer layer —
  a rule with no gate is a machine-design flaw, not a worker error.
