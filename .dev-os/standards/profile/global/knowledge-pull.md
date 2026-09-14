<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/knowledge-pull.md and re-run profile-sync. -->
# Knowledge Pull Standard

**Standard ID:** `knowledge-pull`
**Scope:** General (inherited by all profiles)
**Applies to:** Any command or workflow that produces AI-generated output whose correctness depends on current ecosystem knowledge

---

## Overview

Before generating output that depends on current ecosystem knowledge, DevOS must exhaust free and low-cost sources in order — cheapest first. This prevents stale training knowledge from entering specs, tasks, architecture decisions, workflow guidance, standards, documentation, code reviews, or implementation plans, while avoiding unnecessary paid MCP calls for information the connected LLM already knows well.

**The principle:** Knowledge costs money or confidence. Spend the cheap kind first.

---

## Scope

This standard covers AI-generated output in DevOS commands and workflows that depends on current outside knowledge: libraries, frameworks, SDKs, APIs, protocols, CLIs, MCP servers, model/provider behavior, services, package managers, deployment platforms, security practices, standards, current tool behavior, and current operator/user workflow guidance.

It does not cover pure local structure operations that can be answered entirely from the repository or filesystem: status checks, git staging/commits, file moves, local test execution, server lifecycle, and mechanical formatting. If a product decision, user-facing document, architecture choice, workflow, or standard depends on current ecosystem behavior, this standard applies.

---

## Principles

### 1. Cheapest source first

Knowledge has a cost in tokens, latency, or money. Local bundles are free and instant. Exhaust local and free tiers before making MCP calls or web searches.

### 2. Never trust stale training knowledge on moving surfaces

APIs, CLIs, provider behavior, agent platforms, MCP servers, deployment targets, security guidance, and framework practices change between minor versions and sometimes between weeks. Training knowledge is a starting point, not a source of truth.

### 3. Non-blocking on failure

A knowledge-pull failure MUST NOT block command execution. Log the failure and proceed with available knowledge.

### 4. Durable by default

Workflow knowledge pulls MUST save or reuse durable notes under `docs/references/` by default. Generated artifacts cite those notes through `knowledge_sources`. Ephemeral LLM context is allowed as a working copy, but it is not sufficient traceability for decisions that will outlive the current session.

---

## When This Standard Applies

Apply the knowledge-pull protocol whenever a command or workflow:

- Writes a spec, design, architecture brief, standard, workflow, or implementation plan touching named technologies, tools, providers, protocols, platforms, or current practices
- Generates task breakdowns that include technology-specific, provider-specific, workflow-specific, or standard-specific work
- Reviews code, docs, architecture, standards, or workflows that rely on current ecosystem behavior
- Implements features against a known tech stack, agent stack, provider stack, CLI stack, deployment stack, or operating workflow
- Generates documentation, runbooks, guides, references, or onboarding material that must reflect current behavior, commands, flags, constraints, or practices

**Does NOT apply to:**
- Commands that produce pure local structural output with no current-knowledge dependency (status checks, git operations, file moves)
- Commands the user has invoked with an explicit knowledge waiver, e.g. `--skip-knowledge-pull` or a legacy `--skip-docs`
- Runtime operations that only execute local state (test execution, server lifecycle, deployment) unless the operation generates guidance, remediation, docs, or plans based on current outside behavior

### Feature build preflight

A feature build is any request that creates or changes product behavior, user-facing workflow, CLI behavior, integration behavior, agent/runtime behavior, or deployable architecture. Before implementation begins, the workflow MUST have both:

1. **Knowledge evidence:** `/knowledge-pull` has run for the current feature targets, or the feature artifact records an explicit `knowledge_sources: waived` entry with a reason.
2. **Pinned architecture:** `/architecture-creator` has produced a pinned architecture artifact for the feature, usually `product/specs/<spec>/planning/architecture.md`.

Pinned architecture means the build cites a concrete architecture artifact path and treats that artifact as the implementation boundary for module seams, integration contracts, ADR candidates, and fitness checks. Reusing an older architecture is allowed only when the feature artifact names the existing path and states why it is still current for the active requirements.

This preflight follows the C4 Model for making system boundaries explicit, the ADR Pattern for preserving consequential decisions, and Evolutionary Architecture fitness functions for keeping implementation aligned with the pinned design. It is intentionally stricter than the general non-blocking knowledge-pull rule: if knowledge-pull sources fail, implementation may continue with a recorded knowledge waiver; architecture cannot be waived for feature builds.

---

## The Eight-Tier Fallback Chain

For each detected knowledge target, attempt sources in order. A target can be a library, API, framework, protocol, CLI, MCP server, service, model/provider, deployment platform, standard, or current practice area. **Stop at the first tier that returns usable content.** Local and free sources are exhausted before any paid search or synthesis.

### Tier 0 — Local Bundles *(fastest, free, zero-latency)*
Pre-compressed, versioned documentation bundles stored on disk. No network call, no MCP overhead. Covers libraries, APIs, protocols, services, and tools across multiple tier categories.

1. Check project overlays in order: `./bundles/bundle-manifest.json`, then `./.dev-os/bundles/bundle-manifest.json`.
2. Check the canonical global manifest `~/.dev-os/bundles/bundle-manifest.json`.
3. If the canonical global root or manifest is absent, read the legacy nested manifest `~/.dev-os/.dev-os/bundles/bundle-manifest.json` and report legacy fallback use. Never write it.
4. If found: read the bundle JSON file at the tier/filename path and extract `compressed_docs`.

→ If library not in the active manifests: fall through to Tier 1

**Bundle location:** `<active-root>/<tier>/<lib>@<version>.json` (canonical global: `~/.dev-os/bundles/`)
**Manifest:** `<active-root>/bundle-manifest.json` (canonical global: `~/.dev-os/bundles/bundle-manifest.json`)
**Cost:** Zero. No network, no MCP call. Always check first.
**Staleness:** Bundles have `refresh_days` (default 30) and `last_refreshed` timestamps in the manifest. If a bundle is older than `refresh_days`, treat as stale — fall through to Tier 1 and note `(Local bundle — stale, verified via Context7)`.

**Bundle tier categories:**

| Tier | Name | Contents |
|------|------|----------|
| `tier0_platform` | Platform Documentation | Claude Code, Codex CLI, Gemini CLI, etc. |
| `tier0_skills` | Universal Skills | agent-browser, best practices, design guidelines |
| `tier1_core` | Critical Frameworks | Next.js, React, Tailwind, Convex, shadcn, Motion |
| `tier1_auth` | Authentication Providers | Clerk |
| `tier2_state` | State Management | Zustand, TanStack Query, Jotai, React Hook Form, Zod |
| `tier2_sdk` | AI/LLM SDKs | Anthropic SDK, Vercel AI SDK, OpenAI SDK, PostHog |
| `tier3_database` | Backend/Database | Drizzle, Supabase, FastAPI, Hono |
| `tier3_testing` | Testing Frameworks | Vitest, Playwright |
| `tier4_apis` | API Documentation | REST APIs, webhook specs, service endpoints |
| `tier5_other` | Protocols & Other | Protocol specs, standards, tool configs |

`tier4_apis` and `tier5_other` are created on demand by `knowledge-pull --bundle`.

### Tier 1 — llms.txt *(free, LLM-native)*
The llms.txt standard (`llmstxt.org`) is a growing convention where libraries publish LLM-optimized documentation at their domain root. Jina Reader fetches and parses it for free.

```
0. Canonical docs discovery
   → If the library domain is ambiguous, search the official docs site first
   → Prefer the canonical documentation hostname over repo mirrors or marketing domains
   → Example: resolve the product docs site before calling llms_check(domain=...)

1. mcp__jina-reader__llms_check(domain=<lib-domain>)
   → If no llms.txt found: fall through to Tier 2

2. mcp__jina-reader__llms_fetch(domain=<lib-domain>)
   → Returns structured index with title, summary, and linked resources
   → For deeper docs: mcp__jina-reader__llms_fetch_full(domain=<lib-domain>, max_pages=5)
   → Log as (llms.txt <domain>)
```

**Common domains:** `nextjs.org`, `react.dev`, `tailwindcss.com`, `clerk.com`, `supabase.com`, `convex.dev`, `zod.dev`, `drizzle.team`, `hono.dev`
**Cap:** 3 llms.txt fetches per invocation.
**Cost:** Zero. Jina Reader is free.
**When to use `llms_fetch_full`:** When the topic requires detail beyond the index (e.g., specific API patterns, migration guides). The full fetch retrieves linked pages (capped at `max_pages`).

### Tier 2 — Context7 *(structured, free)*
Versioned, structured, purpose-built for code documentation. No per-call financial cost beyond MCP overhead.

```
1. mcp__context7__resolve-library-id(libraryName=<lib>)
   → on no match: fall through to Tier 3

2. mcp__context7__query-docs(libraryId=<id>, query=<topic>, tokens=3000)
   → on error or empty result: fall through to Tier 3
```

**Cap:** 3 Context7 calls per command invocation (aligns with CLAUDE.md global rule).

### Tier 3 — GitHub Docs via `github-docs` skill *(free)*
Delegate to `/github-docs --library <lib>`, `/github-docs --repo <owner>/<repo>`, or `/github-docs --auto-detect`. Extract the returned compressed bundle and log `(GitHub <owner>/<repo>)`; if no repository is identifiable, fall through to Tier 4. Do not call raw GitHub MCP file tools directly.

### Tier 4 — Web Scraping + Brave *(free)*
Use `mcp__jina-reader__read_url` for known static URLs, `mcp__crawl4ai__c4ai_scrape` for JS-heavy sites, or Brave's `brave_llm_context` / `brave_web_search` for free search. Extract relevant markdown and log `(Jina <url>)`, `(Crawl4ai <url>)`, or `(Brave <query>)`; if no useful content, fall through to Tier 5.

### Tier 5 — LLM Deep Research *(free)*
Prompt: `"What are the current best practices and API signatures for <library> <topic> as of your knowledge cutoff? Flag anything you are uncertain about."` Use high-confidence results as `(LLM knowledge)`; if uncertain, niche, or post-cutoff, fall through to Tier 6.

### Tier 6 — Exa Neural Search *(paid)*
Use `mcp__exa__exa_search(query="<library> <topic> API", type="neural", getText=true)` for semantic search or `mcp__exa__exa_answer(query="<library> <topic> current API usage")` for cited API answers. If no usable content, fall through to Tier 7.

### Tier 7 — Connected LLM Synthesis *(paid, last resort)*
Route through the provider-aware dispatch helper (`scripts/lib/agent-runtime-dispatch.sh`; `codex` default, `claude` fallback) to synthesize an answer from gathered context. Use only when Tiers 0–6 fail or return low-confidence signal; log the resulting source and durable note metadata.

---

## Library Detection

Two signals are combined and deduplicated. Cap at **10 library candidates** per command invocation (override with `DEVOS_LIBRARY_CAP` env var).

**Signal A — Project files** (scan in order, stop after first match per file type):
- `package.json` — dependencies + devDependencies
- `requirements.txt`
- `go.mod`
- `Cargo.toml`
- `.dev-os/config.yml` — profile field maps to canonical stack

**Signal B — Command input** (the user's feature description, spec title, or task statement):
- Scan for known library names and apply alias resolution
- Alias map lives in `scripts/lib/fetch-docs.sh` (`LIBRARY_ALIASES`)
- Priority: libraries most central to the stated feature come first

---

## Non-Blocking Behavior

**The knowledge-pull step must never cause a command to fail.** Every failure mode has a defined fallback.

| Condition | Behavior |
|-----------|----------|
| Local bundle found (fresh) | Use + log as `(Local bundle <version>)` |
| Local bundle found (stale) | Use as baseline, fall through to Tier 1 for verification |
| Library not in bundle manifest | Fall through to Tier 1 |
| llms.txt found via Jina | Use + log as `(llms.txt <domain>)` |
| No llms.txt at domain | Fall through to Tier 2 |
| Tier 2 returns docs | Use + log as `(Context7 <libraryId>)` |
| Library not in Context7 | Fall through to Tier 3 |
| GitHub docs found | Use + log as `(GitHub <org>/<repo>)` |
| GitHub repo not identifiable | Fall through to Tier 4 |
| Jina/Crawl4ai scrape returns docs | Use + log as `(Jina <url>)` or `(Crawl4ai <url>)` |
| Brave search returns results | Use + log as `(Brave <query>)` |
| Scrape/Brave fails or URL unknown | Fall through to Tier 5 |
| LLM returns high-confidence patterns | Use + log as `(LLM knowledge — high confidence)` |
| LLM signals low confidence | Fall through to Tier 6 |
| Exa returns a usable answer | Use + log cited source URL(s) |
| Exa fails or returns low confidence | Fall through to Tier 7 |
| Connected LLM synthesis succeeds | Use + log provider/source metadata |
| Durable note exists and is fresh | Reuse note, cite path in `knowledge_sources`, emit telemetry |
| Durable note is stale | Refresh from the eight-tier chain, then overwrite note with current metadata |
| All eight tiers fail for a target | Log `(not found)` — skip that target, continue |
| All tiers fail for all targets | Set output field to `none (all sources unavailable)` |
| No targets detected | Set output field to `none (no current-knowledge targets detected)` |
| `--skip-knowledge-pull` or legacy `--skip-docs` flag present | Skip entire step, set field to `waived`, record waiver reason when available |

---

## Output Contract

Every command that applies this standard must save or reuse durable notes under `docs/references/` and append a `knowledge_sources` block to its primary output artifact. The `knowledge_sources` entry points at the durable note so future sessions can inspect or refresh the decision context. The format varies by artifact type:

### Spec / plan headers (`spec.md`, `requirements.md`)
```markdown
**knowledge_sources:**
  - react — "hooks and server components" (2026-04-15, Local bundle 19.0.0, note: docs/references/react-hooks-server-components.md)
  - next.js — "server actions" (2026-02-26, Context7 /vercel/next.js, note: docs/references/next-js-server-actions.md)
  - convex — "file mutations" (2026-02-26, LLM knowledge — high confidence, note: docs/references/convex-file-mutations.md)
  - stripe — "webhook signing" (2026-02-26, GitHub stripe/stripe-node README, note: docs/references/stripe-webhook-signing.md)
  - some-niche-lib — "obscure api" (2026-02-26, Web https://lib-docs.example.com, note: docs/references/some-niche-lib-obscure-api.md)
```

### Task lists (`tasks.md`)
Add as a comment block at the top:
```markdown
<!-- knowledge_sources: next.js (Context7, docs/references/next-js-server-actions.md), convex (LLM, docs/references/convex-file-mutations.md), stripe (GitHub, docs/references/stripe-webhook-signing.md) -->
```

### Code review output
Add as a footnote section:
```markdown
---
**Knowledge sources consulted:** convex (Context7 /get-convex/convex-backend, docs/references/convex-backend.md), react (LLM, docs/references/react.md)
```

---

## Applying This Standard in Workflows

Use the shared workflow snippet via:

```
{{workflows/_shared/knowledge/knowledge-pull-step}}
```

This resolves through the profile inheritance chain to `profiles/general/workflows/_shared/knowledge/knowledge-pull-step.md`.

> **Note:** `{{standards/global/knowledge-pull}}` is NOT a valid template directive — the template processor only handles `{{workflows/...}}` and `{{include ...}}` patterns. Always use the shared snippet reference above, or inline the step block verbatim.

For inline usage (when a direct snippet reference is not appropriate):

```markdown
## Step 0: Knowledge Pull

Apply the DevOS knowledge-pull standard (profiles/general/standards/global/knowledge-pull.md):
1. Detect libraries from project files and the feature description (cap 10)
2. For each library, run the eight-tier fallback chain (Local Bundles → llms.txt → Context7 → GitHub → Web scraping + Brave → LLM → Exa → connected LLM synthesis)
3. Save or reuse durable notes under docs/references/
4. Summarize current patterns in working context from the durable notes
5. Prepare knowledge_sources entries for the output artifact header, including note paths
6. Emit telemetry to product/runtime/knowledge-pull-telemetry.jsonl
```

**Field placement:** `knowledge_sources` is written as bold markdown body text in the spec header (consistent with existing DevOS spec metadata format — `**Status:**`, `**Profile:**`, etc.). It is NOT placed in YAML frontmatter.

**Durable note format:** Notes live at `docs/references/<target-slug>.md` and include metadata (`Pulled`, `Source`, `Freshness`, source URL or bundle/version), key patterns, quick reference, examples when applicable, and sources.

---

## Commands That Apply This Standard

| Skill | When applied | Output field |
|---------|-------------|--------------|
| `write-spec` | Before writing spec content | Durable notes + `knowledge_sources:` in spec.md header |
| `autonomous` | Planning phase (before shape-spec) | Durable notes + `knowledge_sources:` in spec.md header |
| `create-tasks` | Before generating task breakdown | Durable notes + comment block at top of tasks.md |
| `review` | Before code review analysis | Durable notes + footnote in review output |
| `implement-tasks` | Before each task group implementation | Durable notes + task/session note reference |
| `feature-delivery` / feature build workflows | Before implementation begins | Durable notes + pinned `planning/architecture.md` path |

---

## Related Standards

- `global/runtime-standards.md` — canonical runtimes for project stacks
- `global/shell-safety.md` — shell command safety rules
- `scripts/lib/fetch-docs.sh` — library detection and alias resolution helpers
- `architecture-creator` skill — creates pinned architecture artifacts using C4, ADR candidates, and fitness functions before feature implementation

---

## Telemetry

Every knowledge-pull invocation emits one JSONL line to `product/runtime/knowledge-pull-telemetry.jsonl`. This enables the designer feedback loop: tier hit rates, failure patterns, and skip frequency are reviewable via `monthly-retro`.

**Schema:**
```json
{"ts": "<ISO-8601>", "command": "<invoking command>", "targets": ["react", "convex"], "tiers_hit": {"react": "local_bundle", "convex": "context7"}, "durable_notes": {"react": "docs/references/react.md", "convex": "docs/references/convex.md"}, "skipped": false, "all_failed": []}
```

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `ts` | string | ISO-8601 timestamp |
| `command` | string | Invoking command (e.g., `write-spec`, `create-tasks`, `review`) |
| `targets` | string[] | Knowledge targets detected |
| `tiers_hit` | object | Map of target → tier that succeeded (`local_bundle`, `context7`, `llm`, `github`, `web`) |
| `durable_notes` | object | Map of target → saved or reused note path under `docs/references/` |
| `skipped` | boolean | True if `--skip-knowledge-pull` or legacy `--skip-docs` was passed |
| `all_failed` | string[] | Targets where all tiers failed |

**Skip entry:** When `--skip-knowledge-pull` or legacy `--skip-docs` is passed, emit: `{"ts": "...", "command": "...", "skipped": true, "waiver": "<reason if known>"}`

**Downstream consumers:**
- `monthly-retro` — reads telemetry to report tier hit rates and propose KNOWN_GOOD_LIBRARIES updates
- `health` — counts all-failed entries as a health signal
- `triage` — surfaces high skip rates as a finding

---

## Enforcement

Commands that produce spec or plan output should include a verification step that checks for the `knowledge_sources` field. The `verify-spec.md` workflow checks for its presence and logs a warning (not error) if absent.

---

## Anti-Patterns

| Anti-pattern | Consequence |
|---|---|
| Calling Context7 when a local bundle exists for the library | Unnecessary MCP overhead — local bundles are faster and free |
| Calling Context7 for every command | Unnecessary latency and token cost when LLM knowledge is sufficient |
| Skipping knowledge-pull entirely on versioned API usage | Stale syntax errors in generated code |
| Using ephemeral `--llm` only for workflow decisions | No future traceability for why a decision was made |
| Blocking command execution on knowledge-pull failure | Violates the non-blocking principle |
| Querying Context7 more than 3 times per question | Diminishing returns, cost inefficiency |
| Ignoring bundle staleness (refresh_days exceeded) | Using outdated documentation without verification |
| Starting a feature build without a pinned architecture artifact | Implementation invents module boundaries and integration contracts mid-build |

---

## Compliance Test

Before shipping a command or workflow that applies this standard, verify all of the following:

- [ ] Does the command check local bundles before calling Context7?
- [ ] Does the command try LLM knowledge before calling Context7 (for libraries not in bundles)?
- [ ] Is Context7 called no more than 3 times per workflow?
- [ ] Does a knowledge-pull failure log a warning but continue execution?
- [ ] Does workflow knowledge-pull save or reuse `docs/references/<target>.md`?
- [ ] Is the knowledge source noted in generated artifacts that rely on current ecosystem knowledge?
- [ ] For feature builds, does the artifact cite `/knowledge-pull` evidence or an explicit knowledge waiver?
- [ ] For feature builds, does the artifact cite a pinned `/architecture-creator` artifact path?

---

## References

- `./bundles/bundle-manifest.json` and `./.dev-os/bundles/bundle-manifest.json` — project-local overlay manifests
- [Context7 MCP documentation](https://context7.com) — structured library docs (Tier 1)
- `runtime-standards.md` (sibling) — defines the canonical tech stack Context7 should be queried against
- `scripts/lib/fetch-docs.sh` — library detection, alias resolution, caching helpers
- `~/.dev-os/bundles/bundle-manifest.json` — canonical global bundle manifest (Tier 0)
- `~/.dev-os/.dev-os/bundles/bundle-manifest.json` — read-only compatibility fallback only when canonical global root/manifest is absent
- This standard (`knowledge-pull`) is referenced by the `write-spec`, `implement-tasks`, and `autonomous` skills (`.claude/skills/<name>/SKILL.md`)
