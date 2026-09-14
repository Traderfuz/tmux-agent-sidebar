<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/cross-platform-compat.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/cross-platform-compat.md and re-run profile-sync. -->
# Cross-Platform Compatibility Guide
## macOS and Linux CLI Standards

### Overview
This document standardizes CLI command usage and shell invocation for tools used across both macOS (BSD-based) and Linux (GNU-based) systems. Adherence to these standards ensures consistent behavior and prevents platform-specific failures.

**Sibling standards:**
- [`shell-safety.md`](./shell-safety.md) — canonical alias-bypass rules (use `command <name>` or `/usr/bin/<name>` for `rm`, `cp`, `mv`, `grep`, `find`, `ls`, etc.)
- [`bash-sourced-script-safety.md`](./bash-sourced-script-safety.md) — sourced-library invocation discipline

Read all three together. This standard handles macOS-vs-Linux command differences; the others cover alias bypass and sourcing hygiene.

---

## Bash Version Policy (DevOS-specific)

**DevOS requires Bash 4.0+.** Multiple core libraries (`scripts/lib/logger.sh`, command-router associative arrays, etc.) hard-fail under Bash 3.2.

macOS ships Bash 3.2.57 at `/bin/bash` and pins it there for GPL-3 licensing reasons. The system bash never updates. The canonical fix is **install Homebrew bash and re-exec under it**:

- **Apple Silicon:** `/opt/homebrew/bin/bash`
- **Intel Mac:** `/usr/local/bin/bash`

Linux ships Bash 4+ at `/bin/bash` so re-exec is a no-op there.

**Do NOT** "avoid Bash 4+ features for macOS compatibility." That guidance is obsolete in DevOS — associative arrays, `mapfile`, `nameref`, `declare -A` are all required and used widely. Make the script run under Bash 4+ via the reexec pattern below instead.

---

## The Auto-Reexec Pattern (canonical solution)

When a script (or git hook) needs Bash 4+, embed this block at the top, immediately after the shebang:

```bash
#!/usr/bin/env bash
# Re-exec under Homebrew Bash 4+ on macOS where /usr/bin/env bash resolves
# to /bin/bash (3.2). No-op on Linux (where /bin/bash is already 4+).
if [[ "${BASH_VERSINFO[0]}" -lt 4 && -z "${DEVOS_BASH_REEXEC:-}" ]]; then
    for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$candidate" ]]; then
            candidate_major="$("$candidate" -lc 'printf "%s" "${BASH_VERSINFO[0]}"' 2>/dev/null || printf "0")"
            if [[ "$candidate_major" =~ ^[0-9]+$ ]] && [[ "$candidate_major" -ge 4 ]]; then
                exec env DEVOS_BASH_REEXEC=1 "$candidate" "$0" "$@"
            fi
        fi
    done
fi

# Hard guard if no candidate found
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "ERROR: requires Bash 4.0+ (found ${BASH_VERSION}). Run: brew install bash" >&2
    exit 1
fi

set -euo pipefail
```

**Reference implementations:**
- `scripts/install.sh:9-28` — original
- `profiles/default/hooks/pre-commit.sh:11-21` — git hook adaptation
- `scripts/hooks/pre-push.sh:16-26` — git hook adaptation

**When invoking sub-scripts that also need Bash 4+:** use `"$BASH"` (the interpreter running the parent), not bare `bash`. This propagates the upgraded interpreter regardless of PATH ordering at invocation time:

```bash
# ❌ Wrong — sub-script may inherit /bin/bash 3.2 via PATH
bash "$PROJECT_ROOT/scripts/lib/something.sh"

# ✅ Correct — sub-script inherits the same Bash 4+ as parent
"$BASH" "$PROJECT_ROOT/scripts/lib/something.sh"
```

---

## Shebang Policy

Use `#!/usr/bin/env bash` as the default shebang. It's portable across distros. **Combined with the auto-reexec pattern above**, it correctly resolves to Bash 4+ on macOS via Homebrew.

`#!/bin/bash` hardcodes a 3.2 interpreter on macOS — avoid.

`#!/opt/homebrew/bin/bash` works on Apple Silicon but breaks on Intel Mac and Linux — avoid as primary shebang. Acceptable as a re-exec target inside the script body (as shown above).

---

## Homebrew Prefix Detection

When code needs to find Homebrew tools by absolute path:

```bash
detect_brew_prefix() {
    if [[ -x /opt/homebrew/bin/brew ]]; then
        echo "/opt/homebrew"   # Apple Silicon
    elif [[ -x /usr/local/bin/brew ]]; then
        echo "/usr/local"      # Intel Mac
    else
        echo ""                # Not installed
    fi
}

BREW_PREFIX="$(detect_brew_prefix)"
```

Or use `brew --prefix` if `brew` is already on PATH. The literal-path probe above is safer in early-boot contexts (git hooks) where PATH may be minimal.

---

## Core Principles

- **Avoid GNU-only extensions** when a POSIX alternative exists
- **Use conditional logic** for genuinely incompatible operations
- **Document platform assumptions** in code comments
- **Prioritize readability** over brevity — clarity reduces porting errors
- **Test on both platforms** before committing cross-platform code (see Compliance below)
- **Use shellcheck** for static analysis and portability linting
- **Bypass aliases** with `command <name>` (preferred) or `/usr/bin/<name>` for `rm`, `cp`, `mv`, `grep`, `find`, `ls` — see `shell-safety.md`
- **Probe command capabilities, not just command presence** — Homebrew can provide one GNU tool while adjacent commands remain BSD/system variants

---

## Critical Command Differences & Standardized Approaches

### 1. sed (Stream Editor)

**Problem**: macOS uses BSD sed; Linux uses GNU sed. Option syntax differs significantly.

#### ❌ Non-Standard
```bash
# Linux-only
sed -i 's/old/new/g' file.txt

# macOS-only
sed -i '' 's/old/new/g' file.txt
```

#### ✅ Cross-Platform Standard
```bash
# POSIX-compliant approach (no in-place backup)
sed 's/old/new/g' file.txt > file.txt.tmp && mv file.txt.tmp file.txt

# Or, for in-place editing with backup on both platforms:
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/old/new/g' file.txt
else
    sed -i 's/old/new/g' file.txt
fi
```

#### Recommended Pattern
```bash
sed_inplace() {
    local file=$1
    local expr=$2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$expr" "$file"
    else
        sed -i "$expr" "$file"
    fi
}
```

---

### 2. grep

**Problem**: macOS uses BSD grep; Linux typically uses GNU grep. Flag support differs.

**Additional gotcha (DevOS-specific):** under zsh, `grep` may be aliased (e.g., to `rg` ripgrep, or to `grep --color=auto` which corrupts pipe parsing). When inline-invoking grep from Bash that may run under zsh aliases, prefix with `command` (preferred — bypasses aliases and functions, portable across distros) or use the absolute path `/usr/bin/grep`. See `shell-safety.md`.

#### ❌ Non-Standard
```bash
# GNU only — fails on macOS
grep -P '(?<=prefix).*' file.txt
```

#### ✅ Cross-Platform Standard
```bash
# Use extended regex with -E (POSIX)
grep -E 'pattern' file.txt

# Inline Bash call where zsh aliases may interfere (DevOS pattern):
command grep -E 'pattern' file.txt           # preferred — portable, bypasses aliases/functions
# Fallback when extra defense needed (e.g., binary may be a wrapper on PATH):
/usr/bin/grep -E 'pattern' file.txt          # macOS path; Linux distros vary

# For Perl-like patterns, use ggrep on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    "$(detect_brew_prefix)/bin/ggrep" -P 'pattern' file.txt
else
    grep -P 'pattern' file.txt
fi
```

---

### 3. find

**Problem**: Option ordering, syntax, and flag availability differ between BSD and GNU find.

#### ✅ Cross-Platform Standard
```bash
# Always specify path before options
find . -type f -name "*.txt"

# Portable file-execution pattern
find . -type f -name "*.txt" -print0 | xargs -0 grep "pattern"

# Under zsh-alias risk (e.g., `find` shadowed by `fd`), bypass with command or absolute path
command find . -type f -name "*.txt"          # preferred
/usr/bin/find . -type f -name "*.txt"         # fallback
```

---

### 4. date

**Problem**: Date manipulation syntax is completely different between GNU and BSD date.

#### ✅ Cross-Platform Standard
```bash
date_add_minutes() {
    local minutes=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        date -v +${minutes}M
    else
        date -d "+${minutes} minutes"
    fi
}
```

Or install GNU coreutils on macOS (`brew install coreutils`) and use `gdate` everywhere.

---

### 4.1. Mixed GNU/BSD Toolchains

**Problem:** macOS machines often have Homebrew GNU tools installed selectively. Detecting `timeout` or `gtimeout` does **not** mean `tail`, `sed`, `find`, or other companion commands are GNU-compatible. A script that checks only `command -v timeout` and then runs `tail --pid` can fail on macOS because `/usr/bin/tail` is BSD and lacks `--pid`.

#### ❌ Non-Standard
```bash
# Fails on macOS when GNU timeout exists but tail is BSD.
if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" tail --pid="$pid" -f /dev/null
fi
```

#### ✅ Cross-Platform Standard
Use a portable shell watchdog, or probe the exact command feature before using it.

```bash
# Portable watchdog: no GNU tail dependency.
timeout_marker="$(mktemp -t devos-timeout.XXXXXX)"
command rm -f "$timeout_marker" 2>/dev/null || true

(
    sleep "$seconds"
    if kill -0 "$pid" 2>/dev/null; then
        : > "$timeout_marker"
        kill "$pid" 2>/dev/null || true
    fi
) &
watchdog_pid=$!

if wait "$pid" 2>/dev/null; then
    rc=0
else
    rc=$?
fi
kill "$watchdog_pid" 2>/dev/null || true
wait "$watchdog_pid" 2>/dev/null || true

if [[ -f "$timeout_marker" ]]; then
    rc=124
fi
command rm -f "$timeout_marker" 2>/dev/null || true
```

When a GNU-specific option is truly needed, probe that exact option:

```bash
if tail --help 2>&1 | command grep -q -- '--pid'; then
    timeout "$seconds" tail --pid="$pid" -f /dev/null
else
    # portable fallback
fi
```

**MUST NOT** infer that one GNU command on PATH implies all related commands are GNU-compatible.

---

### 5. xargs

**Problem**: Flag support differs; macOS doesn't recognize some GNU options like `--no-run-if-empty`.

#### ✅ Cross-Platform Standard
```bash
# -0 with find -print0 works on both
find . -type f -name "*.tmp" -print0 | xargs -0 rm

# Use -r short form (POSIX, works on both)
find . -type f -name "*.log" -print0 | xargs -0 -r rm
```

---

### 6. cp / mv / rm

**Problem (1)**: Recursive flag syntax differs (`cp -R` vs `cp -r`).

**Problem (2, DevOS-specific)**: zsh aliases (`cp -iv`, `rm -iv`, `mv -iv`) inject prompts that hang non-interactive scripts indefinitely. Inline Bash calls under zsh-loaded environments **MUST** bypass aliases.

#### ✅ Cross-Platform Standard
```bash
# Both -R and -r work; lowercase -r is POSIX
cp -r src/ dest/

# Under zsh-alias risk, prefix with `command` (preferred) or use absolute path
command cp -r src/ dest/                    # preferred — portable, bypasses aliases
command mv old new
command rm -f file.txt

# Absolute-path fallback (defensive when binary on PATH may be a wrapper)
/usr/bin/cp -r src/ dest/                   # macOS path; Linux distros vary

# For complex recursive copy, prefer rsync
rsync -av --delete source/ destination/
```

**Why `command` is preferred:** it's a POSIX shell builtin that bypasses aliases and shell functions while still finding the binary via PATH. Works regardless of where the binary lives (macOS `/usr/bin/`, Linux `/bin/` or `/usr/bin/` depending on distro). The absolute path is a fallback for cases where you need to bypass even PATH-based wrappers.

**Reference:** `shell-safety.md:25` lists `command` first, absolute path second. Commit `5b0398d2` used absolute paths in `install.sh` because the script was already operating with a deliberately-narrow toolset; `command` would have worked equivalently there.

---

## OS Detection Pattern

```bash
detect_os() {
    case "$(uname)" in
        Darwin)  echo "macos" ;;
        Linux)   echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

OS="$(detect_os)"
```

The `$OSTYPE` variable also works (`"$OSTYPE" == "darwin"*` for macOS), but `uname` is more portable across older shells.

---

## Recommended Defaults

### Cross-Platform Safe
- ✅ `printf` over `echo` (consistent escaping)
- ✅ `$( ... )` over backticks (nests properly)
- ✅ `[[ ... ]]` over `[ ... ]` (safer, fewer quoting issues)
- ✅ `find ... -print0 | xargs -0` for filenames with spaces
- ✅ `rsync` for recursive file operations instead of `cp -r`
- ✅ `#!/usr/bin/env bash` shebang **+ auto-reexec block** for Bash 4+ scripts
- ✅ `"$BASH"` (not bare `bash`) for invoking sub-scripts that need Bash 4+
- ✅ `command grep`, `command cp`, `command rm` (preferred) — bypasses aliases/functions, portable
- ✅ `/usr/bin/grep`, `/usr/bin/cp` (fallback) — when extra defense needed against PATH-based wrappers

### Avoid
- ❌ `#!/bin/bash` — pins to macOS Bash 3.2
- ❌ `#!/opt/homebrew/bin/bash` as primary shebang — breaks on Intel Mac and Linux
- ❌ "Avoid Bash 4+ features" — obsolete advice; DevOS requires Bash 4+
- ❌ Perl regex in `grep` without `ggrep` on macOS
- ❌ GNU-only `sed` features without wrapper functions
- ❌ Relative date math with `date -d` on macOS without wrapper
- ❌ Backticks for command substitution
- ❌ Relying on GNU coreutils being available without `brew install`

---

## Compliance & Enforcement

The "test on both platforms" principle is only load-bearing if it's enforced. Aspirational checklists rot. DevOS uses these enforcement points:

| Gate | Mechanism | Catches |
|------|-----------|---------|
| Pre-commit hook reexec | `profiles/default/hooks/pre-commit.sh:11-21` | Hooks themselves running under Bash 4+ |
| `validate-skill.sh` SK11 | `.claude/skills/bx-skill-creator/scripts/validate-skill.sh:260+` | Hardcoded absolute paths in skill docs |
| `validate-skill.sh` SK12 | Same file | Bare `source scripts/lib/*.sh` calls |
| BATS tests on macOS + Linux | `tests/bats/` (CI) | Actual command behavior across platforms |
| ShellCheck | Manual / CI | Generic portability lint |
| `standards-consistency.sh` | `scripts/lib/standards-consistency.sh`; runs in `pre-commit-doc-validation.sh` when standards staged | Asymmetric sibling cross-references and command-guidance drift between sibling standards |

**When adding a new portable wrapper or pattern**, also add a BATS test that exercises it under both `OSTYPE=darwin` and `OSTYPE=linux-gnu` simulation. Pattern without test = pattern that will rot.

**When the project's actual posture diverges from this standard** (as the Bash version policy did before the 2026-04-25 refresh), file a `G-CPC-XX` gap and update the standard. The Dalio-layer rule: standards must be designed to refresh themselves when reality moves.

---

## Quick Reference Table

| Operation | macOS (BSD) | Linux (GNU) | Recommended |
|-----------|------------|-----------|-------------|
| In-place sed | `sed -i ''` | `sed -i` | Use `sed_inplace()` wrapper |
| Perl grep | Not available | `grep -P` | Use `ggrep` on macOS or avoid |
| Find exclusion | `-not -path` | `-not -path` | Both same |
| Date offset | `date -v +10M` | `date -d '+10 min'` | Use `date_add_minutes()` wrapper |
| No-input xargs | `xargs -r` | `xargs -r` | `-r` (POSIX, works on both) |
| Recursive copy | `cp -R` | `cp -r` | `cp -r` (POSIX) or `rsync -a` |
| Extended regex | `grep -E` | `grep -E` | Both same |
| Bash 4+ shebang | `/opt/homebrew/bin/bash` | `/bin/bash` | `#!/usr/bin/env bash` + reexec block |
| Inline utility under zsh | aliases mangle | usually fine | `command cp`, `command grep` (preferred); `/usr/bin/cp` (fallback) |

---

## Homebrew Installation for GNU Tools (macOS)

When native POSIX equivalents are insufficient, install GNU tools on macOS:

```bash
brew install bash coreutils findutils gnu-sed grep

# Usage examples:
gdate -d '+1 day'           # Instead of date -v +1d
gsed -i 's/old/new/' file   # Instead of sed -i ''
ggrep -P 'regex' file       # For Perl regex on macOS
```

`brew install bash` is the prerequisite for the auto-reexec pattern. The DevOS install script (`scripts/install.sh`) detects and re-execs but does not currently auto-install — see [follow-up note in install.sh:7-28].

---

## Summary

1. **DevOS requires Bash 4+.** Use the auto-reexec pattern, not "avoid Bash 4+ features."
2. **Detect the OS** when behavior must differ; prefer POSIX-compliant approaches when not.
3. **Bypass aliases** with `command <name>` (preferred) or `/usr/bin/<name>` (fallback) for `rm`, `cp`, `mv`, `grep`, `find`, `ls` — see `shell-safety.md`.
4. **Use `"$BASH"`** for sub-script invocation when the parent re-exec'd to a specific interpreter.
5. **Test on both platforms** via BATS — aspirational checklists rot, enforced gates don't.
6. **Refresh this standard** when the project's actual posture diverges from documented guidance.
