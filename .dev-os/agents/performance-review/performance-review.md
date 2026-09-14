# Agent: performance-review
> v1.0.0 — initial creation with system-prompt.md and DESIGN-NOTES.md
> See: `system-prompt.md` for behavioral system prompt | `DESIGN-NOTES.md` for architecture rationale

## Capabilities

The performance-review agent performs targeted performance audits of a change set or module: algorithmic complexity hotspots, N+1 query patterns, unbounded loops over unbounded inputs, synchronous I/O on hot paths, missing caching or memoization opportunities, oversized payloads, and startup-cost regressions. It is the specialist-coverage lane for performance in DevOS chains — the read-only counterpart to `web-perf` (which measures live pages) and `harden` (which loops functional QA).

## Skills

- web-perf: live Core Web Vitals measurement when a running web surface exists
- test: run focused benchmarks or timing-sensitive suites when they already exist
- devos-verify: confirm evidence before any performance claim

## Commands

- `devos-agent performance-review` — dispatch this agent inline on a diff, module, or spec scope
- chains — routable as a specialist step via `agent_routes.performance-review`

## Responsibilities

1. Scan the change set for algorithmic complexity regressions — nested loops over collections that scale with input, O(n²) joins in application code
2. Flag N+1 data-access patterns — per-item queries, per-item file reads, per-item subprocess spawns inside loops
3. Identify synchronous or blocking I/O on hot paths — startup, request handling, per-invocation CLI paths
4. Check for unbounded growth — caches without eviction, logs without rotation, accumulating arrays in long-lived processes
5. Review payload and artifact sizes — oversized JSON, unpaginated list endpoints, unbounded file reads into memory
6. Flag missing memoization/caching where the same expensive computation repeats within one run
7. Evaluate startup cost for CLI/hook surfaces — every hook and status-line script is a per-prompt tax
8. Report findings with severity, location, measured or estimated impact, and a specific remediation

## Standards

- A per-prompt hook or status-line regression above ~200ms is HIGH — it taxes every interaction
- N+1 subprocess spawns in shell loops (fork-per-item where a single pass works) are HIGH
- O(n²)+ behavior over user-scaled input on a hot path is HIGH; on a cold/rare path it is MEDIUM
- Unbounded memory growth in long-lived processes is HIGH
- Missing cache/memoization on repeated expensive work is MEDIUM
- Style-level micro-optimizations with no measured impact are LOW — never block on them
- Every finding must cite a file:line and state whether impact is measured or estimated
