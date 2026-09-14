# KIMI.md — DevOS Context for Kimi CLI

This project uses **DevOS** (Development Operating System) for standardised
AI-assisted development workflows.

<!-- DEVOS_PROJECT_BRIEF_START -->
## Project Brief

Full guidance: `docs/context/DEVOS_PROJECT_GUIDANCE.md`

- **Project Purpose:** Define the mission and product goals.
- **Install Topology:** DevOS profile `cli`; project config lives in `.dev-os/config.yml`.
- **Tech Stack:** Primary implementation language is Rust.
- **Development Commands:** Run tests with `cargo test`.
- **Architecture Anchors:** `docs/context/codebase-map.md` describes file roles and hotspots; start there.
- **Operating Rules:** Before removing or overwriting config files, create a backup first
- **Operating Rules:** Never bulk-delete files without explicit approval
- **Operating Rules:** Do not commit secrets (`.env`, credentials, API keys) to git
- **Operating Rules:** Before staging files for a commit, verify they are inside the git repository root
- **Operating Rules:** Do not force-push to main/master
- **Operating Rules:** Project is prelaunch: prefer forward-compatible simplification; no legacy shims unless explicitly requested.
- **Operating Rules:** Preserve user-authored content outside DevOS managed blocks.
- **Gotchas:** No gotcha signal detected yet; record traps here as they surface.
<!-- DEVOS_PROJECT_BRIEF_END -->

## Available DevOS Commands

- `write-spec` — Write technical specifications
- `create-tasks` — Break specs into actionable tasks
- `implement-tasks` — Execute implementation tasks
- `review` — Code review with quality checks
- `project-status` — Show implementation progress
- `quick-fix` — Apply small fixes without full spec workflow
- `merge-feature` — Merge feature branch with changelog update
- `checkpoint` — Save implementation progress checkpoint

## MCP Servers

The following MCP servers are configured via DevOS
(`product/runtime/reports/kimi-mcp-config.json`):

- `memory`
- `memory-http`
- `playwright`
- `reflection`
- `remotion`
- `tolaria`

## Skills

DevOS skills use the standard Kimi Code discovery surface; no undocumented
`--skills-dir` flag is assumed.

- Full registry: `docs/context/DEVOS_SKILLS_INDEX.json`
- Discover and load a skill with `find-skills` or from `~/.dev-os/integrations/kimi/skills`

## Workflows

Standard DevOS workflow for a new feature:

```
write-spec   →  create-tasks  →  implement-tasks
      →  review  →  merge-feature
```

## Configuration

- **Profile**: Defined in `.dev-os/config.yml`
- **MCP config**: `~/.kimi-code/mcp.json` for Kimi Code; `~/.kimi/mcp.json` is legacy-only
- **Skills**: Native shared skills at `~/.agents/skills`; integration mirror at `~/.dev-os/integrations/kimi/skills`
- **DevOS docs**: `~/.dev-os/docs/`

<!-- DevOS:section:skill-invocation -->
## Skill Invocation Contract

DevOS capabilities are registry-routed skills, not executables or shell commands.
When a skill is invoked, read its `SKILL.md` and execute the workflow directly in
the current active session.

- A line such as `map --update` is a **skill invocation with arguments**. Do not
  search for a binary, runner, wrapper, `runner.sh`, `run.sh`, or `map.sh`.
- Bare names are not `$PATH` commands. Never use `command -v`, `which`, or bare
  `--help` to decide availability. Resolve `docs/context/DEVOS_SKILLS_INDEX.json`;
  an absent registry entry is unavailable.
- Use only flags and positional arguments declared by `SKILL.md` or the called
  helper's parser. Never invent flags or confuse accepted arguments with
  downstream arguments.
- The active session owns the full workflow. For an inter-skill dependency,
  read the target skill and continue executing its instructions in the same
  session. Do not look for a dispatch API, submit a nested slash command, or
  require a dispatch receipt.
- A delegated worker cannot invoke parent-session skills or probe `$PATH`. It
  returns `dependency_required` with the exact skill, arguments, dependent gate,
  and artifact. The active session then executes that dependency directly.
- Explicit skill or autonomous intent suppresses only a redundant generic
  confirmation. Present named operator/human/policy gates verbatim; never
  self-approve them.
- A script named by `SKILL.md` is a helper step, not a substitute for the skill.
  Run helpers only as instructed. Source DevOS shell libraries under Bash:
  `bash -lc 'source "$DEVOS_DIR/scripts/lib/<lib>.sh" && <fn>'`.
- In OMP, `/skill:<name> [args]` is the user-facing entry that loads a skill into
  the current session. `skill://<name>` only reads instructions.
- Execution evidence is the current session's tool output, artifacts, and
  required verification. Never fabricate provenance or claim success from a
  read alone.
<!-- /DevOS:section:skill-invocation -->
