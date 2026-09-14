# User Flows Documentation Standard

Defines the required format and content for `docs/user-flows.md` in every DevOS-managed project.

## When to Use

Use this workflow to document user flows for a feature spec — capturing the step-by-step journey, decision points, and happy/sad paths before implementation begins.

Do not use this workflow for API documentation, architecture diagrams, or internal code documentation — it covers user-facing journey documentation only.


## Process

1. Identify the primary actor and entry point for the flow.
2. Map the happy path as a numbered step sequence.
3. Identify branching points and document alternate paths (error states, permission gates, edge cases).
4. Capture decision points with their conditions.
5. Review for completeness against acceptance criteria.
## Purpose

Every project must ship `docs/user-flows.md` — ASCII flowcharts of its main user-facing pipelines. This gives contributors immediate orientation to how the system works without reading command or workflow source files.

## Canonical Example

`docs/user-flows.md` in the dev-os repository is the canonical reference for format and depth.

## ASCII Format Requirements

### Allowed Characters

Use only these characters for drawing flow boxes and connectors:

| Character | Use |
|-----------|-----|
| `+` | Box corners and intersections |
| `-` | Horizontal lines |
| `\|` | Vertical lines |
| `/` | Diagonal connectors (left-to-right down) |
| `\` | Diagonal connectors (right-to-left down) |
| `v` | Downward arrow |
| `^` | Upward arrow |
| `<` | Leftward arrow |
| `>` | Rightward arrow |

No Mermaid syntax. No external renderer dependencies. Must render correctly in a monospace plain-text environment.

### Box Style

Decision points use slashes:
```
  Decision?
   /      \
 YES       NO
```

Process steps use vertical bars:
```
        |
        v
  Do something
        |
        v
```

Grouped sub-processes use box borders:
```
  +==============================+
  |  LOOP NAME                   |
  |    |                         |
  |    v                         |
  |  Step inside loop            |
  +==============================+
```

Gates and pauses use bordered boxes:
```
  GATE: Name
  +---------------------------+
  | What this gate checks     |
  +---------------------------+
  *** PAUSE — await user ack ***
```

## Required Sections

Every `docs/user-flows.md` must contain:

### 1. Top-Level Flow Map

A single ASCII diagram showing how all major flows connect to each other. Entry points, handoffs between flows, and the overall topology. Kept at a high level — no step detail here.

### 2. Individual Flow Sections

One section per major pipeline. Only commands/workflows with meaningful multi-step flows get their own section. Simple one-step commands do not need a section.

Each section must show:
- **Entry point** — the command or trigger
- **Decision branches** — every `YES/NO` or option fork
- **Key sub-steps** — named steps inside the flow (not every line of code, but every meaningful stage)
- **Outputs / artifacts** — what the flow produces
- **"Next" pointer** — what the user does after this flow completes

### 3. The "Golden Path" Section

A single end-to-end sequence showing the most common user journey from start to shipped. Kept brief — reference flow section names rather than repeating detail.

## Task Group Templates

Use these templates when injecting user-flows tasks into `tasks.md`.

### Template A — `docs/user-flows.md` does not exist

```markdown
### Documentation

#### Task Group N: User Flows Documentation
**Dependencies:** All other task groups
**Priority:** P2

- [ ] N.0 Create docs/user-flows.md
  - [ ] N.1 Identify all user-facing pipelines introduced or modified by this spec
  - [ ] N.2 Draw top-level flow map connecting all pipelines
  - [ ] N.3 Draw ASCII flowchart for each pipeline per user-flows-standard.md format
  - [ ] N.4 Add "Golden Path" section showing end-to-end happy path
  - [ ] N.5 Verify all flows are accurate against the implementation
```

### Template B — `docs/user-flows.md` already exists, spec adds new pipelines

```markdown
- [ ] N.0 Update docs/user-flows.md for new pipelines in this spec
  - [ ] N.1 Add ASCII flowcharts for [list new flows introduced by this spec]
  - [ ] N.2 Update top-level flow map if entry points or handoffs changed
  - [ ] N.3 Verify updated flows are accurate against the implementation
```

## When No Task Is Injected

If `docs/user-flows.md` already exists and the spec does not introduce any new user-facing pipelines (e.g., it is a purely internal refactor or config change), no user-flows task is added to tasks.md.

## Display Format

```
User Flow: [flow-name]
  Actor:     [user role]
  Entry:     [trigger / starting screen]
  Steps:     [N]
  Branches:  [N decision points]
  Paths:     happy path + [N] alternates
```
