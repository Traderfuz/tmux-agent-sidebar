<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/extensibility.md and re-run profile-sync. -->
# Extensibility Standards

**Sibling standards:**
- [`modular-architecture.md`](./modular-architecture.md) — where code lives, feature boundaries, dependency direction
- [`modular-integration.md`](./modular-integration.md) — how modules connect at runtime, plugin registration protocol
- [`provider-agnostic-architecture.md`](./provider-agnostic-architecture.md) — capability-first provider and service portability
- [`modular-provider.md`](../../../default/standards/global/modular-provider.md) — provider ports, adapters, routers, and tests

## Overview

In fast-moving domains, the dominant cost is not writing new code — it is the blast radius that change creates across existing code. A provider swap that requires editing three files. A new runtime that needs a case arm added to a switch statement in the router. A new skill format that silently breaks two callers. Each of these is an extensibility failure: the system was not designed to absorb the change.

This standard governs how DevOS primitives (providers, runtimes, commands, adapters, skills) are designed at the boundary: stable interfaces that consumers depend on, extension registries that grow without modifying existing code, and change contracts that make breaking changes visible rather than silent.

## Scope

This standard covers the design of swappable primitives: interface contracts, extension registry patterns, change-contract rules, and independent testability. It does NOT cover runtime plugin registration protocol (covered by `modular-integration.md`), where modules live on disk (covered by `modular-architecture.md`), or CLI output contract stability across provider swaps (covered by `modular-provider.md`).

---

## Named Frameworks

### Open/Closed Principle (OCP)
Robert C. Martin, _Agile Software Development_ (2002). A module should be open for extension and closed for modification. Adding a new variant — provider, runtime, adapter — should require writing one new file, not editing any existing file.
**Applied to:** Rule 1 (interface contract) and Rule 2 (extension without modification).

### Plugin Registry Pattern
Convention used across extensible systems (VS Code extensions, Babel plugins, Rollup plugins). Extensible surfaces maintain a registry of named implementations keyed by a string identifier. The core resolves from the registry at runtime; it never hardcodes variant names. New variants self-register by naming convention or config entry.
**Applied to:** Rule 3 (declarative registry) and Rule 4 (no hardcoded variant lists).

### Strategy Pattern (GoF)
Gamma et al., _Design Patterns_ (1994). Define a family of interchangeable algorithms/behaviors behind a shared interface. Callers work against the interface; the concrete strategy is injected, not imported directly.
**Applied to:** Rule 1 (port/strategy interface) and Rule 5 (injection over direct import).

### Dependency Inversion Principle (DIP)
Robert C. Martin, _Agile Software Development_ (2002). High-level modules must not depend on low-level modules — both depend on abstractions. The abstraction (interface/port) is stable; implementations are swappable. DIP is the architectural *direction* behind Rule 5: callers are the high-level policy; adapters are the low-level detail; the interface is the abstraction both depend on.
**Applied to:** Rule 5 (callers depend on interface, not concrete implementation). Strategy Pattern describes the *shape*; DIP describes the *direction*.

### Semantic Versioning for Interfaces
[semver.org](https://semver.org). Interface contracts — not implementations — are versioned. Patch = compatible fix. Minor = additive (new optional fields). Major = breaking (removed or changed required contract). When the interface changes incompatibly, the major version increments so consumers know.
**Applied to:** Rule 6 (change contract versioning).

---

## Principles

1. **New variants require new files, not modified files.** Adding a new LLM provider, agent runtime, or CLI adapter should create one new file that implements the interface. No changes to the router, registry entry point, or any existing caller.

2. **Change contracts are explicit, not assumed.** Every swappable primitive must document what consumers can rely on across swaps: function signatures, output shapes, exit codes, required keys. Undocumented contracts are unknown contracts — they break silently.

3. **Extension points are registered, not hardcoded.** A switch statement listing known variants is a hardcoded variant list. It breaks every time a new variant is added. Extension points use file-discovery, config-driven, or directory-convention registration.

---

## Rules

### Rule 1 — Swappable primitives MUST define a stable interface contract (`MUST`)

Every primitive that can be swapped — a provider adapter, runtime adapter, CLI integration, skill — MUST have an explicit interface contract. In Bash: a function signature, documented parameters, stdout/stderr contract, and exit codes. In TypeScript: an interface or type.

```bash
# OFF-STANDARD — no contract, callers invoke arbitrary functions
source "scripts/lib/integrations/claude.sh"
claude_call "$prompt"  # what does this return? what exit codes? no contract

# ON-STANDARD — documented interface contract
# Interface: provider_invoke(prompt: string) → stdout: JSON, exit 0=ok 1=rate_limit 2=auth_fail 3=network
# All providers implement this contract.
provider="${DEVOS_PROVIDER:?Set DEVOS_PROVIDER or configure the provider registry default}"
source "scripts/lib/integrations/${provider}.sh"
provider_invoke "$prompt"
```

The interface contract is the file that consumers depend on. The implementation may change freely as long as the contract is honored.

The contract MUST be documented as a `# CONTRACT` header block at the top of the implementation file:

```bash
# CONTRACT: provider_invoke(prompt: string)
#   stdout: newline-terminated JSON {"text": string, ...}
#   exit 0: success
#   exit 1: rate_limit     (retry safe after backoff)
#   exit 2: auth_fail      (not retry safe — check credentials)
#   exit 3: network_error  (retry safe)
```

Every adapter implementing a contract MUST open with this block. When a consumer needs to know the contract, they read the adapter file's header — not its callers or tests.

---

### Rule 2 — Adding a new variant MUST NOT require modifying existing callers (`MUST`)

When a new provider, runtime, or adapter is added, zero existing files change. The new variant implements the interface and is registered. Callers are untouched.

```bash
# OFF-STANDARD — adding "gemini" requires editing the router
case "$PROVIDER" in
  claude)  invoke_claude  "$@" ;;
  openai)  invoke_openai  "$@" ;;
  # → MUST add gemini here — router modification required
esac

# ON-STANDARD — directory-convention registry; no router change needed
# scripts/lib/integrations/gemini.sh implements provider_invoke()
# Router discovers via: source "scripts/lib/integrations/${PROVIDER}.sh"
source "scripts/lib/integrations/${PROVIDER}.sh"
provider_invoke "$@"
# Adding gemini = adding scripts/lib/integrations/gemini.sh. Router unchanged.
```

**DevOS reference:** `scripts/lib/integrations/` — claude.sh, codex.sh, gemini.sh, kimi.sh, hermes.sh, kilo.sh, opencode.sh, zed.sh. Eight adapters; adding a ninth requires one new file.

---

### Rule 3 — Extension registries MUST be declarative (`MUST`)

Registries use file discovery, directory convention, or a config file — not imperative switch/if chains. The registry's extension mechanism must work without touching existing code.

```bash
# OFF-STANDARD — imperative registry; adding a command requires editing this file
get_skill_handler() {
  case "$1" in
    implement-tasks)  echo "implement-tasks/SKILL.md"  ;;
    write-spec)       echo "write-spec/SKILL.md"        ;;
    # every new skill requires editing here
  esac
}

# ON-STANDARD — directory convention; new skill = new directory
get_skill_handler() {
  local skill_dir="${DEVOS_SKILLS_DIR}/${1}"
  [[ -f "${skill_dir}/SKILL.md" ]] && echo "${skill_dir}/SKILL.md"
}
# Adding a new skill = creating ~/.claude/skills/<name>/SKILL.md. No registry edit.
```

**DevOS reference:** `.claude/skills/` — 195 skills discovered by directory convention. Adding skill 196 requires one directory.

Extension registries MUST fail with a clear diagnostic when the requested variant cannot be resolved. Silent failure (undefined variable, `source` of a non-existent file, empty output) is a violation — it produces phantom behavior that is harder to debug than an explicit error.

```bash
# ON-STANDARD — graceful resolution failure
provider="${DEVOS_PROVIDER:?Set DEVOS_PROVIDER or configure the provider registry default}"
provider_file="scripts/lib/integrations/${provider}.sh"
if [[ ! -f "$provider_file" ]]; then
  echo "[ERROR] Provider '${provider}' not found: ${provider_file}" >&2
  echo "[INFO] Available: $(ls scripts/lib/integrations/*.sh | xargs -n1 basename | sed 's/\.sh//' | tr '\n' ' ')" >&2
  exit 3
fi
source "$provider_file"
```

---

### Rule 4 — Hardcoded variant lists in core MUST be eliminated or wrapped with parity gates (`MUST`)

When a variant list cannot be replaced with directory discovery (e.g., ACP allowlists for security), it MUST be:
1. Defined in exactly ONE canonical location
2. Protected by a parity gate that fails CI when the list drifts across its consumers

```bash
# OFF-STANDARD — ACP list hardcoded in 3 files independently
# command-router.sh: ACP_ALLOWED_COMMANDS=(implement-tasks write-spec ...)
# agent-runtime.py: ALLOWED_COMMANDS = ["implement-tasks", "write-spec", ...]
# agent-runtime.py: TOOL_TO_COMMAND = {"implement-tasks": ..., ...}
# Adding a command requires editing all three; drift is silent

# ON-STANDARD — single canonical source + parity gate
# Define in command-router.sh, generate the others, block commit on drift
# Keep the required parity check wired through the active Git pre-commit delegate.
```

**DevOS reference:** the active Git pre-commit delegate invokes `profiles/default/hooks/pre-commit.sh`; wire parity checks there rather than under `.claude/hooks/`.

---

### Rule 5 — Callers MUST depend on the interface, not the concrete implementation (`MUST`)

Callers import or source the interface entry point. The concrete provider is injected or resolved at runtime. This is the Strategy pattern applied at the shell level.

```bash
# OFF-STANDARD — caller hardcodes the implementation
# scripts/lib/advisor-orchestrator.sh
source "scripts/lib/integrations/claude.sh"  # hardcoded; can't swap
claude_invoke "$prompt"

# ON-STANDARD — provider resolved at runtime via registry
# scripts/lib/advisor-orchestrator.sh
provider="${DEVOS_PROVIDER:?Set DEVOS_PROVIDER or configure the provider registry default}"
source "scripts/lib/integrations/${provider}.sh"
provider_invoke "$prompt"  # calls whatever provider is active
```

---

### Rule 6 — Interface changes MUST be versioned; breaking changes MUST be signaled (`MUST`)

When an interface contract changes incompatibly (parameter removed, output shape changed, exit code semantics changed), the version increments and callers are notified. Silent breaking changes violate the contract.

**Additive change (non-breaking):** Adding an optional new output field, a new optional parameter with a default.
**Breaking change:** Removing a field, changing a required parameter name, changing exit code semantics.

```bash
# OFF-STANDARD — breaking change with no signal
# v1: provider_invoke(prompt) → {"text": "..."}
# v2: provider_invoke(prompt) → {"content": "..."}  ← "text" renamed to "content"
# All callers parsing "text" break silently — no version signal

# ON-STANDARD — breaking changes versioned
# provider_invoke_v2(prompt) → {"content": "..."}
# Callers on v1 still work; migration path documented; v1 deprecated with timeline
```

For skills and commands: a breaking change to a skill's input schema MUST increment the skill's major version in its frontmatter and update all callers before the old signature is removed.

**Migration ownership:** The implementer of the new interface version is responsible for migrating all existing callers within the same PR or immediately-following PR. No breaking change ships to main while callers still reference the old version. Migration window is one PR cycle — not "eventual." Callers on the old version with no migration path are a blocking issue.

---

### Rule 7 — Interface contracts MUST be independently testable (`MUST`)

Every interface contract must have a corresponding test that verifies an adapter implements the contract. The test asserts the contract (correct output shape, correct exit codes) against a real adapter — not a mock of itself.

```bash
# tests/bats/lib/integrations/claude.bats
@test "claude adapter: provider_invoke returns JSON on stdout" {
  run provider_invoke "test prompt"
  assert_success                   # exit 0
  run jq '.' <<< "$output"
  assert_success                   # valid JSON
}

@test "claude adapter: provider_invoke exits 1 on simulated rate limit" {
  DEVOS_FORCE_RATE_LIMIT=1 run provider_invoke "test"
  assert_equal "$status" 1
}
```

Contract test files live at `tests/bats/lib/integrations/<adapter>.bats`. One file per adapter. New adapters MUST include a passing contract test before merging. Contract tests are run as part of `make test`.

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `case "$PROVIDER" in claude\|openai\|gemini)` in the router | Adding a new provider requires editing the router | Directory-convention registry; `source "integrations/${PROVIDER}.sh"` |
| Domain logic importing concrete adapter directly (`source "integrations/claude.sh"`) | Couples caller to one implementation; can't swap | Inject via `DEVOS_PROVIDER` env var; source dynamically |
| Same list of variant names in 3 files without a parity gate | Drift is invisible; one file updated, two forgotten | Single canonical source + CI parity gate |
| Renaming a field in a shared interface without versioning | Silent breakage across all callers | Additive change + deprecation period + major version on removal |
| Monolithic skill with `if [[ "$runtime" == "openai" ]]` branches | Adding a runtime requires modifying the skill | Runtime-specific handler files; skill dispatches by convention |
| `shared/utils.ts` with 50+ unrelated exports as the "extension point" | No contract, no stability, every change has unknown blast radius | Narrow interface per swappable surface |
| Interface with 10+ required functions all adapters must implement | Implementing a new adapter becomes expensive; new variants don't get built; extensibility collapses under its own weight | Interface Segregation Principle (ISP): one narrow interface per capability; compose for full-featured adapters (`source streaming.sh && source tool-calls.sh`) |

---

## Deviation guidance

You MAY use a hardcoded list when the list serves a security boundary (e.g., ACP allowlist). When you do: define the list in ONE canonical file, generate or derive all other consumers from it, and enforce parity with a pre-commit gate. Document the deviation at the list definition site.

You MAY maintain two major versions of an interface concurrently during a migration window. MUST document the deprecation timeline and MUST NOT maintain more than two concurrent versions at the same time.

---

## Profile inheritance notes

This standard lives at `general` level and propagates to all profiles. Profile-specific extensions:

- `cli` profile: SHOULD extend with shell-specific contract documentation conventions (header block format for Bash adapters, exit code tables) — extension not yet written; use the `# CONTRACT` header pattern in Rule 1 until a child standard exists
- `webapp` profile: SHOULD extend with TypeScript interface versioning patterns (interface version in the module's `index.ts` exports) — extension not yet written
- Any profile adding a new primitive category (voice agents, browser agents): MUST add the interface contract to this standard before implementing the first variant

---

## Relationship to sibling standards

| This standard (extensibility) | modular-architecture.md | modular-integration.md |
|---|---|---|
| How to design a primitive to be swappable | Where code lives and feature boundaries | How modules connect and register at runtime |
| Interface contracts and versioning | Dependency direction and import rules | Plugin registration protocol and event patterns |
| Extension registry design (no-modification rule) | Circular dependency prevention | Service injection and communication channels |

All three apply simultaneously. A provider that follows modular-architecture (correct boundaries) and modular-integration (correct registration protocol) but has no stable interface contract (violates extensibility) will break callers when it is swapped.

---

## Compliance test

Answer YES or NO. A single NO is an extensibility gap.

1. Does every swappable primitive (provider, runtime, adapter, skill) have an explicit interface contract documenting inputs, outputs, and failure modes? (Y/N)
2. Can a new variant be added by creating one new file, without modifying any existing caller, router, or registry entry point? (Y/N)
3. Are extension registries directory-based, config-driven, or otherwise declarative — not switch/if chains listing variant names? (Y/N)
4. Where hardcoded variant lists are unavoidable (security boundaries), are they defined in exactly one canonical location with a CI parity gate? (Y/N)
5. Do callers depend on the interface contract, not the concrete implementation (injected provider rather than sourced-by-name)? (Y/N)
6. Are breaking interface changes versioned and signaled to consumers — not silently deployed? (Y/N)
7. Does each swappable primitive have a contract test (see Rule 7) that verifies an adapter implements the interface contract — output shape, exit codes, failure modes? (Y/N)

If any check fails: treat as an extensibility bug, not a code smell. Record deviations with justification in a `# DEVIATION(extensibility)` comment at the violation site.

---

## References

- [Robert C. Martin — _Agile Software Development_ (2002)](https://www.pearson.com/en-us/subject-catalog/p/agile-software-development-principles-patterns-and-practices/P200000009509) — Open/Closed Principle; Dependency Inversion Principle
- [Gamma et al. — _Design Patterns_ (1994)](https://www.pearson.com/en-us/subject-catalog/p/design-patterns-elements-of-reusable-object-oriented-software/P200000009505) — Strategy Pattern (pattern 315)
- [Semantic Versioning](https://semver.org) — interface contract versioning (major = breaking, minor = additive, patch = fix)
- [Alistair Cockburn — Hexagonal Architecture (2005)](https://alistair.cockburn.us/hexagonal-architecture/) — Ports and Adapters; ports as stable interfaces, adapters as swappable implementations
- DevOS reference implementations: `scripts/lib/integrations/` (CLI adapters), `.claude/skills/` (skill registry), `profiles/default/hooks/pre-commit.sh` (canonical project hook body)
