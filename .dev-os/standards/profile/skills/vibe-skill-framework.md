<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/vibe-skill-framework.md and re-run profile-sync. -->
# Vibe Skill Framework

**Extracted from:** `01-vibe-marketing-skills/` — brand-voice, positioning-angles, lead-magnet, content-atomizer, email-sequences, newsletter, direct-response-copy
**Source:** Real-world tested skills with confirmed production results
**Extracted:** 2026-02-20
**Status:** Active

---

## What This Framework Is

A repeatable blueprint for writing AI skills that consistently produce expert-level output. Derived by reverse-engineering 7+ marketing skills that work in production — not from theory, but from what the live outputs look like.

The framework has 10 structural elements. Every skill that works follows all 10. Skills that underperform typically skip 3-5 of them.

---

## The 10 Elements

### 1. Philosophical Hook (3-5 sentences)

Opens by reframing why the conventional approach fails — not an intro paragraph, a provocation.

**Pattern:** `[Common thing people do] [doesn't work / works for the wrong reason]. [Reframe that explains WHY]. [The skill's purpose stated as a consequence of the reframe].`

**Example (brand-voice):**
> "Generic copy converts worse than copy with a distinct voice. Not because the words are different—because the reader feels like they're hearing from a PERSON, not a marketing team. This skill defines that voice."

**Example (positioning-angles):**
> "The same product can sell 100x better with a different angle. Not a different product. Not better features. Just a different way of framing what it already does. This skill finds those angles."

**Why it works:** Sets Claude's worldview before any instructions. Claude enters the task with the right mental frame, not a neutral one.

---

### 2. The Core Job (1 paragraph + output format)

One crisp statement of what the skill produces. Immediately followed by the exact output format.

**Pattern:**
```
## The core job

[Single sentence stating the deliverable, not the method.]

Output format: **[N] distinct [thing]**, each with:
- [Element 1]
- [Element 2]
- [Element 3]
- [Element 4]
```

**Why it works:** Claude knows what "done" looks like before reading a single instruction. Prevents open-ended wandering.

---

### 3. Decision Gate / Mode Split

Before doing any work, route the user to the correct path. Always presented as a binary or small set of modes with clear selection criteria.

**Pattern:**
```
## Two modes  [or: N approaches / The process]

### Mode 1: [Name]
**Use when:** [Specific condition]
**Process:** [What happens in this mode]

### Mode 2: [Name]
**Use when:** [Specific condition]
**Process:** [What happens in this mode]

**How to choose:**
Ask: "[Decision question]"
- [Answer A] → Mode 1
- [Answer B] → Mode 2
```

**Why it works:** Prevents Claude from blending approaches. Forces context-gathering before output generation.

---

### 4. Context Gathering Steps (before generating)

Explicit "understand this before you do anything" section. Numbered steps, each with a clear question or data point to collect.

**Pattern:**
```
## Before generating: Understand the context

### Step 1: Identify [X]
[What to ask or assess. Why it matters to the output.]

### Step 2: Identify [Y]
[What to ask or assess.]

### Step 3: Identify [Z]
[What to ask or assess.]
```

**Why it works:** Prevents premature generation. Claude that generates without context produces generic output.

---

### 5. Named Frameworks Embedded Inline

Domain expertise isn't described generically — it's attached to specific named models with attribution. Each framework is explained just enough to apply it, not to teach it.

**Pattern:**
```
### [Framework Name]

[1-2 sentence explanation of the model]

[How it applies to the specific task, with concrete examples]

**[Implication for output]:** [What this framework tells Claude to do differently]
```

**Examples used across skills:**
- Schwartz's 5 stages of market sophistication → which angle type to use
- Hormozi's value equation → how to evaluate lead magnet quality
- Dunford's positioning methodology → what to ask to find the unique mechanism
- Bridge Principle (coined internally) → lead magnet must logically connect to paid offer

**Why it works:** Named frameworks give Claude a credible reason for a decision, not just an instruction. The output becomes defensible, not arbitrary.

---

### 6. Generator / Angle Library

A structured list of approaches with named types, patterns, examples, and conditions for use. This is the "when to use which tool" section.

**Pattern:**
```
#### The [Name] Approach
[What it is — 1 sentence]

> "[Example output pattern]"

Works when: [Specific market/audience conditions]
```

**Why it works:** Gives Claude a menu to select from rather than inventing from scratch. Each approach has a use condition, preventing misapplication.

---

### 7. Prescriptive Output Format (shown before the example)

The exact template — not described, shown. Blank fields to fill in, section headers, formatting rules. Shown in a code block so it reads as a literal template.

**Pattern:**
````
## Output format

When [doing the task], deliver this:

### [Section Title] for [Context]

**[Item 1 name]: [Label]**
- [Field 1]: [Description of what goes here]
- [Field 2]: [Description]
- [Field 3]: [Description]
- [Field 4]: [Description]

**[Item 2 name]: [Label]**
...

**Recommended starting point:** [Which option to lead with and why]
````

**Why it works:** Claude produces consistent, scannable output every time. User knows what to expect. Downstream skills can consume outputs predictably.

---

### 8. Worked Example (full realistic output)

A complete, realistic example — not a toy example. The example itself could be shipped as real output.

**Pattern:**
```
## Example: [Specific realistic scenario]

### Context
- [Fact about the scenario]
- [Fact about the scenario]
- [Fact about the scenario]
- [Fact about the scenario]

### [Output type] for [Subject]

**[Item 1]**
- [Field]: [Real filled-in content]
- [Field]: [Real filled-in content]
...

**Recommended starting point:** [Specific recommendation with reasoning]
```

**Why it works:** Shows Claude the quality bar. A vague example produces vague output. A high-quality example produces high-quality output.

---

### 9. Skill Wiring (upstream/downstream connections)

Explicitly states which other skills feed into this one and which skills consume its output.

**Pattern:**
```
## How this skill connects to others

**[This skill] + [Other skill]:**
"[Exact instruction Claude would use to chain them]"

**The workflow:**
1. Run [upstream skill] first ([what it produces])
2. Save the [output artifact]
3. Reference it in [this skill or downstream skill]
```

**Why it works:** Enables skill composition without reinventing orchestration logic each time. Claude understands its place in the pipeline.

---

### 10. The Test (4-5 verifiable criteria)

Quality gate before delivery. Not "check if it's good" — specific, binary tests.

**Pattern:**
```
## The test

Before delivering [output], verify each one:

1. **[Criterion name]:** [Specific question that has a yes/no answer]

2. **[Criterion name]:** [Specific question]

3. **[Criterion name]:** [Specific question]

4. **[Criterion name]:** [Specific question]

5. **[Criterion name]:** [Specific question]

If any answer is no, [what to do — sharpen/revise/ask again].
```

**Why it works:** Claude self-reviews before outputting. Catches "good enough" outputs that don't actually meet the standard.

---

### 11. Graceful Degradation Tiers

Every skill must declare how it handles three context levels. This is a required implementation pattern — not an optional enhancement.

**Pattern:**
```
## Context levels

This skill works at three levels:

### Tier 0 — No context
[What the skill does when shared memory / profile files are absent]
Note shown: "[Context source] not found — this skill works standalone. I'll ask what I need as we go."
Requirement: Tier 0 must produce genuinely useful output, not a stub.

### Tier 1 — Partial context
[What the skill does when some but not all files are present]
Note shown (ONE line): "Loaded [X]; [Y] and [Z] not yet created."
At end: suggest one high-impact next step to fill the most important gap.

### Tier 2 — Full context
[What the skill does with all declared context present]
Note shown: "Loaded [files] ([dates]). Using throughout."
Requirement: Use context visibly — confirm what was loaded and when.
```

**Rules:**
- Tier 0 must produce genuinely useful output, not a stub or a refusal
- Tier 1 consolidates missing context into ONE status line — never a list of missing files
- Tier 2 shows loaded context visibly and confirms currency
- No skill may error or block on missing upstream files
- Never guilt-frame missing context ("you're missing X") — opportunity-frame it ("X would enable Y")

**Why it works:** Skills that error on missing context break workflows. Skills that silently proceed without context produce unexplained quality degradation. Explicit tiers give users clarity and let the system grow with the user.

Reference: `graceful-degradation-tiers-framework.md`

---

## What's Always in `references/`

The main `Skill.md` stays focused and scannable. Deep domain knowledge goes in `references/`:

- Named frameworks with full detail (e.g., `dunford-positioning.md`, `schwartz-sophistication.md`)
- Format-specific examples by category (e.g., `format-examples.md`, `info-product-magnets.md`)
- Psychology / research foundations (e.g., `psychology.md`)
- Worked examples by industry (e.g., `eeat-examples.md`, `newsletter-examples.md`)

**Rule:** If reading it would slow down Claude on a quick task, it belongs in `references/`. The main file links to it and Claude loads it only when needed.

---

## What's Always Out of Scope (The "Is NOT" Section)

Every skill ends with what it explicitly doesn't do — stated as a list of adjacent tasks that belong to other skills.

**Pattern:**
```
## What this skill is NOT

This skill [does the core thing]. It does NOT:
- [Adjacent thing 1] (that's [other skill name])
- [Adjacent thing 2] (that's [other skill name])
- [Assumption it doesn't make]
- [Scope it explicitly rejects]

The output is [what it is], not [what it might be confused for].
```

**Why it works:** Prevents scope creep. Claude stops at the right boundary and hands off to the right next skill.

---

## Checklist: Does Your Skill Have All 11?

- [ ] Philosophical hook — reframes the problem, not an intro
- [ ] Core job + output format stated upfront
- [ ] Decision gate / mode split with selection criteria
- [ ] Context gathering steps before generation
- [ ] Named frameworks with conditions for application
- [ ] Generator library — named approaches with "works when" conditions
- [ ] Prescriptive output format shown as a template
- [ ] Full worked example at production quality
- [ ] Skill wiring — upstream and downstream connections stated
- [ ] The test — 4-5 verifiable quality criteria
- [ ] Graceful degradation — all 3 tiers handled explicitly (Tier 0: standalone, Tier 1: partial, Tier 2: full)

---

## The "Scope Sentence" Test

Before writing a skill, complete this sentence:

> "This skill does ONE thing: it produces **[specific artifact]** so that **[downstream use or user goal]**. It does NOT **[adjacent thing]**."

If you can't complete it in one sentence, the skill scope is unclear. Split it.

**Zero-context test:** Read Element 11 (Graceful Degradation Tiers). Can this skill produce genuinely useful output with no shared memory, no prior session, no profile files? If the answer is no without modification — add a Tier 0 path before shipping.
