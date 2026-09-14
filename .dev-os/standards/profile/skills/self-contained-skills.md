<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/self-contained-skills.md and re-run profile-sync. -->
# Self-Contained Skills Standard

## Overview

A self-contained skill works in any project context without undeclared dependencies. It declares what it needs, degrades gracefully when optional dependencies are absent, and never assumes project structure, MCP server availability, or environment state that it has not verified. Without this property, skills that pass all structural and content validation still fail silently when used outside the author's original environment.

## Scope

This standard covers dependency declaration, runtime environment assumptions, MCP server coupling, inter-skill coupling, and portability constraints for Claude Code skills.

It does NOT cover skill file structure (see `skill-structure.md`), content quality (see `skill-content-standards.md`), or trigger design (see `skills-authoring-best-practices.md`).

## Principles

1. **Declare, don't assume.** Every external dependency — tool, MCP server, file, environment variable, project structure — must appear in the Prerequisites section. An undeclared dependency is an invisible failure mode.
2. **Degrade, don't crash.** When an optional dependency is absent, the skill should produce a reduced but useful result, not an unexplained failure. The skill must distinguish between hard requirements (cannot proceed) and soft requirements (can proceed with reduced capability).
3. **Verify at entry, not mid-workflow.** Check all hard dependencies at the start of execution. A skill that fails at step 7 of 10 because a tool was missing wastes the work of steps 1-6.
4. **Zero implicit coupling.** A skill must not silently depend on another skill being loaded, a specific DevOS profile being active, or a particular project directory structure existing. If a skill chains to another skill, it names that skill explicitly and states what happens if it is absent.

## Rules

### Dependency Declaration

Every skill MUST declare its dependencies in the Prerequisites section using three categories:

```markdown
## Prerequisites

**Required (will not proceed without these):**
- `jq` CLI installed
- Git repository in the current directory

**Optional (degrades gracefully without these):**
- Context7 MCP server (falls back to training knowledge if unavailable)
- `scripts/validate.sh` (skips validation step if missing)

**Assumed (standard Claude Code environment):**
- Bash tool access
- Read/Write/Edit/Glob/Grep tools
- File system access to the current working directory
```

**OFF-STANDARD — Undeclared MCP dependency:**
```markdown
## Step 3
Query Context7 for the latest React docs.
```

**ON-STANDARD — Declared with fallback:**
```markdown
## Prerequisites
**Optional:** Context7 MCP server (for up-to-date library docs; falls back to training knowledge)

## Step 3
If Context7 is available, query for latest React docs. Otherwise, use training knowledge
and note that docs may not reflect the latest version.
```

### MCP Server Coupling

Skills MUST NOT hard-depend on a specific MCP server being available unless the skill's entire purpose is to operate that server (e.g., a `supabase` skill requiring the Supabase MCP).

For skills that benefit from but don't require an MCP server:
- List the server as an Optional prerequisite
- Provide a concrete fallback behavior for each MCP-dependent step
- Never let a missing MCP server produce an unhandled error

**OFF-STANDARD — Silent MCP assumption:**
```markdown
## Step 2
Store the result in memory using mcp__memory__store_memory.
```

**ON-STANDARD — Explicit optional dependency:**
```markdown
## Step 2
If Memory MCP is available, store the result for cross-session retrieval.
If unavailable, write the result to `./output/` as a local file instead.
```

### Inter-Skill Coupling

When a skill references another skill:
- Name the dependency explicitly: "This skill chains to `bx-skill-creator` for skill generation."
- State what happens if the referenced skill is not installed: "If `bx-skill-creator` is not available, perform the skill creation manually following the output format in the Outputs section."
- Never use implicit skill chaining where one skill silently assumes another will handle a step.

**OFF-STANDARD — Implicit chain:**
```markdown
## Step 5
Now use the brainstorm skill to refine the approach.
```

**ON-STANDARD — Explicit chain with fallback:**
```markdown
## Step 5
If the `brainstorm` skill is installed, delegate approach refinement to it.
If not installed, apply the following inline refinement checklist:
1. Does the approach solve the stated problem?
2. Are there simpler alternatives?
3. What are the failure modes?
```

#### Never invoke a skill as a shell command (`command -v <skill>`)

DevOS skills are **registry-routed, not on `$PATH`**. A skill that gates an action behind
`command -v <other-skill>` — or runs a bare `<skill> --flag` as a subprocess — is broken:
`command -v <skill>` ALWAYS fails, so the guarded action (a map refresh, a `knowledge-pull`,
a `context-full-refresh`) is **silently skipped**. To trigger another skill, write a plain
instruction to *invoke* it; for a deterministic, backgroundable refresh, call the underlying
**script** (e.g. `scripts/bundle-refresh.sh`, `scripts/devos-context-refresh.sh`) — never the
skill name as a binary. Enforced by `validate-skill.sh` **SK18** (must-fix).

**OFF-STANDARD — skill gated as a shell command (silently no-ops):**
```bash
if command -v map >/dev/null 2>&1; then map --update; fi      # map is a skill → always false
```

**ON-STANDARD — invoke the skill, or call the deterministic script:**
```markdown
If the codebase map is stale, **invoke the `map` skill** (`--update`).
For a non-interactive refresh, run `scripts/devos-context-refresh.sh --mode soft` (a real script).
```

### Project Structure Assumptions

Skills MUST NOT assume a specific project structure unless they declare it as a hard prerequisite.

- Do not assume `.dev-os/` exists unless the skill is explicitly a DevOS-only skill
- Do not assume `package.json`, `tsconfig.json`, or any framework file exists without checking
- Do not assume a specific directory layout (`src/`, `app/`, `pages/`) without verifying
- Use discovery (Glob, file existence checks) rather than hardcoded paths

**OFF-STANDARD — Hardcoded project structure:**
```markdown
## Step 1
Read the project config from `.dev-os/config.yml` to determine the active profile.
```

**ON-STANDARD — Discovery-based approach:**
```markdown
## Step 1
Check if `.dev-os/config.yml` exists. If present, read the active profile.
If not present, this project is not DevOS-initialized — proceed with
framework-agnostic defaults.
```

### Environment State Assumptions

Skills MUST NOT depend on:
- Specific environment variables being set (unless declared as Required prerequisites)
- A particular shell (bash vs zsh) beyond standard POSIX compatibility
- Network connectivity (unless the skill's purpose requires it, e.g., web scraping)
- A specific operating system (unless declared — e.g., "Linux only")
- Prior session state or memory from a previous invocation

When a skill requires environment state, it MUST verify that state at entry:

```markdown
## Quick start

1. Verify prerequisites:
   - Confirm `DOPPLER_TOKEN` is set (required for secret sync)
   - Confirm `git rev-parse --show-toplevel` succeeds (must be in a git repo)
2. If any required prerequisite fails, stop and report which one is missing.
```

### Portability Across Profiles

Skills installed globally (`~/.claude/skills/`) MUST work regardless of which DevOS profile is active. A skill that only works under the `webapp` profile but is installed globally is not self-contained — it should either:
- Be scoped to the profile (`profiles/webapp/skills/`)
- Or handle the absence of profile-specific context gracefully

### Entry-Point Verification Pattern

Skills with more than two hard dependencies SHOULD include a verification gate as their first workflow step:

```markdown
## Workflow

### Step 0: Preflight check

Before proceeding, verify all required dependencies:

| Dependency | Check | Required? |
|---|---|---|
| `jq` | `command -v jq` | Yes — abort if missing |
| Git repo | `git rev-parse --show-toplevel` | Yes — abort if missing |
| Context7 MCP | Attempt `resolve-library-id` | No — degrade to training knowledge |
| Node.js | `command -v node` | No — skip Node-dependent steps |

If any required dependency fails, report the missing dependency and stop.
If any optional dependency fails, note the degraded capability and continue.
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Skill works on author's machine but fails everywhere else | Undeclared dependencies on local tools, paths, or MCP servers that aren't universal | Declare all dependencies in Prerequisites with Required/Optional/Assumed categories |
| MCP server call with no fallback | Skill crashes when server is unavailable, offline, or not configured in the user's environment | List MCP as Optional; provide a concrete non-MCP fallback for each dependent step |
| Implicit skill chaining ("now use the X skill") | If skill X is not installed, the workflow dead-ends with no recovery path | Name the dependency, state what happens if absent, provide an inline fallback |
| Checking dependencies at step 7 of 10 | Steps 1-6 execute successfully, then the skill fails — wasting context window and user time | Move all hard dependency checks to Step 0 (preflight) |
| Assuming `.dev-os/` or `package.json` exists | Fails in repos that aren't DevOS-initialized or don't use Node.js | Use file existence checks and provide framework-agnostic defaults |
| Requiring network for offline-capable tasks | Skill fails in air-gapped environments or when a service is temporarily down | Separate network-dependent steps from offline-capable steps; mark network as Required only when truly necessary |

## Deviation Guidance

You MAY omit fallback behavior for an MCP server when the skill's entire purpose is to operate that specific service (e.g., `supabase` skill requiring Supabase MCP, `linear` skill requiring Linear MCP). In this case, the MCP server is a Required dependency, not Optional.

You MAY assume standard Claude Code tool availability (Bash, Read, Write, Edit, Glob, Grep) without declaring them — these are part of the Assumed baseline.

You MAY assume git is available without checking when the skill is explicitly scoped to git workflows (e.g., `commit`, `worktrees`). Document this in the scope.

You MUST NOT use any deviation to skip the Prerequisites section entirely. Even a fully self-contained skill with zero external dependencies should state: "No external dependencies required."

## Profile Inheritance Notes

Extends: `general` profile standards.
Adds: Self-containment rules specific to skill portability and dependency management.
Overrides: Nothing from general — this standard is additive.

This standard applies to all skills regardless of profile. Skills in profile-specific directories (`profiles/webapp/skills/`) have a narrower portability requirement (they may assume profile context) but must still declare that assumption explicitly.

## Compliance Test

- [ ] Does the Prerequisites section categorize every dependency as Required, Optional, or Assumed?
- [ ] Does every MCP-dependent step have a concrete fallback behavior documented for when the server is unavailable?
- [ ] Does every inter-skill reference name the dependency explicitly and state what happens if the referenced skill is absent?
- [ ] Are all hard dependencies verified at skill entry (Step 0 / preflight) rather than discovered mid-workflow?
- [ ] Does the skill avoid hardcoded project structure assumptions, using discovery checks instead?

If any check fails: add the missing declaration, fallback, or verification. A skill that passes structural and content validation but fails self-containment is not portable.

## References

- [Twelve-Factor App — Dependencies](https://12factor.net/dependencies) — "Explicitly declare and isolate dependencies." Applied here: skills declare, not assume.
- [Postel's Law (Robustness Principle)](https://en.wikipedia.org/wiki/Robustness_principle) — "Be conservative in what you send, liberal in what you accept." Applied here: skills should work with minimal environment and not demand more than they need.
- `skill-structure.md` — Physical layout and frontmatter rules
- `skill-content-standards.md` — Content quality and section requirements
- `skills-authoring-best-practices.md` — Trigger design and operational quality
