<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/profile-standards-inheritance.md and re-run profile-sync. -->
# Profile Standards Inheritance

## Overview

A child profile standard should exist only when the child profile has something real to say. When child profiles duplicate parent standards for convenience, the standards tree drifts silently: one improvement in a parent becomes three stale forks in descendants. This standard defines when a profile should inherit unchanged, when it should write a thin extension, and how authored profile standards relate to extracted project standards.

## Scope

This standard covers inheritance, extension, override, and extraction-boundary rules for DevOS profile standards. It does NOT cover runtime artifact ownership beyond standards documents themselves or the detailed content of any single domain standard.

## Principles

1. **Inherit by default:** If the parent standard already fits, do not create a child copy.
2. **Child standards describe only the delta:** A child profile standard exists to say what changes for that profile, not to restate the parent.
3. **Observed truth and authored guidance stay separate:** Extracted project standards describe what a project currently does; profile standards describe what the profile recommends.
4. **Local duplication is maintenance debt:** A copied parent standard is acceptable only when the child is intentionally taking ownership of a different contract.

## Framework Basis

This standard combines four named frameworks:

- **ISO Scope Pattern:** keeps the document focused on standards inheritance and extraction boundaries.
- **RFC 2119 Normative Vocabulary:** MUST/SHOULD/MAY language makes authoring decisions reviewable.
- **Convention over Configuration:** unchanged behavior should come from inheritance, not local restatement.
- **DRY/DAMP Standards Balance:** keep the rule once in the parent; keep child examples concrete when the child really adds something.

## Rules

### Rule 1: A child profile MUST inherit unchanged parent standards

If a parent standard already governs the child profile accurately, the child profile must rely on inheritance instead of copying the file locally.

**OFF-STANDARD**

```text
profiles/default/standards/global/validation.md
profiles/general/standards/global/validation.md   # exact duplicate copy
```

**ON-STANDARD**

```text
profiles/default/standards/global/validation.md
# no child file in general; inheritance resolves to the parent
```

If the child adds nothing, the correct child file is no child file.

### Rule 2: A child profile SHOULD use a thin extension when only the delta changes

When the child profile adds profile-specific rules but keeps the parent contract intact, write a thin extension standard.

**ON-STANDARD**

```markdown
# Type Checking Standards — CLI Profile

Extends: [../../../default/standards/global/type-checking.md](../../../default/standards/global/type-checking.md)

## Overview

CLI tools add process-boundary typing concerns around argv, stdin, stdout, and exit-code contracts.
```

Thin extension expectations:

- include an `Extends:` link
- state what the profile adds or narrows
- avoid re-copying parent sections unless the child truly changes them

### Rule 3: Full overrides MUST be explicit and justified

Create a full child-profile standard only when the parent contract no longer fits the profile's actual domain.

Examples of valid full overrides:

- a PWA standard for service worker typing that the parent does not cover
- a platform-specific standard for Cloudflare Workers runtime constraints
- a business-profile SEO standard with domain-specific rules absent from the parent

If the child replaces rather than extends the parent, that replacement must be evident from the scope and overview.

### Rule 4: Authored profile standards MUST NOT be confused with extracted project standards

Profile standards are authored conventions. Extracted standards are observed project truth.

Use this split consistently:

- `profiles/.../standards/...` = profile-authored guidance
- `.dev-os/standards/global/...` = extracted project truth
- `.dev-os/standards/profile/...` = profile-synced standards in active project state

Profile-synced standards in `.dev-os/standards/profile/` feed the AGENTS.md injection pipeline. The `standards_injection` config block in `.dev-os/config.yml` controls which categories are injected, in what priority order, and up to what token cap — following the Progressive Exposure model (see `profiles/general/standards/global/progressive-exposure.md`). Profile exclusions (`exclude_inherited_files`) prevent files from reaching disk; category toggles prevent files on disk from entering AGENTS.md.

Do not write a profile standard as if it were reporting what every project currently uses.

### Rule 5: Child `tech-stack` standards MUST describe recommendations, not project truth

Child `tech-stack` standards are especially prone to drift because they tempt authors into large vendor inventories. A child `tech-stack` standard should state only:

- the profile-specific defaults
- the selection rules for alternatives
- the meaningful delta from the parent stack contract

It must not act as machine-readable config or extracted project inventory.

### Rule 6: Extraction SHOULD refine project truth, not author profile policy

Use `extract-standards` to describe what a project does. Use authored profile standards to describe what the profile wants.

If extraction reveals no consensus, do not promote the extraction output into a child profile standard without editorial rewriting and rationale.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Copying a parent standard into a child profile unchanged | Creates stale forks with no new policy | Inherit the parent directly |
| Writing a child standard that repeats 90% of the parent verbatim | Hides the real delta and increases maintenance cost | Use a thin extension focused on additions and overrides |
| Treating extracted standards as the profile contract | Confuses observed project truth with recommended conventions | Keep authored profile standards and extracted project standards separate |
| Using child `tech-stack` docs as giant vendor inventories | Reintroduces ownership ambiguity and drift | State defaults, selection rules, and deltas only |
| Creating a child file because “it feels nicer to have one locally” | Local convenience becomes long-term drift | Create the file only when the profile truly changes the rule |

## Deviation Guidance

- Teams MAY create a local child standard when they expect rapid near-term divergence from the parent, but the file must state the new ownership clearly and should be rewritten promptly into a true extension or override.
- Teams MAY keep a short bridge note in a child profile during migration from a stale fork to inheritance, provided it does not duplicate the parent's substantive rules.
- Teams MUST NOT keep exact duplicate child copies of parent standards after the migration window closes.
- Teams MUST NOT present extracted project standards as if they were stable profile guidance.

## Duplicate Detection

Verbatim parent copies in child profile standards are invisible to standard code review — they look like valid files. Use this command to detect them:

```bash
# Detect child profile standards that are byte-for-byte copies of a parent standard
# Compares same-named files across profile inheritance chains

PROFILES_DIR="profiles"
PARENT="general"    # change to the parent profile you want to check against

find "$PROFILES_DIR" -name "*.md" | while read child_file; do
  # Extract relative path within standards/
  rel="${child_file#$PROFILES_DIR/*/standards/}"
  [[ "$rel" == "$child_file" ]] && continue   # not under standards/

  parent_file="$PROFILES_DIR/$PARENT/standards/$rel"
  [[ ! -f "$parent_file" ]] && continue        # no parent counterpart

  # Skip if the child IS the parent
  [[ "$child_file" == "$parent_file" ]] && continue

  if diff -q "$child_file" "$parent_file" > /dev/null 2>&1; then
    echo "DUPLICATE: $child_file is identical to $parent_file"
  fi
done
```

**When to run:** Run this check before merging a branch that modifies any `profiles/*/standards/` file, and as part of any maintenance session audit. The script is non-destructive — it reports duplicates without deleting them.

**What to do with results:**
- If the child file adds nothing: delete it and rely on inheritance
- If the child file should add something: open it in Mode 3 via `bx-standards-creator` and add the real delta
- If the child file is intentionally identical (rare): add a comment at the top — `<!-- Intentional copy: this profile takes ownership of this standard independently -->` — so future runs can be filtered

**Approximate detection time:** Under 1 second for a typical profiles tree (10 profiles × 30 standards = 300 comparisons).

## Related Standards

- `artifact-ownership.md` for derived-artifact ownership contracts
- `tech-stack-ownership.md` for `tech-stack` artifact roles
- `../../../default/standards/global/tech-stack.md` for the base tech-stack contract

## Compliance Test

- [ ] If a child file exists, does it add or override a real parent rule instead of duplicating it?
- [ ] If the parent standard already fits, is the child relying on inheritance rather than carrying a local copy?
- [ ] Does every extension standard include a clear `Extends:` link and describe only the delta?
- [ ] Are authored profile standards clearly separated from extracted project standards?
- [ ] Do child `tech-stack` standards describe recommendations and selection rules rather than project truth?
