<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/awk-portability.md and re-run profile-sync. -->
# Cross-Platform AWK Standards

## Overview

AWK scripts in DevOS must run on both GNU awk (Linux, Git Bash) and BSD awk (macOS). The two implementations differ in how they handle newlines inside `-v` variable values, `ENVIRON` array support, and regex literal placement. Scripts that work on Linux fail silently or error on macOS. This standard defines portable AWK patterns for all DevOS scripts and skill invocation blocks.

## Scope

This standard covers AWK usage in DevOS shell scripts (`scripts/lib/`), skill invocation blocks, and BATS test helpers. It does NOT coverAWK used in one-liner Bash tool calls outside of scripted contexts (those must be evaluated case-by-case).

## Principles

1. **Avoid `-v` for multi-line values:** BSD awk (macOS) treats newlines in `-v` variable values as literal newlines inside the script program; GNU awk allows them as string content. Use `ENVIRON` or temp files instead.
2. **Test on both implementations:** Every AWK pattern must be verified on macOS (BSD awk) and Linux (GNU awk) before shipping.
3. **Explicit shebang over implicit inference:** Never assume `awk` resolves to GNU awk. Use `/usr/bin/awk` only when the script is BSD-compatible; otherwise document the GNU requirement.

## Rules

### Rule 1 — Multi-line replacement strings via ENVIRON (not `-v`)

BSD awk does not reliably pass multi-line strings via `-v`. Use the `ENVIRON` array instead.

```bash
# OFF-STANDARD (fails on macOS when content has newlines)
awk -v repl="$content" '
    $0 == start { print repl; skip=1; next }
    $0 == stop  { skip=0; next }
    !skip       { print }
' "$file" > "$tmp"

# ON-STANDARD (portable)
content_awk="${content}" awk '
    BEGIN { repl = ENVIRON["content_awk"] }
    $0 == start { print repl; skip=1; next }
    $0 == stop  { skip=0; next }
    !skip       { print }
' "$file" > "$tmp"
```

**Why it fails on BSD:** The newline in `repl="$content"` is parsed as a literal newline in the awk script source, not as a character in the string value. GNU awk handles this; BSD awk raises "newline in string".

### Rule 2 — Awk version detection before conditional use

```bash
# Detect awk flavor before using GNU-specific features
awk_version_detect() {
    local version_output
    version_output=$(awk --version 2>&1 | head -1)
    if [[ "$version_output" =~ "GNU Awk" ]]; then
        echo "gawk"
    elif [[ "$version_output" =~ "BSD awk" ]] || [[ "$version_output" =~ "202" ]]; then
        echo "bsd"
    else
        echo "unknown"
    fi
}
```

Use `gawk`-specific features (e.g., `length()` overloads, `@include`, or `FPAT`) only after confirming GNU awk. Fall back to POSIX for unknown flavors.

### Rule 3 — Shebang line for AWK scripts

```bash
# OFF-STANDARD: relies on awk in PATH, ambiguous version
#!/bin/sh
awk '{print}' file

# ON-STANDARD: explicit path with version check
#!/usr/bin/env awk
# OR (if GNU awk is required)
#!/usr/bin/env gawk
```

### Rule 4 — No regex literals as AWK pattern operands on BSD

BSD awk handles some regex literals differently from GNU awk in mixed expressions. Use `~` operator explicitly.

```bash
# OFF-STANDARD (may misbehave on BSD in some contexts)
awk '/^start/,/^end/' file

# ON-STANDARD (explicit, portable)
awk '$0 ~ /^start}/{flag=1; next} /^end/{flag=0} flag' file
```

### Rule 5 — No backslash in `-v` values on BSD

BSD awk interprets backslashes in `-v` values as escape sequences differently from GNU awk. Avoid passing strings with backslashes via `-v`.

```bash
# OFF-STANDARD (breaks when content contains \n, \t, literal \)
awk -v s="$string" 'BEGIN { gsub(/\\n/, "\n", s); print s }'

# ON-STANDARD (pass via ENVIRON)
string_awk="${string}" awk 'BEGIN { s = ENVIRON["string_awk"]; print s }'
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Multi-line `-v repl=` on macOS | BSD parses newline as script source, not string content | `ENVIRON["var"]` |
| `length()` without parens on GNU awk | GNU extends length() to accept regex, BSD does not | `length($0)` always |
| `/pattern/` as expression operand | BSD handles differently in some contexts | `$0 ~ /pattern/` |
| Backslash in `-v` value | BSD interprets as escape, GNU sometimes does | `ENVIRON` or `sprintf` |

## Deviation guidance

**MAY** use `gawk`-specific features when the script runs only in Linux-native contexts (CI on Linux runners, deploy to Linux-only containers). **MUST** document the GNU-only requirement in a comment above the awk block and guard with a version check.

**MAY** omit the `ENVIRON` workaround when the passed variable is guaranteed single-line (e.g., a simple project name or date string with no special characters).

## Profile inheritance notes

This standard lives in the `general` profile. All child profiles inherit it. The `cli` profile's scripts directory is the primary target for compliance checking.

## Compliance test

- [ ] No multi-line string is passed via `awk -v` in any script under `scripts/lib/`?
- [ ] Are all awk scripts run through a version detection function before GNU-specific features are used?
- [ ] Do all new awk additions to `scripts/lib/` include a `gawk` vs `bsd` code path or a POSIX fallback?
- [ ] Does no awk invocation in skill invocation blocks pass a variable containing newlines via `-v`?
- [ ] Have all awk blocks been tested on macOS (BSD awk) before merge?

If any check fails: replace the `-v` pattern with `ENVIRON`, then test on both `awk --version` outputs.

## References

- [GNU AWK Manual — GAWK](https://www.gnu.org/software/gawk/manual/gawk.html) — `-v` behavior and ENVIRON array
- [FreeBSD awk man page](https://www.freebsd.org/cgi/man.cgi?awk(1)) — BSD awk limitations
- [POSIX awk specification](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html) — baseline portability contract
- [ShellCheck SC1000](https://www.shellcheck.net/wiki/SC1000) — undefined variable warning (use `-v` correctly or use ENVIRON)
