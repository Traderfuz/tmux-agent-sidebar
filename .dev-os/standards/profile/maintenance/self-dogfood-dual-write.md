<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/self-dogfood-dual-write.md and re-run profile-sync. -->
# Self-Dogfood Dual-Write Standards

## Overview

DevOS is dogfooded from inside its own repository, so many fixes touch artifacts that exist in two places: the canonical profile source and the active project-local installation. A local-only fix makes the current session pass but is overwritten by the next profile activation; a source-only fix is durable but leaves the current dogfood run broken until propagation happens.

This standard applies GitOps-style source-of-truth discipline and configuration-drift control to DevOS self-hosting work: durable fixes land in source, active-session fixes land locally, and verification proves both surfaces agree.

## Scope

This standard covers dual-write handling for DevOS profile-distributed artifacts during self-dogfooding. It does NOT cover ordinary downstream client projects, release packaging, or global installer propagation.

## Named frameworks

- **GitOps Source of Truth:** Durable system state must be represented in version-controlled source, not only in a live runtime copy.
- **Configuration Drift Management:** Runtime/configuration copies must be compared against their intended source to prevent silent divergence.
- **RFC 2119 Normative Vocabulary:** MUST/SHOULD/MAY language makes the dual-write contract checkable.
- **DRY/DAMP Standards Balance:** Source remains authoritative (DRY), while local active copies may be updated explicitly to keep dogfood examples and verification meaningful (DAMP).

## Principles

1. **Source is durable:** Canonical profile files are the only durable fix surface for future projects and re-init runs.
2. **Local is executable:** `.dev-os/` is the active surface the current dogfood session executes.
3. **Drift must be intentional:** Any difference between source and local copies must be explained, temporary, or eliminated.
4. **Verification spans both surfaces:** A fix is not complete until both source and active local copies parse or pass their relevant checks.

## Rules

### Rule 1 — Identify distributed artifacts first

Before editing a DevOS artifact under `.dev-os/`, `.claude/`, or generated project-local surfaces, agents MUST check whether it is profile-distributed from `profiles/**`.

```text
# OFF-STANDARD
Edit only .dev-os/chains/build-slice.yaml because that is where the failure occurred.

# ON-STANDARD
Find the canonical source first:
profiles/general/chains/build-slice.yaml
.dev-os/chains/build-slice.yaml
```

### Rule 2 — Dual-write profile-distributed fixes

When a defect is found in a profile-distributed artifact while dogfooding inside the DevOS repo, agents MUST apply the same semantic fix to both:

- canonical source: `profiles/<profile-or-parent>/<artifact-path>`
- active local copy: `.dev-os/<artifact-path>`

```text
# OFF-STANDARD
Patch only .dev-os/chains/build-slice.yaml.

# ON-STANDARD
Patch both:
profiles/general/chains/build-slice.yaml
.dev-os/chains/build-slice.yaml
```

### Rule 3 — Prefer source when copies diverge

If the source and local copy differ before the fix, agents SHOULD treat `profiles/**` as authoritative unless the local copy contains a clearly intentional project-local override. When uncertain, inspect activation metadata or ask before overwriting local-only intent.

### Rule 4 — Verify both surfaces

After a dual-write fix, agents MUST run the smallest relevant verification on both paths. For YAML chains, parse both files. For shell libraries, run syntax checks and targeted tests. For standards, ensure both source and installed copies exist and have identical or intentionally different content.

```bash
python3 - <<'PY'
import yaml
for path in ['profiles/general/chains/build-slice.yaml', '.dev-os/chains/build-slice.yaml']:
    with open(path) as f:
        yaml.safe_load(f)
    print(f'{path}: OK')
PY
```

### Rule 5 — State deviations explicitly

Agents MAY write only one surface when the change is intentionally local-only or source-only. When doing so, they MUST state the reason and the expected propagation behavior.

Examples:

- Local-only: testing an experiment that should not survive `devos-init`.
- Source-only: preparing a profile change for future projects, followed by an explicit `devos-init` or sync step before local execution.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Patch only `.dev-os/**` | Re-init overwrites the fix | Patch source and local active copy |
| Patch only `profiles/**` | Current dogfood command still reads stale local copy | Patch local too, or run profile activation immediately |
| Assume `.dev-os/**` is source | Confuses runtime installation with canonical profile content | Locate the owning file under `profiles/**` |
| Silent drift | Future agents cannot tell whether divergence is intentional | Document the deviation or eliminate it |
| Verify only one path | One surface can still be broken | Run checks against both paths |

## Deviation guidance

You MAY deviate from dual-write when the artifact is not profile-distributed, when the change is intentionally project-local, or when activation/sync is the next immediate step. When you do, state which surface was intentionally skipped and why.

## Profile inheritance notes

Extends the general DevOS maintenance standards. Adds a self-hosting-specific rule for profile-distributed artifacts where DevOS is both the product under test and the active project using that product.

## Compliance test

- [ ] Did the change touch a `.dev-os/`, `.claude/`, or other active project-local DevOS artifact?
- [ ] If yes, did the agent check for a canonical owner under `profiles/**`?
- [ ] If the artifact is profile-distributed, was the same semantic fix applied to both source and local active copy?
- [ ] If only one surface was changed, is the local-only or source-only reason stated explicitly?
- [ ] Did verification run against both changed surfaces?
- [ ] Does `git diff` show no unexplained source/local drift for the touched artifact?

If any check fails, patch the missing surface or record the deviation before declaring the dogfood fix complete.

## References

- [OpenGitOps Principles](https://opengitops.dev/) — source-controlled desired state and operational convergence.
- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) — normative MUST/SHOULD/MAY language for checkable standards.
- [Configuration drift](https://en.wikipedia.org/wiki/Configuration_drift) — divergence between intended and actual system state.
