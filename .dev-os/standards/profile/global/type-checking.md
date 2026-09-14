<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/global/type-checking.md and re-run profile-sync. -->
# Type Checking Standards — CLI Profile

Extends: [../../../default/standards/global/type-checking.md](../../../default/standards/global/type-checking.md)

## Overview

CLI tools have a specific type-safety failure mode that web applications do not: **undetected argument contract violations at the process boundary**. A REST API returns a typed response; a CLI tool writes to stdout or exits with a code — and if the argument types are wrong, the failure surfaces as a runtime crash or silent bad output in a user's shell pipeline.

This standard narrows the default profile's multi-language type-checking guide to the CLI profile's actual stack: TypeScript 5.6+ with Bun, and Python 3.11+. Rules for Go, Rust, Java, and C# are defined in the default profile and apply unchanged when those languages are present.

## Scope

This standard covers TypeScript and Python type-checking configuration, CLI argument typing contracts, and CI integration for CLI tools. It does NOT cover request/response body schemas (see `api-contracts.md`), frontend component prop types, or database schema type generation.

## Principles

1. **Process boundary first:** The stdin/stdout/argv boundary is where type guarantees matter most — every public CLI argument and every output format MUST be typed before internal implementation details.
2. **Strict by default, deviation by record:** Strict mode is non-negotiable. Any suppression (`@ts-expect-error`, `# type: ignore`) requires an inline comment naming the reason and a linked issue.
3. **Fail at check time, not shell time:** Type errors that reach the user's terminal are harder to debug than type errors caught in CI. Type checks run before any publish or release step.

## Rules

### TypeScript — tsconfig

**MUST extend the CLI base config** (`MUST` per RFC 2119):

```jsonc
// tsconfig.json — CLI tool
{
  "extends": "./tsconfig.base.json",
  "compilerOptions": {
    "module": "ESNext",
    "target": "ESNext",
    "lib": ["ESNext"],
    "types": ["bun-types"],
    "moduleResolution": "bundler"
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist"]
}
```

`tsconfig.base.json` is defined in the default profile and MUST NOT be duplicated here. Link to it, do not copy it.

**OFF-STANDARD — inline strict options in project tsconfig:**
```jsonc
// BAD: Duplicates default profile config, diverges silently
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true
  }
}
```

**ON-STANDARD — extend only:**
```jsonc
{
  "extends": "./tsconfig.base.json",
  "compilerOptions": {
    "types": ["bun-types"]
  }
}
```

### TypeScript — CLI argument typing

**MUST define an `Options` interface for every command** — never use `any` or raw `process.argv` access.

**OFF-STANDARD:**
```typescript
const program = new Command();
program.option('-o, --output <path>', 'Output file').action((opts) => {
  fs.writeFileSync(opts.output, data); // opts is any
});
```

**ON-STANDARD:**
```typescript
interface BuildOptions {
  output: string;
  verbose: boolean;
  count?: number;
}

program
  .option('-o, --output <path>', 'Output file path')
  .option('-v, --verbose', 'Verbose output', false)
  .option('-c, --count <n>', 'Repeat count', parseInt)
  .action((opts: BuildOptions) => {
    fs.writeFileSync(opts.output, buildContent(opts));
  });
```

**MUST use `satisfies` over `as` for config objects:**

```typescript
// OFF-STANDARD: type assertion loses literal types
const config = { mode: 'strict', retries: 3 } as Config;

// ON-STANDARD: satisfies validates shape while preserving literals
const config = { mode: 'strict', retries: 3 } satisfies Config;
```

### TypeScript — suppression policy

`@ts-expect-error` is preferred over `@ts-ignore`. Both MUST include:
1. A reason in the trailing comment
2. A linked issue number if the suppression is temporary

```typescript
// OFF-STANDARD: bare suppression
// @ts-ignore
const result = legacyAdapter(data);

// ON-STANDARD: documented suppression
// @ts-expect-error — legacyAdapter lacks types, tracked in #204
const result = legacyAdapter(data);
```

### Python — pyproject.toml config

**MUST use mypy strict mode.** The CLI profile requires Python 3.11+ — use modern union syntax.

```toml
[tool.mypy]
strict = true
warn_unreachable = true
warn_return_any = true
python_version = "3.11"
pretty = true
show_column_numbers = true
show_error_codes = true
```

**MUST annotate all public CLI entry points with full signatures:**

```python
# OFF-STANDARD: unannotated entry point
def run(args):
    output_path = args.output
    count = args.count or 1
    process(output_path, count)

# ON-STANDARD: fully annotated
import argparse

def run(args: argparse.Namespace) -> None:
    output_path: str = args.output
    count: int = args.count or 1
    process(output_path, count)
```

**MUST use `|` union syntax, not `Optional[X]`:**

```python
# OFF-STANDARD: legacy Optional
from typing import Optional
def get_config(path: Optional[str]) -> Optional[dict[str, str]]: ...

# ON-STANDARD: PEP 604 union
def get_config(path: str | None) -> dict[str, str] | None: ...
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Raw `process.argv` access | Untyped, position-dependent, breaks on reorder | Define `Options` interface + commander/clipanion |
| `any` in argument handlers | Silently accepts wrong types at runtime | Explicit interface cast with type guard |
| Duplicate `strict: true` in project tsconfig | Diverges from default profile baseline silently | Extend `tsconfig.base.json` only |
| `Optional[T]` in new Python code | Verbose, inconsistent with 3.11+ standard | `T \| None` (PEP 604) |
| Bare `@ts-ignore` without reason | Suppresses type error with no audit trail | Document reason + issue number |
| `ignore_missing_imports = true` globally | Masks untyped dependencies wholesale | Scope per-module in `[[tool.mypy.overrides]]` |

## Deviation guidance

**MAY** use `ignore_missing_imports = true` for a specific third-party module when no stubs exist and creating a stub file is not feasible. MUST scope it to that module via `[[tool.mypy.overrides]]`, not globally.

**MAY** omit the `Options` interface for single-argument scripts (fewer than 20 lines, fewer than 3 flags). MUST add the interface before the script reaches 3 flags or is shared as a reusable command.

**MUST NOT** reduce tsconfig strictness below the default profile baseline for any reason. If a library is incompatible with strict mode, patch its types or use `@ts-expect-error` per the suppression policy above.

## Profile inheritance notes

Extends: `default/standards/global/type-checking.md`
Adds: CLI argument typing contract, `satisfies` requirement, PEP 604 union syntax, suppression policy with linked-issue requirement.
Overrides: Scope — the default standard covers 6 languages; this standard applies only TypeScript + Python for CLI tools.
Not overriding: Go, Rust, Java, C# sections remain in the default standard and apply unchanged when those languages are present.

## Compliance test

- [ ] Does every CLI command have a typed `Options` / `argparse.Namespace` interface — no raw `process.argv` or untyped `args`?
- [ ] Does `tsconfig.json` use `"extends": "./tsconfig.base.json"` without duplicating strict options?
- [ ] Does every `@ts-ignore` or `@ts-expect-error` have an inline reason comment?
- [ ] Does `pyproject.toml` have `strict = true` under `[tool.mypy]`?
- [ ] Does new Python code use `T | None` union syntax — no `Optional[T]`?

If any check fails: fix the violation directly, or record the deviation in the file with a linked issue number.

## References

- [RFC 2119 — Key Words for Use in RFCs](https://datatracker.ietf.org/doc/html/rfc2119) — normative vocabulary (MUST / SHOULD / MAY) used throughout this standard
- [TypeScript Strict Mode](https://www.typescriptlang.org/tsconfig#strict) — what `strict: true` enables and why
- [PEP 604 — Union Type Syntax](https://peps.python.org/pep-0604/) — `X | Y` over `Optional[X]` in Python 3.10+
- [TypeScript `satisfies` operator](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html#the-satisfies-operator) — shape validation without losing literal types
- [Default profile type-checking](../../../default/standards/global/type-checking.md) — full multi-language reference this extends
