<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/testing/bats-test-writing.md and re-run profile-sync. -->
# BATS Test Writing Standards

## Overview

This standard covers how to write effective BATS (Bash Automated Testing System) tests for CLI
and shell library code in DevOS projects. It is the CLI-profile companion to
`profiles/default/standards/testing/test-writing.md`, which establishes the general philosophy.
Read that file first.

## Scope

This standard covers:
- Unit tests for bash library files in `scripts/lib/`
- Integration tests for scripts and CLI entry points
- BATS file structure, naming, setup/teardown patterns, mocking, and fixture layout

It does NOT cover:
- E2E usability dimensions (U1–U10) — see `cli-e2e-testing.md`
- CI/CD pipeline configuration — see `profiles/cli/ci/`
- Performance or load testing of shell scripts

## Philosophy

Test-at-completion applies to shell code exactly as it does to application code. Write BATS tests
once the library function's contract is stable — once you know what it accepts and what it returns.
Shell functions are small; their contracts are easy to specify after the fact. Premature tests for
bash code are especially costly because bash refactors change variable names and control flow
constantly during development.

**Behavior over implementation:** A good BATS test calls the public function and asserts on its
stdout, stderr, exit code, or side-effect files. It does not peek at internal variables or assert
on which sub-functions were called. A test that breaks when you rename a local variable is a
brittle test, not a useful test.

---

## Rules

### Rule 1: setup() and teardown() patterns

Every BATS test file that creates temporary files or modifies state MUST use `setup()` and
`teardown()` to create and clean up a per-test temp directory.

**Canonical pattern:**

```bash
setup() {
    TEST_TMPDIR="${BATS_TMPDIR}/mylib-$$"
    mkdir -p "$TEST_TMPDIR"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}
```

The `$$` suffix makes the directory unique per test run. Use the library name as the prefix so
failures are identifiable.

**OFF-STANDARD**

```bash
# Shared state — tests will interfere with each other
TMPDIR="/tmp/bats-test"
mkdir -p "$TMPDIR"
```

**ON-STANDARD**

```bash
setup() {
    TEST_TMPDIR="${BATS_TMPDIR}/cache-$$"
    mkdir -p "$TEST_TMPDIR"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}
```

---

### Rule 1b: Isolate runtime state — overriding `HOME` is NOT enough

Any test that sources a DevOS lib which can write **runtime state** — `learnings-capture.sh`,
anything calling `devos_runtime_path()`, telemetry emitters, checkpoint/snapshot/ledger hooks —
MUST isolate `XDG_STATE_HOME` in addition to `HOME`.

**Why.** `devos_runtime_path()` maps every live runtime path to
`${XDG_STATE_HOME:-$HOME/.local/state}/dev-os/projects/<project-id>/<relative>`. On most Linux
shells `XDG_STATE_HOME` is **exported**, so it *wins over `$HOME`*. A test that overrides only
`HOME` still writes to the developer's **real** `~/.local/state/dev-os` — silently polluting the
real learnings log / telemetry and making tests **order-dependent** (one test's write becomes the
first line the next test reads). This is a real failure that has shipped: a "writes correction
entry" test passed alone but failed in-suite because earlier tests' writes landed in the same
shared real file.

**ON-STANDARD — use the shared helper (preferred):**

```bash
setup() {
    export TEST_ROOT="${BATS_TMPDIR}/mylib-$$"
    mkdir -p "$TEST_ROOT"
    # Sets HOME + XDG_STATE_HOME (+ other XDG dirs) under TEST_ROOT. Call BEFORE
    # sourcing any lib that computes a runtime path at source time.
    source "${BATS_TEST_DIRNAME}/<rel>/helpers/isolate-state.bash"
    devos_isolate_runtime_state "$TEST_ROOT"

    source "${BATS_TEST_DIRNAME}/../../scripts/lib/learnings-capture.sh"
}

teardown() { rm -rf "$TEST_ROOT"; }
```

If you cannot use the helper, the minimum is `export XDG_STATE_HOME="$TEST_ROOT/state"` set
**before** sourcing the lib (paths are often computed at source time).

**OFF-STANDARD — writes escape to real user state:**

```bash
setup() {
    export HOME="${BATS_TMPDIR}/home-$$"   # XDG_STATE_HOME from the dev's shell still wins →
    source ".../scripts/lib/learnings-capture.sh"   # writes land in REAL ~/.local/state/dev-os
}
```

**Verify isolation** (no test may touch real state): run the suite with an outer
`XDG_STATE_HOME=/tmp/iso-$$` and assert nothing lands there, or diff `~/.local/state/dev-os`
before/after. A correctly-isolated suite leaves the real state dir untouched.

---

### Rule 1c: Parallel execution MUST isolate state per BATS file

Projects with a BATS corpus MUST invoke the canonical owner
`${DEVOS_DIR:-$HOME/.dev-os}/scripts/run-bats.sh --project-root <project>`.
Initialization and scaffolding classify any project-local copy as
non-authoritative and never create or overwrite it.

The parallel wave MUST give every `.bats` file its own **absolute** sandbox
under the system temp root with private:

- `HOME`
- `TMPDIR` and `BATS_TMPDIR`
- `XDG_STATE_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME`

It MUST unset inherited `DEVOS_DIR` and `DEVOS_STATE_ROOT`, and MUST remove
exported `devos_runtime_*` / `_devos_runtime_*` Bash functions so a sourced
library cannot bypass the private XDG roots. Preserve ordinary caller/toolchain
variables. A path relative to the repository is off-standard: any test that
changes cwd would reinterpret the sandbox and escape isolation.

Known real-install, hardcoded-path, and timing/benchmark contracts MUST run in
the runner's serial quarantine. Quarantine is not the fix for ordinary
runtime-state writers—private per-file state is. Add a quarantine entry only
after a file fails in the parallel wave and passes serially for a reason that
requires the caller environment.

`--isolated` adds source-tree isolation: each private HOME's `~/.dev-os` and
`DEVOS_DIR` MUST point to a throwaway git worktree, never the live checkout.
Normal full/scoped/failed runs MUST go through the canonical owner with an
explicit project root; raw `bats` is a declared degraded fallback only.

For two or more parallel files, the runner MUST detect GNU Parallel before
execution. Missing GNU Parallel MUST fail with exit 2 and actionable
Debian/Ubuntu + macOS install commands plus two explicit fallbacks:
`--jobs 1` (isolated sequential, preferred) and `--serial` (caller environment,
real-install compatibility only). It MUST NOT silently degrade to a shared-state
or unisolated run. CLI CI workflows MUST install GNU Parallel before invoking
the canonical DevOS runner.

The runner contract MUST have regression coverage proving:

1. two parallel files receive distinct absolute state roots;
2. inherited runtime path functions do not reach the child BATS process;
3. isolated mode points `DEVOS_DIR` and `~/.dev-os` at the throwaway worktree;
4. serial mode preserves the caller environment;
5. missing GNU Parallel fails with install/fallback guidance, while `--jobs 1` remains isolated and succeeds.

---

### Rule 2: Sourcing a library under test


To test a library, source it inside `setup()` or at the top of the test file. Use the canonical
`$BATS_TEST_DIRNAME` relative path — never a hardcoded absolute path.

**Canonical source pattern:**

```bash
setup() {
    TEST_TMPDIR="${BATS_TMPDIR}/mylib-$$"
    mkdir -p "$TEST_TMPDIR"

    # Source the library under test
    source "${BATS_TEST_DIRNAME}/../../scripts/lib/mylib.sh" 2>/dev/null || true
}
```

The `2>/dev/null || true` suppresses sourcing noise (e.g., logger setup messages) and prevents
the setup phase from aborting on informational stderr output.

**Stubbing dependency libraries:**

If the library under test sources other libraries (e.g., `logger.sh`, `cache.sh`), create minimal
stubs in `$TEST_TMPDIR` before sourcing the library:

```bash
setup() {
    TEST_TMPDIR="${BATS_TMPDIR}/mylib-$$"
    mkdir -p "$TEST_TMPDIR"

    # Stub logger dependency
    log_info()    { :; }
    log_warning() { :; }
    log_error()   { :; }
    export -f log_info log_warning log_error

    source "${BATS_TEST_DIRNAME}/../../scripts/lib/mylib.sh" 2>/dev/null || true
}
```

This avoids pulling in side effects from transitive dependencies and keeps test execution fast.

---

### Rule 3: run + status + output assertions

Always use the `run` helper to call functions or commands when you need to capture output or
test exit codes. Never call a function directly without `run` for these purposes.

**OFF-STANDARD**

```bash
@test "get_version returns a string" {
    result=$(get_version)          # Cannot test exit code; loses BATS output capture
    [ -n "$result" ]
}
```

**ON-STANDARD**

```bash
@test "get_version: returns a non-empty version string" {
    run get_version
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
```

**Standard assertion set:**

```bash
# Exit code
[ "$status" -eq 0 ]    # success
[ "$status" -ne 0 ]    # any failure
[ "$status" -eq 1 ]    # specific failure code

# Output contains substring
[[ "$output" == *"expected substring"* ]]

# Output equals exactly
[ "$output" = "exact string" ]

# Output is empty
[ -z "$output" ]

# Line-by-line (BATS $lines array)
[ "${lines[0]}" = "first line" ]
[ "${#lines[@]}" -eq 3 ]   # exactly 3 lines
```

---

### Rule 4: Fixture patterns

Create fixtures using heredocs inside `setup()` or inline in the test body. Always place fixture
files inside `$TEST_TMPDIR`.

**Inline fixture (preferred for single-test fixtures):**

```bash
@test "parse_config: reads profile key from valid config file" {
    cat > "$TEST_TMPDIR/config.yml" <<'EOF'
profile: cli
version: 1.0.0
EOF

    run parse_config "$TEST_TMPDIR/config.yml" "profile"
    [ "$status" -eq 0 ]
    [ "$output" = "cli" ]
}
```

**setup() fixture (for fixtures shared across multiple tests):**

```bash
setup() {
    TEST_TMPDIR="${BATS_TMPDIR}/parser-$$"
    mkdir -p "$TEST_TMPDIR"
    mkdir -p "$TEST_TMPDIR/specs/my-feature"

    cat > "$TEST_TMPDIR/specs/my-feature/tasks.md" <<'EOF'
# Task Breakdown: My Feature

- [ ] 1.1 Do the thing
- [x] 1.2 Done thing
EOF
    source "${BATS_TEST_DIRNAME}/../../scripts/lib/myparser.sh" 2>/dev/null || true
}
```

**Do NOT use hardcoded paths outside `$TEST_TMPDIR`:**

```bash
# OFF-STANDARD — pollutes the real filesystem
cat > /tmp/test-fixture.yml <<'EOF'
profile: cli
EOF
```

---

### Rule 5: When to source vs when to mock

**Source the real library** when you are testing that library's behavior. This is the primary
purpose of a BATS test.

**Mock external commands** when the library under test calls commands that have unacceptable
side effects: `git`, `curl`, `ssh`, `brew`, package managers, or anything that modifies global
state or makes network calls.

**How to mock an external command:** Create a shim script in `$TEST_TMPDIR` and prepend to `$PATH`.

```bash
setup() {
    TEST_TMPDIR="${BATS_TMPDIR}/git-workflow-$$"
    mkdir -p "$TEST_TMPDIR/bin"

    # Stub git — returns exit 0 and controlled output
    cat > "$TEST_TMPDIR/bin/git" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    status)  echo "nothing to commit, working tree clean"; exit 0 ;;
    log)     echo "abc1234 feat: initial commit"; exit 0 ;;
    *)       exit 0 ;;
esac
STUB
    chmod +x "$TEST_TMPDIR/bin/git"
    export PATH="$TEST_TMPDIR/bin:$PATH"

    source "${BATS_TEST_DIRNAME}/../../scripts/lib/git-workflow.sh" 2>/dev/null || true
}
```

**Do NOT mock bash built-ins** (`echo`, `read`, `printf`, etc.) — they have no side effects.
**Do NOT mock functions in the library under test** — that defeats the purpose.

---

### Rule 6: Test naming

**File naming:**

| Scenario | File name |
|----------|-----------|
| One-to-one library coverage | `tests/bats/lib/<libname>.bats` |
| Large library split by subsystem | `tests/bats/lib/<libname>-<focus>.bats` |

Examples:
- `cache.bats` — covers the full `cache.sh` library
- `command-router.bats` — covers core routing in `command-router.sh`
- `command-router-start.bats` — covers start-specific behavior only

**Test name pattern:**

```
@test "<function_name>: [verb] [outcome] when [condition]"
```

Examples:
- `@test "cache_get: returns empty string when key is not set"`
- `@test "triage_scan_specs: emits high finding when tasks.md has open items"`
- `@test "get_inheritance_chain: returns root when profile has no parent"`

The function name prefix makes it easy to grep tests for a specific function. The `[verb] [outcome]
when [condition]` body makes failures self-explanatory.

---

### Rule 7: File split criteria

Split a test file into multiple files when:

**(a)** The suite exceeds approximately **300 lines**, OR
**(b)** The library has **two functionally distinct subsystems** that are independently testable
(e.g., `command-router.sh` contains both core routing logic and start-command scaffolding —
split into `command-router.bats` and `command-router-start.bats`).

**Do NOT split** just because there are many tests for one function. A 60-test file testing
every branch of `parse_version()` is fine as one file.

After splitting, both files MUST be added to `BATS_SUITES` in `Makefile` (see Rule 8).

---

### Rule 8: BATS_SUITES wiring

Every new `.bats` file MUST be registered in `BATS_SUITES` in `Makefile`. Orphaned test files
that are not in `BATS_SUITES` are never run by `make test` or CI.

**Makefile BATS_SUITES format (illustrative):**

```makefile
BATS_SUITES = \
    tests/bats/lib/cache.bats \
    tests/bats/lib/logger.bats \
    tests/bats/lib/mylib.bats   # <-- add new file here
```

**Verification command:**

```bash
# Confirm your new file is wired
grep "mylib.bats" Makefile
```

If the grep returns nothing, the test file will never run in CI.

`triage` reports `.bats` files missing from `BATS_SUITES` as a **Medium** finding.
Fix immediately — orphaned tests provide zero coverage signal.

---

### Rule 9: Test output — always use TAP format in Makefile

The `make test` target MUST use `bats --tap` (Test Anything Protocol), not the default verbose
formatter. TAP produces one line per test (`ok N` / `not ok N`), making output parseable by CI
tools and keeping temp file sizes manageable during runs.

**Standard Makefile test target:**
```makefile
test:
	@echo "Running comprehensive BATS suite..."
	@PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH" bats --tap $(BATS_SUITES)
```

**Key requirements:**
- `PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"` — bats uses `#!/usr/bin/env bash` which resolves to
  macOS bash 3.2 by default. Homebrew bash 5+ must be first in PATH so DevOS libs using associative
  arrays (`declare -gA`) parse correctly.
- `--tap` — TAP output format. One line per test regardless of result. Skips and failures are
  single-line entries. No per-line skip explanations.
- `@` prefix — suppress the command echo from make, keep output clean.

**Why not default bats output:**
Default bats output includes per-test explanations of skips and diagnostics. With 2800+ tests,
verbose output easily reaches 10–50MB per run. On systems with constrained `/tmp` (e.g., macOS
sandboxed temp), this causes ENOSPC failures that kill test runs.

**Verifying TAP output:**
```bash
make test 2>&1 | head -5   # Should be "1..N" (plan line) then "ok 1 ..." or "not ok 1 ..."
```

---

### Rule 10: Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Direct function call without `run` to check output | `$output` is not captured; `$status` is not set | Always use `run <function> [args]` |
| Hardcoded paths outside `$TEST_TMPDIR` (e.g., `/tmp/test.yml`) | Leftover files from failed tests pollute future runs; races on parallel execution | Use `$TEST_TMPDIR` exclusively |
| Shared mutable state between tests (top-level variables set once in the file) | Tests pass or fail depending on execution order; intermittent CI failures | Use `setup()` to initialize state before each test |
| `ls` or `find` inside test assertions | Output format varies by OS and flags; not portable | Use glob checks: `[ -f "$TEST_TMPDIR/file" ]` |
| Relying on test execution order | BATS does not guarantee order; shuffled runs in CI expose the dependency | Each test must be self-contained — call `setup()` is already doing this for fixtures |
| Sourcing the library at file scope (outside `setup()`) | Any library that calls functions on source will run with no test fixtures in place | Source inside `setup()` after fixtures are created |
| No `teardown()` | Temp directories accumulate; disk pressure, stale fixtures contaminate subsequent tests | Always pair `mkdir` in `setup()` with `rm -rf` in `teardown()` |
| Overriding only `HOME` when the lib writes runtime state | `XDG_STATE_HOME` from the dev's shell wins → writes land in the REAL `~/.local/state/dev-os`, polluting user state and making tests order-dependent | Isolate `XDG_STATE_HOME` too — use `devos_isolate_runtime_state` (Rule 1b) |
| Raw parallel BATS with a shared HOME/XDG/TMP | Writer races rotate between unrelated failures and can mutate real user/project state | Use the canonical DevOS runner with `--project-root`; private state per file, serial quarantine only for real-install/timing contracts (Rule 1c) |

---

## Compliance Checklist

- [ ] Every test file has a `setup()` that creates `TEST_TMPDIR="${BATS_TMPDIR}/<name>-$$"` and a `teardown()` that removes it
- [ ] Library under test is sourced via `source "${BATS_TEST_DIRNAME}/../../scripts/lib/<name>.sh"`
- [ ] All output-checking and exit-code-checking tests use `run <command>`; no bare function calls for these purposes
- [ ] All fixture files are written into `$TEST_TMPDIR`, not hardcoded paths
- [ ] External commands with side effects (git, curl, etc.) are stubbed via shim scripts on `$PATH`
- [ ] Test names follow `@test "<function_name>: [verb] [outcome] when [condition]"` pattern
- [ ] New `.bats` files are registered in `BATS_SUITES` in `Makefile`
- [ ] File splitting follows the 300-line or two-subsystem criteria — not "too many tests"
- [ ] No shared mutable state between tests; `setup()` initializes all state per test
- [ ] Tests that source a runtime-state-writing lib isolate `XDG_STATE_HOME` (not just `HOME`) — verified by leaving the real `~/.local/state/dev-os` untouched (Rule 1b)
- [ ] Parallel BATS execution uses the canonical DevOS runner with explicit project root and absolute per-file HOME/TMP/XDG roots; raw shared-state `bats --jobs` is absent (Rule 1c)

## References

- [BATS documentation](https://bats-core.readthedocs.io/) — the authoritative reference for `run`,
  `$status`, `$output`, `$lines`, `setup()`, `teardown()`, helper libraries
- `profiles/default/standards/testing/test-writing.md` — general test philosophy (test-at-completion,
  behavior over implementation, test deletion lifecycle)
- `profiles/cli/standards/testing/cli-e2e-testing.md` — E2E usability dimensions for CLI tools
- `Makefile` — `BATS_SUITES` registration; `make test` entry point
- `tests/bats/` — all existing BATS test files; read before adding new ones to understand conventions
