<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/vibe-skill-writing-standard.md and re-run profile-sync. -->
# Vibe Skill Writing Standard

**Derived from:** Production-tested skills in `01-vibe-marketing-skills/`
**Applies to:** Any skill intended to produce expert-level domain output

This standard defines how to write skills that consistently produce high-quality output in production. It supplements `skills-standards.md` (structural requirements) with content-level requirements derived from real skill performance.

---

## The 10-Element Skill Structure

A production-quality skill has exactly these 10 elements in order:

| # | Element | Purpose |
|---|---------|---------|
| 1 | Philosophical hook | Sets Claude's worldview before any instruction |
| 2 | Core job + output format | Defines "done" before describing "how" |
| 3 | Decision gate / mode split | Routes to correct path before any generation |
| 4 | Context gathering steps | Forces information collection before output |
| 5 | Named frameworks with conditions | Gives Claude credible reasoning, not just instructions |
| 6 | Generator library | Menu of named approaches with "works when" conditions |
| 7 | Prescriptive output format | Template shown as literal fill-in-the-blank |
| 8 | Full worked example | Sets the quality bar through a realistic complete output |
| 9 | Skill wiring | States upstream inputs and downstream consumers |
| 10 | The test | 4-5 verifiable quality gates before delivery |

---

## Required Writing Rules

### Hook
- Must reframe WHY the conventional approach fails — not introduce the skill
- 3-5 sentences maximum
- Should make the reader think "yes, that's exactly the problem"

### Core job
- One sentence stating the deliverable, not the method
- Output format listed immediately — number of items, each field named
- No hedging — "outputs 3-5 positioning options" not "can help generate positioning"

### Decision gate
- Binary or 3-way at most
- Each mode has: Use when / Process / How to choose
- The selection question must be something Claude can literally ask the user

### Context gathering
- Numbered steps
- Each step has a clear data point to collect and why it changes the output
- Placed BEFORE any generation instructions — not after

### Frameworks
- Must be named (Schwartz, Hormozi, Dunford, Bridge Principle, etc.)
- Each framework: 2-sentence explanation + how it applies to THIS skill's task
- Include conditions: "use this framework when [market condition]"

### Generator library
- Each approach gets a name (The Contrarian Angle, The Shortcut Hook, etc.)
- Pattern: what it is → example output → "Works when:" condition
- Minimum 5 named approaches for output-generation skills

### Output format
- Shown as a filled template in a code block — not described
- Every field labeled with what content belongs there
- Ends with "Recommended starting point" field

### Worked example
- Must use a realistic scenario (not "Product X" or "Business Y")
- The example output should be shippable as-is
- Shows the complete format, not abbreviated

### Skill wiring
- States which skill(s) feed into this one
- States which skill(s) consume this one's output
- Shows the exact chaining instruction Claude would use

### The test
- Exactly 4-5 criteria
- Each criterion is a yes/no question, not a vague quality check
- Ends with what to do if any answer is no

---

## `references/` Usage Rules

Move content to `references/` when:
- It's a full named framework (Dunford, Schwartz, Hormozi) with extended detail
- It's a library of examples by category (format examples, industry examples)
- It's foundational psychology or research
- Reading it adds value for deep work but slows down quick tasks

Keep content in `Skill.md` when:
- It's needed on every invocation
- It's a decision gate or routing logic
- It's the output format or quality test

---

## Scope Discipline

Before writing a skill, complete:

> "This skill produces **[specific artifact]** so that **[downstream use]**. It does NOT **[most tempting adjacent thing]**."

If the sentence requires "and" — split into two skills.

Every skill must have a "What this skill is NOT" section that names the adjacent skills explicitly.

---

## Research-Dependent Skills

Any skill that depends on external data (SERP results, competitor intelligence, live metrics, news, market data) must implement the Research Quality Signal protocol.

### Two States

**LIVE** — web search or MCP tools are available:
```
RESEARCH MODE
├── Web search      ✓ connected
├── Sources accessed:
│   ├── [source 1]
│   ├── [source 2]
│   └── [N more sources]
└── Data quality: LIVE
```

**ESTIMATED** — no live tools available:
```
RESEARCH MODE
├── Web search      ✗ not available
├── Data quality: ESTIMATED
│   Using conceptual analysis based on context
│   and training data. Results are directional,
│   not verified.
└── To upgrade:
    → Connect a web search MCP server
    → Or proceed — estimates flagged with ~
```

### Rules

- Show the research signal block **before content begins, after the skill header** — never at the end
- If LIVE: list sources accessed, mark data quality LIVE, proceed
- If ESTIMATED: show the signal block, ask the user before proceeding with estimates
- When proceeding with estimated data: prefix all research-dependent claims with `~`
  - Example: `~2,400 monthly searches` vs `2,400 monthly searches`
- Flag high-risk estimates: `(Estimated — verify with live SERP check)`
- **Never silently fall back** to estimated data — always show the signal and ask

### Writing Rule

The research signal block is not optional for research-dependent skills. A skill that uses estimated data without disclosure produces misleading output. The signal block is a trust contract with the user.

Reference: `research-quality-signal-protocol-framework.md`

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Generic intro paragraph | Claude has no frame before instructions | Replace with philosophical hook |
| "This skill helps with X" | Vague scope | State exact artifact produced |
| Unnamed frameworks | Claude can't reason about when to apply them | Name every framework used |
| Output described not shown | Claude invents format | Show template in code block |
| Toy example ("Company X sells widgets") | Sets low quality bar | Use realistic, shippable example |
| No test section | Claude stops at "good enough" | Add 4-5 verifiable quality gates |
| Skill does 2 things | Dilutes focus, harder to chain | Split into two skills |
| References folder missing | Main file bloated with deep content | Move framework detail to references/ |
| Silent data quality degradation | Skill uses estimated data without disclosure | Always declare LIVE or ESTIMATED before content (see Research-Dependent Skills) |

---

## Applies alongside

- `skills-standards.md` — structural requirements (frontmatter, version, required sections)
- `skill-content-standards.md` — content completeness rules
- `skills-authoring-best-practices.md` — general authoring guidance

This standard adds the *quality pattern* that makes skills perform in production, not just pass validation.
