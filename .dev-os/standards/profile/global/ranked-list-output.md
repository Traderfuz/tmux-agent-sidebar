<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/ranked-list-output.md and re-run profile-sync. -->
# Ranked-List Output Standard

## Overview

Many DevOS skills exist to answer "what should I look at first?" — triage, health,
gap-analysis, orchestrate, portfolio, dispatch, project-status, daily-start,
project-health-audit. Their primary user-facing output is an
**ordered/ranked list** of findings, recommendations, or items. Today each one invents
its own ordering basis, severity vocabulary, numbering, and footer, so the operator
cannot scan them the same way or trust that position means priority.

This standard governs the **body shape of ranked-list output**. It complements
`command-ux.md` (which governs only the next-step footer) and `formatting-style.md`
(whitespace only). Where this standard and a skill's legacy output disagree, this
standard wins on next edit (opportunistic conformance, not a forced mass rewrite).

## Scope

Applies to any skill, command, chain, or hook whose primary output is a list the
operator reads top-to-bottom to decide what to do next. It does NOT apply to:
- prose narratives (daily-review, weekly-review, monthly-retro)
- self-contained HTML/dashboard reports (dashboard)
- flat reference catalogs with no priority order (find-skills, standards-guide)

A skill in scope renders a ranked list as its primary terminal output OR a ranked
section inside a larger report.

## Rules

### R1 — The order is PRODUCED BY the `optimize` skill (not hand-rolled)

The ranking MUST be produced by **invoking the `optimize` skill** (which delegates to
`process-optimizer` — Theory-of-Constraints binding-constraint detection). A skill MUST NOT
invent its own ad-hoc ordering heuristic and merely label it "binding-constraint". The
`optimize` skill names the single binding constraint and returns the order; the calling
skill renders *that* order. Severity (R3) **classifies** each item; `optimize` **orders**
them. A ranked list rendered without an `optimize` pass is non-compliant.

Canonical invocation (the pattern triage and project-health-audit already use):

```bash
# Feed the skill's findings to optimize; render in the order it returns.
bash -lc 'invoke_skill optimize --input "$findings_json"'   # binding-constraint pass
optimize_ranked=$(extract_binding_constraint_verdict)
render_<skill>_output_in_optimize_order "$optimize_ranked"
```

Budget the pass at ≤2s. **Fallback:** only when `optimize` is genuinely unavailable may a
skill fall back to plain severity order, and it MUST disclose the fallback via R2. The #1
item is always the one to act on now.

### R2 — Disclose the ordering basis (one line, always)

Every ranked output MUST print a single line naming its sort key, so the operator can
audit the ranking instead of guessing:

```
Order: binding-constraint (optimize) · severity tiebreak
```

or, on fallback:

```
Order: severity (binding-constraint leverage unavailable)
```

This line appears immediately above the list. Skipping it is the most common failure
this standard exists to prevent.

### R3 — One severity enum

Use exactly: **Critical · High · Medium · Low**, plus **Healthy** (or **OK**) for the
clean/pass state. Map legacy vocabularies on next edit:
- `WARN`/`OK` → Medium-or-higher / Healthy
- `RED`/`YELLOW`/`GREEN` → Critical-or-High / Medium / Healthy

Do not introduce new severity words (`partial`, `degraded`, `blocker`) as severity —
they are status descriptions, not severity levels.

### R4 — Number the ranked items

Ranked items are an ordered list (`1.`, `2.`, `3.` …) so position literally encodes
priority. Bulleted (`-`) lists are for unordered detail under an item, never for the
ranking itself. Severity-grouped sections are allowed, but within and across groups the
numbering reflects the binding-constraint order.

### R5 — Footer per `command-ux.md`

End with the canonical next-step footer from `command-ux.md` — the bare skill name as the
invocable:

```
→ Next: `<skill-name>` skill
```

and, where the skill emits machine-readable markers:

```
<<next>><skill-name> [--flags]<</next>>
NEXT STEP 👉 <skill-name> [--flags]
```

### R6 — Shared row schema for tabular ranked output

When the ranked list is a table, the first three columns are fixed, in this order:

```
| # | Severity | Item / Finding | Why here (binding constraint / evidence) | … |
```

Additional skill-specific columns follow. The `Why here` column is what makes the
binding-constraint order auditable inline (it is the per-row form of R2).

## Compliance test

- [ ] Does the output print an `Order:` line naming its sort key (R2)?
- [ ] Is the primary sort binding-constraint, with severity as tiebreak (R1)?
- [ ] Does it use only Critical/High/Medium/Low/Healthy (R3)?
- [ ] Are ranked items numbered, not bulleted (R4)?
- [ ] Does the footer use the `command-ux.md` skill-name form (R5)?
- [ ] If tabular, do the first three columns match `# | Severity | Item` (R6)?

## Deviation guidance

- A skill MAY omit numbering (R4) only when it returns exactly one recommendation; it
  still prints the `Order:` line and the `→ Next:` footer.
- A skill MAY fall back to severity order (R1) only when binding-constraint leverage is
  genuinely uncomputable, and MUST say so via R2's fallback form.
- `--json` output is exempt from R4/R5/R6 (machine consumers), but the JSON MUST carry an
  `order_basis` field (the structured form of R2) and the canonical severity enum (R3).
