# Design System Generation

Whole-project design-system generation flow for `design-system`. This workflow owns the ordered procedure for resolving project context, selecting generation mode, running the generator engine, verifying outputs, and reporting artifact paths.

## When to Use

- A project needs a new design system from a prompt
- A spec has approved design token tables that should be converted into generated artifacts
- Existing design-system JSON should regenerate downstream outputs
- A frontend slice needs project-level token, preview, and Tailwind artifacts before implementation

**Do NOT use when:** iterating a live implementation visually (`design-iteration`), auditing token adoption (`design-system-audit`), or working only on the underlying BM25 generator internals.

## Runtime Ownership

- Generator engine: `scripts/design/search.py`, `scripts/design/core.py`, `scripts/design/design_system.py`
- Verification helper: `scripts/lib/design-system.sh`
- Public orchestration skill: `.claude/skills/design-system/SKILL.md`

## Process

### Step 1 — Resolve project context

1. Detect project slug from `--project` or the git repo name.
2. If `.dev-os/config.yml` exists, read the active profile.
3. If `package.json` exists, detect the stack.
4. Record explicit fallback values when config or stack files are absent.

### Step 2 — Choose generation mode

Choose one of:
- **Fresh query** — natural-language query drives BM25 generation
- **From spec** — parse `product/specs/<spec>/planning/design-system.md`
- **From JSON** — regenerate outputs from existing `design-system.json`

### Step 3 — Run the generator engine

Fresh query mode:

```bash
python3 scripts/design/search.py "<query>" --design-system --project "<project>"
```

From-spec mode:
- first verify `planning/design-system.md` exists
- parse token tables into JSON input
- pass the temporary JSON payload into the generator

From-JSON mode:

```bash
python3 scripts/design/search.py --from-json "design-system/<project>/design-system.json"
```

### Step 4 — Write downstream validator context

After a successful generation pass, write or refresh the validator/context files that downstream design-iteration checks expect.

### Step 5 — Verify artifacts

Run:

```bash
bash -c "source 'scripts/lib/design-system.sh' && verify_design_system_outputs 'design-system/<project>'"
```

If verification fails, stop and surface the missing or malformed artifact.

### Step 6 — Report outputs

Report the generated files and point the user to the next step:
- review `design-preview.html`
- run visual iteration
- or continue to implementation using the generated tokens

## Display Format

```text
Design System Generation Complete
─────────────────────────────────────────────
Project: <project>
Profile: <profile>
Stack: <stack>
Source: <query | from-spec | from-json>

Artifacts
- design-system/<project>/design-system.json
- design-system/<project>/MASTER.md
- design-system/<project>/tokens.css
- design-system/<project>/tailwind.config.js
- design-system/<project>/design-preview.html

Verification
- verify_design_system_outputs: PASS|FAIL

Next step
- Review design-preview.html
- Or continue to design-iteration / implementation
```
