<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/command-skill-split.md and re-run profile-sync. -->
# Command-Skill Split Standard

## Overview

High-complexity DevOS surfaces often need two things at the same time: a stable public command contract and a reusable orchestration capability beneath it. When those layers collapse into one file, the command becomes a logic dump, the reusable capability never materializes, and docs/runtime/help surfaces drift because the public contract is buried inside internal reasoning text. This standard defines the split between command, skill, workflow, and `scripts/lib` ownership.

## Scope

This standard covers DevOS command surfaces that keep a public `<name>` identity while delegating most reasoning or orchestration beneath them. It defines when a command remains a command, when a backing skill should exist, what belongs in workflow files, and what belongs in deterministic shell libraries.

## Principles

1. **Public contract stays public:** Commands own the stable entrypoint that users, help output, and runtimes expose.
2. **Reusable reasoning should not live in command files:** Skills hold the orchestration intelligence that may be reused by multiple commands or agents.
3. **Deterministic procedure belongs below the reasoning layer:** Workflows and `scripts/lib` implement repeatable execution details.
4. **Thin stubs reduce drift:** A command that delegates clearly is easier to validate than a command that narrates every phase inline.

## Framework Basis

This standard combines four named frameworks:

- **RFC 2119 Normative Vocabulary:** MUST/SHOULD/MAY rules make ownership boundaries reviewable.
- **ISO Scope Pattern:** keeps the standard focused on command-skill boundary decisions.
- **Separation of Concerns:** public interface, orchestration reasoning, process flow, and deterministic runtime code each keep distinct ownership.
- **Convention over Configuration:** once the split is defined, new orchestration surfaces should follow the same pattern by default.

## Rules

### Rule 1: Public `` surfaces MUST remain commands

If users invoke a surface as `<name>`, that surface must remain a command even when most of its internal behavior moves into a skill or workflow layer.

Commands own:

- frontmatter
- public name and description
- user-facing flags or modes
- help/runtime/ACP/MCP command identity
- explicit delegation targets

Commands do not stop being commands just because a reusable skill exists underneath them.

### Rule 2: A backing skill SHOULD exist when orchestration reasoning is reusable

Create a backing skill when the surface contains reusable judgment such as:

- prioritization across backlog/spec/task state
- pause/resume/abort routing
- review-gate sequencing
- blocker detection and next-step recommendation

**OFF-STANDARD**

```markdown
# orchestrate

[200 lines of recommendation logic, routing heuristics, and workflow detail]
```

**ON-STANDARD**

```markdown
# orchestrate

Use the `work-orchestration` skill for prioritization and recommendation logic.
Use `{{workflows/implementation/orchestrate}}` for the deterministic recommendation flow.
```

### Rule 3: Thin command stubs MUST state what they own and what they delegate

A thin command stub must contain:

- valid frontmatter
- heading matching `<name>`
- short summary of the public modes or flags it preserves
- the backing skill name when one exists
- the workflow reference that carries the deterministic process

If a command stays under roughly 30 lines, it should still make delegation explicit rather than assuming the reader will infer it.

### Rule 4: Workflows MUST carry multi-step procedure, not reusable domain expertise

Workflow files are the right home for:

- ordered phase flows
- gating and checkpoints
- required reads/writes
- structured prompts or output formats

They should not become the permanent home of reusable judgment that multiple commands could share. If a workflow contains portable reasoning rather than procedure, it likely belongs in the skill.

### Rule 5: `scripts/lib` MUST own deterministic runtime implementation

Put deterministic shell behavior in `scripts/lib` when the work involves:

- file creation or mutation
- state persistence
- command dispatch
- machine-readable output
- reusable shell helpers

Skills and workflows may instruct the runtime to use these libraries, but they must not replace them as the execution layer.

### Rule 6: Public docs and runtimes MUST continue to point at the command, not the skill

When a command gets a backing skill:

- help output still advertises `<name>`
- runtime surfaces still expose the command identity
- docs still teach the command as the entrypoint

The skill is an implementation boundary, not the public replacement.

### Rule 7: DevOS SHOULD use bx-* authoring tools when creating split artifacts

When implementing a new command-skill split:

- use `bx-standards-creator` for the split standard
- use `bx-skill-creator` for new skills
- use `bx-workflow-creator` for new workflows or shared snippets
- use `bx-agent-creator` only if a distinct agent boundary is truly required

If the tool is unavailable, a manual fallback is acceptable, but the result must still satisfy this standard.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Converting a public command into a skill and deleting the command surface | Breaks the stable user/runtime contract | Keep the command and delegate beneath it |
| Leaving orchestration logic entirely inside a long command file | Makes validation and maintenance harder | Move reasoning to a skill and flow to workflows |
| Treating the skill as the help-visible public API | Creates docs/runtime drift | Keep help and runtime surfaces anchored to the command |
| Putting deterministic file mutation only in markdown instructions | Makes behavior hard to test and reuse | Keep execution in `scripts/lib` |
| Creating both a command and skill that fully restate each other | Duplicates ownership and invites drift | Make the command a thin stub with explicit delegation |

## Deviation Guidance

- A command MAY remain more descriptive than a minimal thin wrapper when public modes or flags need quick user-facing explanation, but it should still delegate the deeper logic explicitly.
- A command MAY omit a backing skill when the surface is a simple deterministic wrapper with no reusable judgment.
- A dedicated agent MAY be introduced for orchestration only when the command-skill-workflow split still leaves a distinct long-running agent boundary to own.

## Related Standards

- `command-quality.md` for baseline command structure and thin-wrapper rules
- `bx-tool-routing.md` for authoritative bx-* tool selection
- `artifact-ownership.md` for ownership of generated artifacts
- `profile-standards-inheritance.md` for keeping maintenance standards thin and non-duplicative

## Compliance Test

- [ ] Does the public `` surface still exist as a command?
- [ ] Does the command clearly state its public modes and delegation targets?
- [ ] If reusable orchestration reasoning exists, is it captured in a backing skill?
- [ ] Is multi-step deterministic procedure represented in workflow files?
- [ ] Is runtime execution behavior kept in `scripts/lib` rather than buried in the command or skill?
- [ ] Do help/runtime/docs surfaces still point users to the command, not directly to the skill?
