# gap-analysis Agent Design Notes

## Purpose

`gap-analysis` is a built-in DevOS agent projection used by the `gap-analysis` skill for bounded evidence passes. It lives in `profiles/default/agents/` so every profile inheriting from `default` receives the projection during profile activation.

## Source Of Truth

Profile activation treats project `.dev-os/agents/` as a generated mirror. Do not edit the generated copy first. Update this profile source, then re-run profile activation.

## Boundary

The agent analyzes only. The parent skill owns convergence, `--fix`, specs/tasks, registry updates, implementation handoff, and commits.
