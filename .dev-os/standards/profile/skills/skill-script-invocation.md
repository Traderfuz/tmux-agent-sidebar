<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/skill-script-invocation.md and re-run profile-sync. -->
# Skill Script Invocation Standards

**Sibling standards:**
- [`self-contained-skills.md`](./self-contained-skills.md) — dependency declaration + portability constraints (this standard extends those)
- [`../global/bash-sourced-script-safety.md`](../global/bash-sourced-script-safety.md) — `${BASH_SOURCE[0]}` discipline inside the scripts themselves
- [`../global/cross-cli-fix-propagation.md`](../global/cross-cli-fix-propagation.md) — propagating a fix across CLI surfaces

## Overview

A skill that ships a helper script and tells the operator to run it is making two silent
promises: that the interpreter exists, and that the path resolves. Both promises break
routinely, and neither is checked by structural validation — so a skill can hold a perfect
validator score for months while every command it documents is unrunnable.

This is not hypothetical. `structured-note` v1.3.0 passed 19/19 structural checks and shipped
nine broken invocations: `python scripts/verify-structure.py`. On Debian, Ubuntu, and most
modern distributions `python` does not exist — only `python3` does. And `scripts/` resolves
against the operator's current working directory, not the skill's, so even with the right
interpreter the command targets a file in the wrong repository, or nothing at all. The
verification step of that skill had never once run.

The cost is invisible failure. The operator sees `command not found` or `No such file`,
assumes their environment is broken, and skips the step. A skipped verification step is worse
than no verification step, because the skill claims coverage it does not have.

## Scope

This standard covers how a skill's documentation invokes executable files that ship inside
that skill's own directory — interpreter selection and path resolution. It does NOT cover the
internal authoring of those scripts (see
[`bash-sourced-script-safety.md`](../global/bash-sourced-script-safety.md)), DevOS-owned
helpers outside the skill directory (see the Symlink-Safe Helper Path Rule in
`bx-skill-creator`), or commands run inside a sandbox, container, or remote runtime whose
interpreter set is controlled separately.

## Principles

1. **A documented command is a claim.** If a SKILL.md tells the operator to run something, that
   command MUST work on a stock supported system. Untested commands are documentation debt
   that reads as capability.
2. **Never assume an unversioned interpreter.** `python`, `node`, `ruby`, and `php` are all
   optional aliases on some distributions. The versioned name is the contract.
3. **A skill's scripts belong to the skill, not the caller.** Path resolution MUST anchor to
   the skill directory, because a skill runs from inside arbitrary user projects that have
   their own `scripts/`.

## Rules

### Rule 1 — Use the versioned interpreter name

Documented invocations MUST name the versioned interpreter. Bare `python` is a hard fail.

| Language | MUST use | MUST NOT use |
|---|---|---|
| Python | `python3` | `python` |
| Node | `node` | `nodejs` (Debian legacy alias) |
| Ruby | `ruby3` where the skill requires 3.x semantics | — |

```bash
# OFF-STANDARD — `python` is absent on Debian/Ubuntu; fails before it runs
python scripts/verify-structure.py path/to/note.md

# ON-STANDARD
python3 "$SKILL_DIR/scripts/verify-structure.py" path/to/note.md
```

**Exception:** a documented invocation inside a manager that provisions its own interpreter
(`uv run python …`, `poetry run python …`, `pipenv run python …`) is ON-STANDARD as written —
the manager guarantees the interpreter. Do not rewrite those to `python3`.

### Rule 2 — Resolve skill-bundled scripts through a skill-directory variable

Any invocation of a file under the skill's own directory MUST resolve through a variable that
tries the project-local skill path first, then falls back to the global DevOS install.

```bash
# OFF-STANDARD — resolves against the operator's CWD, not the skill directory
python3 scripts/build-index.py "$NOTES_DIR"

# ON-STANDARD
SKILL_DIR=".claude/skills/<skill-name>"
[ -f "$SKILL_DIR/scripts/build-index.py" ] ||
  SKILL_DIR="${DEVOS_DIR:-$HOME/.dev-os}/.claude/skills/<skill-name>"
python3 "$SKILL_DIR/scripts/build-index.py" "$NOTES_DIR"
```

The variable name SHOULD be skill-scoped (`SN_SKILL_DIR`, `GD_SKILL_DIR`) when the skill's
documentation defines more than one path variable, to avoid collisions in a copied snippet.

**The guard MUST test for a file, not a directory.** `dirname` of an empty string returns `.`,
which passes `[ -d ]` — so a directory guard silently accepts the wrong path and the fallback
never fires.

```bash
# OFF-STANDARD — `dirname ""` is `.`, `[ -d . ]` is true, fallback never fires
SKILL_DIR="$(dirname "$(readlink -f .claude/skills/foo/SKILL.md 2>/dev/null)")"
[ -d "$SKILL_DIR" ] || SKILL_DIR="${DEVOS_DIR:-$HOME/.dev-os}/.claude/skills/foo"

# ON-STANDARD — tests for the actual target file
SKILL_DIR=".claude/skills/foo"
[ -f "$SKILL_DIR/scripts/run.py" ] ||
  SKILL_DIR="${DEVOS_DIR:-$HOME/.dev-os}/.claude/skills/foo"
```

### Rule 3 — Define the variable once, before first use

The resolution block MUST appear in the skill's Prerequisites section (or an equivalent
section that precedes every invocation). A `$SKILL_DIR` referenced before it is defined is a
fail — a reader copying the second code fence gets an empty expansion.

### Rule 4 — Descriptive mentions are exempt

Naming a script in prose or in a Prerequisites list is not an invocation and needs no
resolution block.

| Line | Class |
|---|---|
| `` - **Python 3** for the bundled scripts (`scripts/build-index.py`) `` | descriptive — exempt |
| `` `scripts/verify.py` resolves against the CWD, which is why … `` | descriptive — exempt |
| `python3 "$SKILL_DIR/scripts/verify.py" note.md` | invocation — Rules 1–3 apply |

### Rule 5 — Foreign-runtime commands are out of scope

A command executed inside a sandbox, container, remote host, or a framework's own runner is
governed by that runtime, not this standard.

```javascript
// ON-STANDARD — `python` here is the sandbox container's interpreter, not the host's
const result = await sandbox.exec('python /tmp/code.py');
```

Likewise `python manage.py runserver` in a table describing Django project conventions
documents *the framework's* published command, not a skill-bundled script.

### Rule 6 — Verify from a foreign working directory

Before shipping, the author MUST execute the documented command from a directory outside the
skill's repository. Running it from the repo root proves nothing — that is the one CWD where
a bare relative path accidentally works.

```bash
cd /tmp && SKILL_DIR=".claude/skills/foo"
[ -f "$SKILL_DIR/scripts/run.py" ] ||
  SKILL_DIR="${DEVOS_DIR:-$HOME/.dev-os}/.claude/skills/foo"
python3 "$SKILL_DIR/scripts/run.py" --help
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `python foo.py` | `python` is unavailable on Debian/Ubuntu and most modern distros | `python3 foo.py` |
| `python3 scripts/foo.py` | Resolves against the operator's CWD, not the skill dir | `python3 "$SKILL_DIR/scripts/foo.py"` |
| `[ -d "$SKILL_DIR" ]` as the fallback guard | `dirname ""` → `.`, which is a real directory; fallback never fires | `[ -f "$SKILL_DIR/scripts/<file>" ]` |
| `$SKILL_DIR` used before the resolution block | Empty expansion for anyone copying that fence alone | Define in Prerequisites, before first use |
| Rewriting `uv run python x.py` to `python3` | Breaks the manager-provisioned environment | Leave manager-prefixed commands as written |
| Verifying only from the repo root | The one CWD where the bug is invisible | Rule 6 foreign-CWD check |

## Deviation guidance

You MAY deviate when the skill targets a single controlled environment (a pinned CI image, a
documented container) whose interpreter set is guaranteed. When you do: state the environment
assumption in the skill's Prerequisites, naming the image or platform. A deviating skill with
no stated environment assumption fails audit.

## Profile inheritance notes

Extends: [`self-contained-skills.md`](./self-contained-skills.md)
Adds: Interpreter-name contract, skill-directory path resolution, foreign-CWD verification.
Overrides: Nothing. Closes a documented exemption — the Symlink-Safe Helper Path Rule in
`bx-skill-creator` classifies skill-owned scripts as `repo_owned_verified` and exempts them
from its resolution requirement. **That exemption is the hole this standard fills.**

## Compliance test

- [ ] Does every documented invocation use a versioned interpreter name (`python3`, not `python`)?
- [ ] Is every manager-prefixed command (`uv run`, `poetry run`) left unrewritten?
- [ ] Does every invocation of a skill-bundled file resolve through a skill-directory variable?
- [ ] Does the fallback guard test for a file (`[ -f … ]`), never a directory (`[ -d … ]`)?
- [ ] Is the resolution block defined before the first invocation that uses it?
- [ ] Was at least one documented command executed from a directory outside the skill's repo?

If any check fails: fix it, or record the environment assumption in Prerequisites per the
deviation guidance.

## Enforcement

`validate-skill.sh` SHOULD gain an executable-claim check that extracts bash-fence
invocations of files bundled in the skill directory and asserts (a) the interpreter exists on
`PATH` and (b) the path resolves from a foreign CWD.

Interim detection:

```bash
# Bare `python <file>.py` anywhere in a skill (excluding python3 and manager-prefixed forms).
# Requires PCRE mode (-P) for the lookbehind; -E has no lookbehind and errors out.
command grep -rnP '(?<![3\w.-])python\s+\S+\.py' \
  --include='*.md' .claude/skills/ | command grep -v 'uv run\|poetry run\|pipenv run'

# Bundled script referenced by bare relative path
command grep -rnE '(^|[^/$"[:alnum:]_-])scripts/[[:alnum:]_.-]+\.(py|sh|js|ts)' \
  --include='SKILL.md' .claude/skills/
```

Both greps report descriptive mentions too — triage against Rule 4 before editing.

## References

- [PEP 394 — The "python" Command on Unix-Like Systems](https://peps.python.org/pep-0394/) —
  establishes that `python` is an optional alias and that tooling should invoke `python3`
  explicitly; the normative source for Rule 1.
- [Debian Python Policy](https://www.debian.org/doc/packaging-manuals/python-policy/) — Debian
  and derivatives ship no `python` binary by default; `python-is-python3` is a separate package.
- [The Twelve-Factor App, Factor II — Dependencies](https://12factor.net/dependencies) —
  explicitly declare and isolate dependencies; never rely on an implicit system-wide tool.
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) — path
  resolution and default expansion discipline underpinning Rule 2.
- [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) — MUST / SHOULD / MAY vocabulary.
- Real bug in this repo: `structured-note` v1.3.0 held 19/19 structural PASS with nine broken
  invocations. Fixed in v2.0.0; see
  `product/gap-analysis/2026-08-07-structured-note-multi-angle-dalio.md`.
