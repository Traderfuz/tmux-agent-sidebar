<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/file-discovery.md and re-run profile-sync. -->
# File Discovery Standards

## Overview

DevOS shell scripts discover files in two distinct contexts: shallow single-directory listings (profile commands, skill catalogs) and multi-level recursive scans (standards extraction, codebase mapping). The wrong tool for the context — an unbounded `find` where a glob would do, or a subprocess where the shell can do it inline — wastes IO, fails silently on symlinked directories, or breaks on macOS's system Bash 3.2. This standard governs which tool to use, how to bound recursive searches, how to handle symlinks correctly, and which tools must never become required dependencies.

This standard extends and refines the alias-bypass rule in `shell-safety.md` (use `command find`, not bare `find`) with file-discovery-specific depth, symlink, and output hygiene rules.

**Sibling standards:**
- [`shell-safety.md`](./shell-safety.md) — canonical alias-bypass rules for all POSIX commands (this standard extends those)
- [`bash-sourced-script-safety.md`](./bash-sourced-script-safety.md) — sourced-library invocation discipline

## Scope

This standard covers file and directory discovery in DevOS shell scripts (`scripts/lib/`, `scripts/`, profile scripts). It does NOT cover file content searching (use `grep`/`command grep`), file manipulation (mv/cp/rm — see `shell-safety.md`), or glob patterns inside BATS test assertions.

## Principles

1. **Bound every recursive search:** An unbounded `find` is a latent performance bug. Every recursive file discovery operation must declare a `maxdepth` — even when the depth "seems obvious". Unbounded searches silently become expensive as project trees grow.
2. **Prefer the shell when the shell is enough:** A shell glob incurs zero subprocess overhead and zero fork cost. For flat-directory listings, a glob loop is always faster and simpler than `command find`. Reserve `find` for cases that require multi-level recursion, complex conditions (`-o`, `-type`, `-newer`), or symlink dereferencing flags.
3. **No undeclared external dependencies:** `fd` and `rg` are not pre-installed in CI. Adding them as required commands breaks the DevOS install on clean environments and violates the "prefer native over tools" principle established in BOX-45. They are optional enhancements, not baselines.
4. **Deterministic output for pipes and LLMs:** Shell glob expansion order is filesystem-dependent. Any file list fed to a downstream process (LLM, sort-sensitive script, diff) must be sorted. `| sort` is always cheap; non-deterministic ordering is never acceptable in automation.

## Rules

### Rule 1 — Flat directory listing: use shell glob

When discovering files in a single directory (no recursion needed), use a shell glob loop instead of `command find`.

```bash
# OFF-STANDARD — subprocess overhead for a flat listing
command find "$commands_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null

# ON-STANDARD — zero subprocess overhead
for f in "$commands_dir"/*.md; do
    [[ -f "$f" ]] || continue   # guard: skip if glob matched nothing
    printf '%s\n' "$f"
done
```

**MUST** guard against empty-match expansion: `[[ -f "$f" ]] || continue`. When the glob matches nothing, bash expands to the literal string (e.g., `"$dir/*.md"`), and the guard prevents treating it as a real file.

### Rule 2 — Shallow recursive scan: use `find` with explicit `maxdepth`

When scanning 2–4 directory levels deep, use `command find` with an explicit `-maxdepth`.

```bash
# OFF-STANDARD — unbounded recursion
command find "$standards_dir" -name "*.md" -type f 2>/dev/null | sort

# ON-STANDARD — bounded, predictable IO
command find "$standards_dir" -maxdepth 4 -name "*.md" -type f 2>/dev/null | sort
```

**MUST** set `-maxdepth` on every `find` invocation. There is no case in DevOS where an unbounded recursive search is correct.

**Depth guidance:**

| Directory structure depth | Recommended maxdepth |
|---|---|
| `dir/file` | 1 |
| `dir/subdir/file` | 2 |
| `profiles/<name>/standards/<area>/file` | 4 |
| Unknown / conservative default | 6 |

### Rule 3 — Symlinked start directory: use glob or `find -L`

`find` without `-L` silently returns nothing when the start path is a symlink. This is a confirmed real bug fixed in DevOS 2026-02 (`command-router.sh`).

```bash
# OFF-STANDARD — returns nothing if $dir is a symlink
command find "$dir" -maxdepth 1 -name "*.md" -type f

# ON-STANDARD — option A: shell glob (follows symlinks automatically)
for f in "$dir"/*.md; do [[ -f "$f" ]] || continue; ...; done

# ON-STANDARD — option B: find with -L (explicit dereference)
command find -L "$dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null
```

Shell globs resolve through symlinks without any flag. `find -L` explicitly dereferences the start path. Both are correct. Bare `find <symlink>` without `-L` is never correct.

**NOTE:** `command find -L` is correct syntax (`-L` comes before the path). Do not write `command find "$dir" -L`.

### Rule 4 — Deep recursive scan: add `maxdepth` even without a natural bound

When a scan has no structural depth limit, set `maxdepth 6` as a conservative default and document the choice.

```bash
# OFF-STANDARD — will crawl into node_modules, .git, nested repos
command find . -name "agent.yaml" -type f 2>/dev/null

# ON-STANDARD — bounded with documented rationale
# maxdepth 6: agent.yaml lives at most 5 levels into a profile tree
command find . -maxdepth 6 -name "agent.yaml" -type f 2>/dev/null
```

If the depth choice is non-obvious, add a comment explaining why that number was chosen.

### Rule 5 — `fd`/`fzf` optional; `rg` recommended-with-fallback (never assumed-present)

`fd` and `fzf` are not pre-installed on GitHub Actions `ubuntu-latest` or a clean macOS system. Scripts that call them unconditionally will fail in CI. `rg` is, as of ADR `2026-06-22-ripgrep-recommended-dependency`, a **recommended** DevOS dependency (offer-installed by `install.sh` via the OS package manager), but it is still **never assumed-present at runtime** — every `rg` call MUST have a `grep` fallback.

```bash
# OFF-STANDARD — breaks on clean CI environments
fd -e md . "$standards_dir"

# ON-STANDARD — optional enhancement with fallback
if command -v fd >/dev/null 2>&1; then
    fd -e md --max-depth 4 . "$standards_dir"
else
    command find "$standards_dir" -maxdepth 4 -name "*.md" -type f 2>/dev/null
fi

# ALSO ON-STANDARD — just use find, no conditional needed
command find "$standards_dir" -maxdepth 4 -name "*.md" -type f 2>/dev/null
```

**`rg` posture (changed by ADR 2026-06-22):**
- `rg` MAY be the preferred path for correctness-sensitive line scans, but the call MUST fall back to `command grep` when `rg` is absent. The canonical pattern lives in `scripts/lib/scan.sh` (`scan_lines` / `scan_count` / `scan_match_only` — rg-preferred, `command grep -E` fallback, `SCAN_FORCE_GREP=1` to force grep).
- `install.sh` runs an **offer-gate** (`check_ripgrep` in `dependency-checker.sh`): interactive sessions are offered an OS-package-manager install; non-interactive runs honor `DEVOS_INSTALL_RG` / `DEVOS_SKIP_RG`, else print a hint and continue. The install NEVER hard-fails on missing `rg`.
- A blanket `grep`→`rg` rewrite remains **PROHIBITED**: the tools are semantically non-equivalent (rg recurses + skips `.gitignore`/hidden by default; rg's Rust regex engine rejects backreferences/lookaround that `grep -E`/`grep -P` accept). Migrate only correctness-sensitive scans, through `scan.sh`.

**MUST NOT** add `fd` or `fzf` to any DevOS script as an unconditional dependency. **MUST NOT** call `rg` without a `grep` fallback. (Supersedes the prior "no `rg` dependency" stance attributed to BOX-45, which was about `just-bash`.)

### Rule 6 — Do NOT use `**` globstar without a Bash 4.0+ guard

`shopt -s globstar` (required for recursive `**` patterns) was added in Bash 4.0. macOS ships Bash 3.2. On Bash 3.2, `**` matches only one level and `shopt -s globstar` produces `invalid shell option name`.

```bash
# OFF-STANDARD — silently wrong on macOS Bash 3.2
shopt -s globstar
for f in "$dir"/**/*.md; do ...

# ON-STANDARD — option A: guard the globstar
if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    shopt -s globstar
    for f in "$dir"/**/*.md; do [[ -f "$f" ]] || continue; ...; done
else
    # fallback for Bash 3.2
    while IFS= read -r -d '' f; do ...; done < <(command find "$dir" -maxdepth 4 -name "*.md" -type f -print0 2>/dev/null)
fi

# ON-STANDARD — option B: skip globstar, use find (simpler, cross-version)
while IFS= read -r -d '' f; do
    ...
done < <(command find "$dir" -maxdepth 4 -name "*.md" -type f -print0 2>/dev/null)
```

DevOS minimum is Bash 4.0+, but the macOS system shell is 3.2. Prefer `find` over globstar for any script that may run on macOS without Homebrew Bash.

### Rule 7 — Sort output when feeding pipes or LLMs

Shell glob expansion order and `find` traversal order are both filesystem-dependent (inode order, not alphabetical). Sort explicitly when output ordering matters.

```bash
# OFF-STANDARD — non-deterministic ordering
command find "$dir" -maxdepth 3 -name "*.md" -type f 2>/dev/null

# ON-STANDARD — deterministic, diffable, LLM-safe
command find "$dir" -maxdepth 3 -name "*.md" -type f 2>/dev/null | sort

# ON-STANDARD — glob with sort
for f in $(printf '%s\n' "$dir"/*.md | sort); do
    [[ -f "$f" ]] || continue
    ...
done
```

**MUST** pipe through `| sort` when: feeding output to an LLM, comparing lists across runs, or when the downstream script assumes alphabetical order.

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `find "$dir" -name "*.md"` without `-maxdepth` | Unbounded recursion — scans entire subtree, becomes slow on large projects | `command find "$dir" -maxdepth 4 -name "*.md" -type f` |
| `find "$symlink_dir" -type f` without `-L` | Silently returns nothing when start path is a symlink | Shell glob `"$symlink_dir"/*.md` or `command find -L "$symlink_dir"` |
| `fd -e md .` as unconditional command | `fd` not in CI — breaks on clean GitHub Actions runner | `command find ... -maxdepth N -name "*.md"` or conditional `command -v fd` check |

---

## Deviation guidance

**MAY** use `fd` or `rg` as optional enhancements when: the script already checks `command -v fd` and falls back to `find`, AND the feature is documented as "faster when fd is available". MUST NOT make the fallback-less version the default path.

**MAY** omit `maxdepth` only for `find -maxdepth 1` equivalents replaced by shell globs, where glob naturally limits to one level. MUST NOT omit `maxdepth` on any `find` call that performs multi-level recursion.

---

## Profile inheritance notes

This is a `general` profile standard. All profiles that inherit from `general` (webapp, cli, astro-client-sites, cloudflare-workers, etc.) inherit this standard automatically. Child profiles do not need to restate these rules unless they override a specific rule (e.g., a profile that guarantees Bash 4.0+ via tooling may choose to allow globstar).

Extends: nothing (standalone `general` standard).

---

## Quick Reference

| Use case | Preferred tool |
|---|---|
| Single directory, one extension | Shell glob + `-f` guard |
| Single directory, multiple extensions | `command find "$dir" -maxdepth 1 \( -name "*.md" -o -name "*.yml" \)` |
| 2–4 levels deep, one condition | `command find "$dir" -maxdepth 4 -name "*.ext" -type f` |
| 2–4 levels deep, complex conditions | `command find "$dir" -maxdepth 4 \( -name "a" -o -name "b" \) -type f` |
| Symlinked start directory | Shell glob or `command find -L "$dir" -maxdepth N` |
| Broken symlink detection | `command find "$dir" -type l ! -exec test -e {} \; -print` |
| Output to LLM or diffable pipe | Any of above `\| sort` |
| Deep scan, unknown depth | `command find "$dir" -maxdepth 6 -name "*.ext" -type f` |
| Null-safe (filenames with spaces) | `command find "$dir" -maxdepth N -print0 \| while IFS= read -r -d '' f; do ...; done` |

---

## Compliance test

Review each `find` or glob invocation in the script being audited:

- [ ] Every `find` call uses `command find` (alias-bypass — per `shell-safety.md`)?
- [ ] Every recursive `find` call has an explicit `-maxdepth` argument?
- [ ] No `find "$symlink_path"` without `-L` on a path that could be a symlink?
- [ ] No `fd`, `rg`, or `fzf` called unconditionally (without `command -v` check and fallback)?
- [ ] No `**` globstar used without a `[[ "${BASH_VERSINFO[0]}" -ge 4 ]]` guard or Bash-version guarantee?
- [ ] All file lists fed to pipes, LLMs, or diff operations pass through `| sort`?
- [ ] All shell glob loops include `[[ -f "$f" ]] || continue` (or `[[ -d "$f" ]]` for dirs) to guard empty expansion?

If any check fails: apply the fix from the corresponding rule above. Document deviations with a comment stating the justification.

---

## References

- [POSIX.1-2017 `find` specification](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/find.html) — defines `-L` symlink-following semantics; authoritative on portability guarantees
- [GNU find manual — Symbolic Links](https://www.gnu.org/software/findutils/manual/html_mono/find.html#Symbolic-Links) — GNU-specific behavior of `-L`, `-H`, `-P` flags
- [Bash Reference Manual — Pattern Matching](https://www.gnu.org/software/bash/manual/bash.html#Pattern-Matching) — glob behavior and `globstar` availability (Bash 4.0+)
- DevOS BOX-45 — Decision record: do not add `fd`/`just` as DevOS dependencies; prefer native tools
- `profiles/general/standards/global/shell-safety.md` — alias bypass rule (`command find` over bare `find`)
