<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/chain-skill-mirror-contract.md and re-run profile-sync. -->
# Chain-Skill Mirror Contract Standard

## Overview

Some DevOS chains have matching-name skills: the chain is the executable orchestration, while the skill is the operator-facing contract. This standard prevents those two artifacts from drifting apart by requiring reciprocal metadata, a shared sequence block, and a validation scan whenever either side changes.

## Scope

This standard covers DevOS chain artifacts that intentionally have an operator-facing matching skill. It does NOT cover unrelated same-name files, agent-to-skill mirrors, command wrappers, or content-OS prefixed skills.

## Principles

1. **Source-to-derivative clarity:** Chain YAML owns executable order; SKILL.md owns operator semantics and failure handling.
2. **Bidirectional discoverability:** Both artifacts declare the relationship so readers and validators can find the counterpart without guessing from filenames.
3. **Single-commit parity:** A behavior change to one side lands with the corresponding change to the other side.
4. **Machine-checkable contract:** The contract uses metadata and explicit sequence text so drift can be caught by a script, not memory.

## Rules

### R1 — Declare mirror metadata

- A chain with an intentional skill mirror MUST include `mirror_skill: <skill-id>` in its YAML.
- The mirrored skill MUST include `mirrors_chain: <chain-id>` in frontmatter.
- The chain id and skill id SHOULD match unless there is an explicit migration or deprecation reason.

```yaml
# ON-STANDARD: chain metadata
schema_version: 1
id: pr-lifecycle
mirror_skill: pr-lifecycle
```

```yaml
# ON-STANDARD: skill frontmatter
---
name: pr-lifecycle
mirrors_chain: pr-lifecycle
---
```

### R2 — Keep executable order in the chain

The chain YAML is the source of truth for the executable sequence. A mirror skill MUST NOT invent a different order or omit safety gates that the chain runs.

### R3 — Keep operator semantics in the skill

The mirror skill MUST explain when to use the workflow, decision modes, context gathering, failure handling, and the test. Chain YAML stays concise and machine-readable.

### R4 — Include a Chain Mirror Contract section

Every mirror skill MUST include a `## Chain Mirror Contract` section that states:

- the chain id it mirrors,
- the reciprocal metadata fields,
- the rule that chain and skill sequence changes land together,
- the validator to run after edits.

### R5 — Validate after edits

After editing any chain or skill that participates in a mirror pair, run the chain-skill mirror contract scan. Strict failures block completion for declared mirrors; legacy matching-name mirrors without metadata are warnings until migrated.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Matching filenames only | Filename convention is invisible to tools and easy to break | Declare `mirror_skill` and `mirrors_chain` |
| Skill repeats a stale sequence from memory | Operators follow outdated gates | Copy/update the chain sequence when YAML changes |
| Chain adds a safety gate without skill docs | Operator-facing instructions understate behavior | Update skill phase list and test in same commit |
| Skill adds a mode not reflected by chain behavior | Chain execution surprises users | Add chain step/args or state that the mode is advisory-only |
| Treating legacy mirrors as forever exempt | Drift accumulates silently | Warnings are migration debt; new mirrors are strict |

## Deviation guidance

You MAY omit mirror metadata when a chain only happens to share a name with a skill and is not meant to be a mirror. When you do, add an inline comment or documentation note explaining that the relationship is accidental. You MAY maintain a legacy mirror without metadata during migration, but new or edited mirrors MUST adopt this contract.

## Compliance test

- [ ] Does every intentional mirror chain declare `mirror_skill: <skill-id>`?
- [ ] Does every intentional mirror skill declare `mirrors_chain: <chain-id>`?
- [ ] Does every mirror skill include a `## Chain Mirror Contract` section?
- [ ] Does the mirror skill mention every chain step name and argument from the YAML sequence?
- [ ] Did the chain-skill mirror contract scan run after the latest edit?
- [ ] Did chain registry regeneration run after any YAML change?

If any check fails for a declared mirror: fix the metadata, sequence, or skill text before completing the change.

## References

- RFC 2119 normative vocabulary — MUST/SHOULD/MAY compliance language.
- DevOS Source-to-Derivative Contract — source YAML plus regenerated registries.
- DRY/DAMP Standards Balance — define the relationship once with metadata, but keep the human-facing sequence readable.
