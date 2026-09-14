# Autonomous Lifecycle Workflow

Session lifecycle operations for `autonomous`.

## When to Use

Use this workflow at the start of every `autonomous` invocation to route lifecycle flags (--status, --resume, --list) before beginning phase execution.

Do not call this workflow for non-autonomous commands or when lifecycle flags are absent and a fresh run is already in progress.

## Lifecycle Routing

Handle these modes before phase execution:

1. `--status` or `--summary`
   - run `auto_status`
   - display current session, phase, branch, and next action
   - exit
2. `--list`
   - run `list_auto_sessions`
   - display all known sessions
   - exit
3. `--pause`
   - run `auto_pause_session`
   - display pause confirmation
   - exit
4. `--abort`
   - confirm intent
   - preserve uncommitted work
   - run `auto_fail_session "User aborted"`
   - exit
5. `--continue`
   - use `{{workflows/implementation/find-session}}`
   - resume from the recorded phase

## Entry Point Detection

When no lifecycle-only mode is chosen, determine the starting route:

| Condition | Entry point | Notes |
|---|---|---|
| Active session state found | `continue` | Prefer recorded progress |
| `product/specs/<name>/tasks.md` exists | `tasks` | Start at implementation |
| `product/specs/<name>/spec.md` exists | `spec` | Start at review or tasking path |
| No artifacts found | `beginning` | Create a new autonomous session |

Honor explicit `--from <mode>` over auto-detection.

## Initialization

For a fresh `beginning` run:

1. initialize session state with `auto_init_session`
2. create or switch to the feature branch
3. create an initial checkpoint
4. display the goal, branch, entry point, and active flags

## Canonical Session Contract

All lifecycle operations read and write the same runtime file:

- primary: `.dev-os/runtime/session-state.yml`
- mirrors: `.dev-os/recovery/<spec>/session-state.yml` and `~/.dev-os/auto/sessions/<session-id>/session-state.yml`

Required execution fields:
- `session_mode`, `session_id`, `spec`, `goal`, `phase`, `status`
- `current_wave`, `wave_phase`, `wave_goal`, `wave_scope_claims`, `wave_status`
- `checkpoint_sha`, `last_update`, `next_action`
- `circuit_breaker_service`, `circuit_breaker_state`, `circuit_breaker_threshold`, `circuit_breaker_timeout`

## Lifecycle Guardrails

- If session state and repo artifacts disagree, stop and recommend `triage`.
- If the requested entry point skips missing prerequisites, stop and point to the missing command.
- If errors occur during lifecycle actions, pause before phase execution and preserve the branch state.
- Circuit-breaker open state is a hard stop. Pause the session, preserve the branch, and require either timeout expiry or operator intervention before retry.

## Display Format

```
Autonomous lifecycle: routing to [resume | status | fresh-start]
  Session: [session-name | none]
  Phase:   [current-phase | starting]
  Branch:  [branch-name | main]
```
