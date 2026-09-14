## Design Approach Library

When shaping a spec, select the approach pattern that best fits the problem type. Name the selected approach explicitly in the spec's Approach section.

### Component-First Design

Name each component, define its single responsibility, specify its interface (inputs/outputs), and identify its dependencies. Then show how they connect.

> "UserAuthService receives credentials → validates against UserStore → returns session token to AuthController → AuthController sets cookie via SessionMiddleware."

**Use when:** Building a new subsystem with multiple interacting parts. Weak component boundaries are the most common source of implementation failure.

---

### Data-Flow Design

Trace data from trigger to final state. Name each transformation: what comes in, what changes, what goes out. Identify where data is persisted, validated, or transformed.

> "Form submit → validate schema → sanitize inputs → write to DB → emit event → notify subscribers → update UI."

**Use when:** The core question is "what happens to this data?" — payment flows, import pipelines, form processing, async jobs.

---

### Incremental Milestone Design

Decompose into milestones where each milestone is a working, shippable state. Define what "done" looks like at each stage.

> "M1: Basic CRUD with hardcoded auth. M2: Real auth + roles. M3: Notifications. M4: Export. Each milestone is deployable."

**Use when:** The project is large enough that shipping in phases reduces risk. Identifies the minimum useful version early.

---

### Constraint-First Design

Surface constraints before proposing anything: performance budgets, API limits, team conventions, backwards-compatibility requirements. Let constraints eliminate approach options before designing the solution.

> "Constraint: must work offline. Eliminates: server-rendered UI, real-time sync, direct DB calls. Narrows to: local-first with sync queue."

**Use when:** Technical or business constraints are load-bearing. Designing without constraints produces elegant solutions that break in production.

---

### Trade-off Comparison

Present 2-3 named approaches with explicit trade-offs. Lead with the recommended option. Each approach: what it is, why it works, what it costs, when to pick it.

> "Option A (recommended): Server-side rendering — SEO-ready, simpler caching, harder to add real-time later. Option B: SPA — easy real-time, complex SEO, higher JS bundle. Option C: Islands — balanced, higher complexity."

**Use when:** Multiple architecturally different approaches are genuinely viable and the trade-offs are non-obvious. The comparison is the design.

---

### Existing-Pattern Extension

Read the codebase, identify the dominant pattern, and extend it. The design explains how new work fits established conventions — and where targeted improvements to problematic code are worth including.

> "Auth follows the handler/service/repo pattern. New feature: add NotificationHandler → NotificationService → NotificationRepo. Flag: UserService has grown too large — split UserAuthService out as part of this work."

**Use when:** Working in an existing codebase where consistency matters more than architectural purity.
