<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/skill-surface-invocation.md and re-run profile-sync. -->
# In-Session Skill Surface Invocation Standard

## Overview

This standard governs DevOS skill execution. A user-facing skill command loads
the skill into the current active session; that session performs the workflow
directly instead of dispatching it elsewhere.

## Scope

This standard covers top-level skill invocations and inter-skill dependencies.
It does not cover deterministic shell helpers or user-requested agent delegation.

## Principles

1. **Registry is the source of truth:** Skill availability is determined by the active skill registry, not `$PATH`.
2. **Skills run in the active session:** Loading `SKILL.md` establishes the workflow; the current session executes it.
3. **Inter-skill calls stay in-session:** Read the dependent skill and continue its workflow directly.
4. **Execution evidence is behavioral:** Tool output, artifacts, and verification prove execution; dispatch receipts are not required.

## OMP invocation

The user invokes a discovered skill with:

```text
/skill:<name> [arguments]
```

This loads the skill into the current OMP session. It is not a request for the
model to submit another slash command. Once loaded, the session executes the
skill and any required inter-skill workflows directly.

`skill://<name>` is the read-only resource URL for inspecting a skill file. It
does not by itself prove that the workflow ran.

## Rules

### Skill resolution

- The active session MUST resolve the canonical skill name through the registry.
- It MUST NOT use `command -v <skill>`, `which`, or `$PATH` as an availability check.
- It MUST read the applicable `SKILL.md` before executing that workflow.

### Active-session execution

- OMP `/skill:<name> [args]` is the user-facing entry that loads a skill into the current session.
- The current session MUST execute the loaded workflow directly.
- A required inter-skill dependency MUST be read and executed in the same active session.
- The session MUST NOT look for a dispatch API, submit nested slash commands, or require `skill-dispatch-result/v1` receipts.
- Deterministic helpers MAY run only where the skill explicitly identifies them as implementation steps.
- Completion evidence MUST come from the workflow's actual outputs and required verification.

### Delegated workers

- A delegated worker that encounters a required parent-owned skill returns `dependency_required`.
- The worker MUST include the canonical skill, exact arguments, dependent gate, and dependent artifact.
- The active parent session then reads and executes that skill directly.
- The dependent gate remains blocked until behavioral verification passes.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `command -v optimize` | Skills are not shell binaries | Resolve and read `optimize`, then execute it in the active session |
| Looking for `invoke_skill` or another dispatch API | The active session already owns execution | Continue the dependent workflow in-session |
| Submitting a nested `/skill:...` command | Slash commands are user-facing loaders | Read the target `SKILL.md` and execute it directly |
| Requiring a dispatch receipt | A receipt is unrelated to direct session execution | Verify real tool output, artifacts, and behavior |
| Running only a named helper | A helper may implement one phase, not the full skill | Apply every required gate and phase from `SKILL.md` |

## Deviation guidance

Delegation is valid only when the user explicitly requests it or another
applicable rule requires it. Delegation does not change ownership of required
skill dependencies: the active parent session executes them.

## Profile inheritance notes

This standard extends the general DevOS skill-system rules. Child profiles may
add domain-specific gates but must preserve direct active-session execution.

## Compliance test

- [ ] Does the user-facing invocation load the skill into the active session?
- [ ] Does the active session execute the workflow directly?
- [ ] Do inter-skill dependencies stay in the same session?
- [ ] Are skill availability decisions independent of `$PATH`?
- [ ] Is completion grounded in tool output, artifacts, and verification rather than dispatch receipts?

If any check fails, correct the host or skill wording before declaring the
workflow complete.

## References

- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119)
- [DevOS self-contained-skills standard](./self-contained-skills.md)
