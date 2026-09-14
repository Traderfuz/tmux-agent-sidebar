<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/single-source-of-truth.md and re-run profile-sync. -->
# Single Source of Truth Standard

## Overview

When two or more surfaces independently compute the same fact, they drift. The motivating
DevOS failure: `daily-start` and `session-status` each re-detected "dirty file count / open
P1 captures / propagation drift" with their own rules, so they disagreed, both paid the
detection cost every session, and a bug fixed in one detector rotted in the other. This
standard makes **one owner per fact** the default and turns every other surface into a
*consumer* of that owner — never a second detector.

## Scope

This standard covers ownership of any fact, value, count, status, list, or derived artifact
that is read by more than one surface (skill, hook, command, doc, CLI, registry). It does NOT
cover *which* value is authoritative when sources conflict — that is `verify-before-surface` /
`verify-status-against-artifact` (trust the artifact, not the marker). This one is upstream of
that: there is exactly one owner that *produces* the fact, so conflicting sources should not
exist in the first place. It does NOT forbid caching or derived views — only independent
re-derivation of the same fact.

## Principles

1. **One owner per fact:** every shared fact is produced by exactly one named thing; everyone
   else reads it.
2. **Read, don't re-derive:** a consumer that needs a fact calls the owner or reads the
   owner's artifact — it never re-implements the detection.
3. **Extend the owner, not a fork:** new fields are added to the owner so every consumer
   gains them at once; a parallel detector is the anti-pattern.
4. **Compose for overlap:** a surface that needs the owner's fact plus extra facts consumes
   the owner and adds only its unique detection on top.

## Named frameworks

### DRY — The Pragmatic Programmer (Hunt & Thomas, 1999)
"Every piece of knowledge must have a single, unambiguous, authoritative representation
within a system." DRY is usually quoted about code, but its actual subject is *knowledge* —
a computed fact is knowledge. SSOT is DRY applied to runtime facts and derived artifacts.
**Use this when:** any fact is produced in two places. DRY names the violation: the duplicate
representation is the defect, even when each copy looks locally reasonable.

### The DDD Aggregate / Bounded-Context boundary (Eric Evans, 2003)
In Domain-Driven Design exactly one aggregate root owns and mutates its invariants; other
contexts reference it, they do not maintain their own copy. The "owner per fact" rule is the
aggregate-root rule for derived facts.
**Use this when:** deciding *which* component should own a fact — the one that already owns
the underlying data/invariant, not whichever surface happened to need it first.

### Relational normalization (Codd, 1970)
Normal form removes redundant storage so an update has one place to land. SSOT is
normalization for *computed* state: one producer means one place to fix when the rule changes.
**Use this when:** justifying why a "harmless" second copy is a liability — it is the update
anomaly, moved from storage to derivation.

## Rules

### R1 — One owner per fact (`MUST`)
Every shared fact has exactly one owning producer (function, file, script, registry). Only
the owner computes the fact. Name the owner where the fact is documented.

### R2 — Consumers read, never re-derive (`MUST`)
Other surfaces consume the owner's output. A consumer MUST NOT re-implement the
detection/derivation logic.

```bash
# OFF-STANDARD — daily-start forks its own dirty-tree + capture detection
dirty=$(git status --porcelain | wc -l)            # also done in session-status → drift
p1=$(grep -c '"priority":"P1"' product/inbox.jsonl) # different rule than the capture lib

# ON-STANDARD — refresh + read the owner; consume the single sub-owners
session_status_write_md --project "$ROOT" >/dev/null   # owner of the aggregated snapshot
#   dirty tree  → owner: git status (one place)
#   P1 captures → owner: capture.sh (devos_p1_inbox_critical)
#   propagation → owner: propagation_chain_status
```

### R3 — Derived views declare their source (`MUST`)
A view, mirror, cache, or rendered copy MUST point back to the owner — a `source:` header,
an "owner:" note, or a regeneration marker (e.g. the `<!-- EXTRACTED -->` header on synced
standards). A reader must reach the owner from any copy.

### R4 — Extend the owner, don't fork it (`MUST`)
A new shared field is added to the owner. Forking a parallel detector to add "just one more
thing" is prohibited.

### R5 — Compose for partial overlap (`SHOULD`)
When surface B needs the owner's fact plus its own extras, B consumes the owner for the
shared fact and detects only its unique facts. B does not re-detect the shared fact to "keep
it together." (`daily-start` consumes `session-status` for the 4 shared signals and owns its
bundle/codebase-map/cadence signals.)

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Two skills each compute "dirty file count" | Drift — they disagree at different moments | One owner; both read it (R2) |
| Copy a registry's counts into a second script to "avoid a dependency" | Update anomaly — counts rot independently | Read the registry; don't copy (R2/R3) |
| Add a field to a forked detector because the owner is "someone else's" | Consumers never gain the field; forks multiply | Extend the owner (R4) |
| Re-detect a shared fact "so it's all in one place" | The owner already IS that place | Compose: consume + add unique (R5) |
| A rendered mirror with no pointer to its producer | Reader can't find/trust the source | Declare `source:`/owner (R3) |

## Deviation guidance

You MAY keep a **performance cache** of the owner's output (it is a view, not a second
detector) — when you do, it MUST declare its source (R3) and have a freshness/TTL story, and
the authoritative value must still come from the owner on any actionable path. You MAY keep
two genuinely-different facts that merely share a name — rename to disambiguate rather than
merge.

## Compliance test

- [ ] For each shared fact, is there exactly one named owning producer?
- [ ] Do all other surfaces consume that owner rather than re-deriving it?
- [ ] Does every derived/mirrored copy point back to its owner?
- [ ] Are new shared fields added to the owner (not to a forked detector)?
- [ ] Where a surface needs owner-facts plus extras, does it compose rather than duplicate?

If any check fails: route the fact to a single owner and convert the other surfaces to
consumers, or explicitly record the deviation (e.g. a declared cache) with its justification.

## References

- [The Pragmatic Programmer — DRY](https://pragprog.com/tips/) (Hunt & Thomas, 1999) — single
  authoritative representation of every piece of knowledge; the SSOT principle verbatim.
- [Domain-Driven Design — Aggregates](https://martinfowler.com/bliki/DDD_Aggregate.html)
  (Evans, 2003) — one root owns its invariants; the "owner per fact" rule.
- [A Relational Model of Data (Codd, 1970)](https://dl.acm.org/doi/10.1145/362384.362685) —
  normalization removes redundant representation; SSOT for computed state.
- DevOS `verify-before-surface` / `verify-status-against-artifact` — the downstream pair:
  trust the artifact when sources conflict; SSOT prevents the conflict upstream.
