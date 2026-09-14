<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/llm-coding-behavior.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/llm-coding-behavior.md and re-run profile-sync. -->
# LLM Coding Behavior Standards

## Overview

LLM coding assistants accumulate a specific category of failure that human developers rarely produce: silent assumption, speculative feature addition, scope creep during edits, and weak self-verification. These failures are not intelligence failures — they are behavior failures. This standard defines the four behavioral constraints that eliminate the most common and most costly LLM coding mistakes.

These guidelines bias toward caution over speed. For trivial tasks, apply judgment.

## Scope

This standard covers AI agent behavior during implementation tasks: assumption handling, scope management, change isolation, success criteria definition, and correct interpretation of skill invocation syntax. It does NOT cover code style or naming (see `coding-style.md`), error handling policy (see `error-handling.md`), or verification gates (see `verification-before-implementation.md`).

## Principles

1. **Surface before acting:** State assumptions, flag ambiguity, present tradeoffs — before writing a single line.
2. **Minimum viable implementation:** The right amount of code is the least amount that solves the problem as stated.
3. **Surgical precision:** Every changed line must trace directly to the request. Nothing more.
4. **Verifiable goals:** Transform vague tasks into falsifiable success criteria before executing.
5. **Skill-native execution:** Treat bare skill names with flags as inline skill invocations, not shell commands.

## Framework Basis

- **Fewest Assumptions Principle:** Unstated assumptions are bugs waiting to surface. Name them first.
- **YAGNI (You Aren't Gonna Need It):** Features not asked for are features that add risk with no value.
- **Surgical Diff Discipline:** The ideal code review shows exactly what changed and why — no noise, no drift.
- **Test-First Verification:** Success criteria defined before implementation prevents goalpost movement.
- **Skill Invocation Boundary:** In a skill-based OS, `skill-name --flag` means invoke that skill inline unless the instruction explicitly says to run a shell command.

## Rules

### Rule 1: Think Before Coding — Surface Assumptions and Ambiguity First

Before implementing, state assumptions explicitly. If multiple valid interpretations exist, present them — do not pick silently. If a simpler approach exists, say so and push back. If something is unclear, stop and name the confusion before proceeding.

**OFF-STANDARD**

```
User: "Add caching to the user endpoint."
Agent: [immediately writes Redis integration with TTL, eviction policy, and cache warming]
```

**ON-STANDARD**

```
User: "Add caching to the user endpoint."
Agent: "Two interpretations:
  A) In-memory cache (simple, single-instance only) — fits if this is a single server
  B) Redis cache (distributed, survives restarts) — needed if load-balanced
Which fits your deployment?"
```

Rules:

- MUST state assumptions before writing code when the request has multiple valid implementations.
- MUST ask when missing information cannot be reasonably inferred and the gap would cause a rewrite.
- SHOULD push back when a simpler approach exists — propose it before implementing the complex one.
- MAY proceed without asking for trivial tasks where intent is unambiguous and stakes are low.

### Rule 2: Simplicity First — Minimum Code That Solves the Problem

Write the least code that satisfies the requirement as stated. No speculative features, no "flexible" abstractions for single-use cases, no error handling for scenarios that cannot occur.

**OFF-STANDARD**

```typescript
// User asked: "add a function to get user by ID"
interface UserFetchOptions {
  includeDeleted?: boolean;
  fields?: string[];
  cacheTtl?: number;
  retryCount?: number;
}

async function getUser(id: string, options: UserFetchOptions = {}) {
  // 80 lines of option handling nobody asked for
}
```

**ON-STANDARD**

```typescript
async function getUserById(id: string) {
  return db.users.findById(id);
}
```

Rules:

- MUST NOT add features beyond what was explicitly requested.
- MUST NOT add abstractions for single-use code.
- MUST NOT add configurability or flexibility that was not requested.
- MUST NOT add error handling for scenarios that cannot occur given the surrounding system.
- SHOULD ask "would a senior engineer say this is overcomplicated?" — if yes, simplify before submitting.

### Rule 3: Surgical Changes — Touch Only What the Request Requires

When editing existing code, change only the lines the request requires. Do not improve adjacent code, reformat unrelated blocks, or refactor things that are not broken. Match existing style even when a different style would be preferable.

**OFF-STANDARD**

```diff
- function processOrder(o) {
+ function processOrder(order: Order): ProcessedOrder {
-   var items = o.items
+   const items = order.items;
-   var total = 0
+   let total = 0;
    // ... actual fix for the bug that was reported
+   // Also renamed variables, added types, reformatted the whole function
```

**ON-STANDARD**

```diff
  function processOrder(o) {
    var items = o.items
-   var total = o.subtotal
+   var total = o.subtotal ?? 0   // fix: handle missing subtotal
    // ... only the lines the bug fix required
```

Rules:

- MUST NOT improve, reformat, or refactor code adjacent to the requested change.
- MUST match existing style (variable naming, spacing, patterns) even when not preferred.
- MUST remove imports/variables/functions that YOUR changes made unused. Do not remove pre-existing dead code unless asked.
- SHOULD mention unrelated dead code or issues noticed — but not fix them silently.
- The test: every changed line should trace directly to the user's request.

### Rule 4: Goal-Driven Execution — Define Success Criteria Before Acting

Transform vague tasks into verifiable goals. State a brief plan with a check per step before executing multi-step tasks. Strong success criteria enable independent looping; weak criteria ("make it work") require constant re-clarification.

**OFF-STANDARD**

```
Task: "Fix the login bug"
Agent: [changes 3 files, no stated hypothesis, no test written, reports "should be fixed"]
```

**ON-STANDARD**

```
Task: "Fix the login bug"
Agent:
  Hypothesis: session cookie not set when login redirects — missing Set-Cookie header.
  Plan:
    1. Write test that reproduces the redirect-without-cookie → verify: test fails
    2. Fix Set-Cookie header in auth middleware → verify: test passes
    3. Run full auth test suite → verify: no regressions
```

Rules:

- MUST state a hypothesis before editing code during bug fixes.
- MUST define success criteria before executing multi-step tasks.
- SHOULD transform vague tasks ("add validation", "fix the bug") into verifiable goals before starting.
- SHOULD loop independently until success criteria are met rather than asking for approval after each step.

Transformation patterns:

| Vague task | Verifiable goal |
|---|---|
| "Add validation" | Write tests for invalid inputs, then make them pass |
| "Fix the bug" | Write a test that reproduces it, then make it pass |
| "Refactor X" | Confirm tests pass before and after — behavior unchanged |
| "Make it work" | Define what "working" means (output, behavior, test) before touching code |

### Rule 5: Skill Invocation Syntax — Do Not Route Inline Skills Through Shell

When instructions, chains, workflows, or skills mention a bare skill name with flags, treat it as an inline skill invocation by the active agent. Do not run it through `devos`, `bash`, `npx`, or any CLI launcher unless the instruction explicitly says "run the shell command" or provides an executable path/script.

**OFF-STANDARD**

```bash
# Instruction says: gap-analysis --dalio --converge --fix
devos gap-analysis --dalio --converge --fix
bash -lc "gap-analysis --dalio --converge --fix"
```

**ON-STANDARD**

```
Apply the gap-analysis skill inline with args: --dalio --converge --fix.
For chain YAML, represent the same operation as:
{name: gap-analysis, args: "--dalio --converge --fix"}
```

Rules:

- MUST interpret `skill-name --flags` as inline skill execution when `skill-name` resolves to a DevOS skill.
- MUST NOT route inline skill syntax through the DevOS launcher, shell, package runners, or CLI clients without explicit instruction.
- MUST use structured chain notation (`{name: <skill>, args: "..."}`) when documenting chain steps with flags.
- SHOULD ask or inspect the skill registry only when the token before the flags is ambiguous and may not be a skill.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Silent assumption — picking one interpretation without stating it | Produces the wrong output; causes full rewrites | Name the assumption or ask before implementing |
| Speculative features — adding things "the user might want later" | Adds untested code with no requirement to anchor it | Implement exactly what was asked |
| Scope drift — improving adjacent code during a focused fix | Noise in the diff; unintended regressions | Touch only lines the request requires |
| Vague success criteria — "make it work", "it should be fine" | Cannot self-verify; requires constant human check-in | Define falsifiable criteria before executing |
| Post-hoc explanation — reporting done before verifying | Ships broken code with confident framing | Run the verification step, then report |
| Shell-routing inline skills — running `skill-name --flags` through `devos`, `bash`, or package runners | Misroutes skill-native workflows and creates false blockers | Invoke the named skill inline with the provided args |

## Deviation Guidance

- Agents MAY proceed without asking when the task is trivial, intent is unambiguous, and the worst-case outcome is a minor correction.
- Agents MAY apply light cleanup to their own new code (formatting, naming) when it was just written in this same change — not to pre-existing code.
- Agents MUST NOT apply these rules so rigidly that they ask unnecessary questions on tasks where the path is clear.
- Agents MUST apply Rule 1 strictly when the request involves destructive operations (deletes, migrations, force-pushes) — even if intent seems clear.
- Agents MUST apply Rule 5 strictly in DevOS skill, chain, and workflow contexts.

## Related Standards

- `coding-style.md` — code quality and readability rules for the artifact itself
- `verification-before-implementation.md` — pre-change verification gates
- `error-handling.md` — when and how to handle errors at system boundaries
- `debugging-escalation.md` — structured escalation for stuck debugging loops

## Compliance Test

- [ ] Were assumptions stated before implementation started?
- [ ] Does the diff contain only lines traceable to the request?
- [ ] Was adjacent unrelated code left unchanged?
- [ ] Was the solution the simplest one that satisfies the requirement?
- [ ] Were success criteria defined before execution began on multi-step tasks?
- [ ] Were bare `skill-name --flags` references treated as inline skill invocations instead of shell commands?
