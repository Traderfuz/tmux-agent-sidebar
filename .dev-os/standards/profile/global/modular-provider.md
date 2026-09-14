<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/global/modular-provider.md and re-run profile-sync. -->
# Modular Provider Standards — CLI Profile

Extends: [../../../default/standards/global/modular-provider.md](../../../default/standards/global/modular-provider.md)

Also extends:
- [../../../general/standards/global/provider-agnostic-architecture.md](../../../general/standards/global/provider-agnostic-architecture.md)

## Overview

CLI tools use the same provider-boundary pattern as the default profile, but their dominant risk is different: provider leakage shows up as broken terminal behavior, unstable output formats, and shell-pipeline incompatibility rather than UI regressions. This standard narrows the parent provider contract for command-line tools.

## Scope

This standard covers provider-boundary expectations specific to CLI tools: command-facing adapter boundaries, stdout/stderr discipline, and exit-code-safe failure handling. It does NOT cover webapp component boundaries or browser-side provider usage.

## Principles

1. **Command surfaces stay provider-agnostic:** CLI commands should expose stable flags, output, and exit semantics regardless of which provider is active underneath.
2. **Provider failures map cleanly to shell contracts:** A provider outage should become a typed CLI failure, not a raw SDK dump in the terminal.
3. **Human output and machine output stay stable:** Swapping providers must not silently change JSON shape or text format contracts.

## Rules

### Rule 1: Command handlers MUST depend on local provider ports, not vendor SDKs

Command modules should talk to a router, service, or local interface, not instantiate a concrete provider directly.

### Rule 2: Provider swaps MUST preserve output contracts

If a CLI advertises JSON output, line-oriented output, or stable field names, provider changes must preserve that contract.

### Rule 3: Provider errors MUST map to CLI-safe failures

Provider exceptions should be translated into:

- structured stderr output for human operators
- stable machine-readable error output when the command supports it
- explicit non-zero exit codes

Raw vendor traces should not be the default CLI error surface.

### Rule 4: Authentication and provider selection SHOULD stay out of call sites

Environment-based provider selection, fallback order, and auth checks belong in one router or composition layer rather than being repeated across commands.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Importing a vendor SDK directly inside a CLI command file | Couples terminal behavior to one provider | Use a local provider interface or router |
| Letting each command invent its own fallback behavior | Creates inconsistent failure modes | Centralize provider selection and fallback |
| Changing JSON output shape when switching providers | Breaks shell pipelines and integrations | Normalize provider responses before printing |
| Dumping raw SDK errors to stdout | Pollutes machine-readable output and confuses users | Map to stable stderr and exit-code behavior |

## Deviation Guidance

- Commands MAY expose a `--provider` debug or development flag when there is a legitimate operator need, but the default path should still route through the shared provider layer.
- Teams MUST NOT let provider-specific payloads leak into documented CLI output formats.

## Profile Inheritance Notes

Overrides: none
Adds: CLI output-contract, exit-code, and shell-surface constraints

## Compliance Test

- [ ] Do CLI commands use a local provider boundary instead of vendor SDKs directly?
- [ ] Does provider substitution preserve documented stdout or JSON contracts?
- [ ] Are provider failures translated into CLI-safe stderr and exit-code behavior?
- [ ] Is fallback and provider selection centralized instead of repeated across commands?
- [ ] Does this file add only CLI-specific deltas rather than restating the parent standard?
