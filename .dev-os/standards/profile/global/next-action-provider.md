<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/next-action-provider.md and re-run profile-sync. -->
# Next-Action Provider Contract

Candidate-capable routing skills MUST expose a read-only `--json` card with `schema: "next-action-candidates/1"`. Provider JSON MUST NOT refresh maps, mutate caches, invoke `optimize`, call a network API, or execute the returned action.

## Card

```json
{
  "schema": "next-action-candidates/1",
  "provider": {
    "entry_skill": "bos-start-here",
    "full_list_invoke": "bos-portfolio-health"
  },
  "candidates": []
}
```

`provider.entry_skill` and `provider.full_list_invoke` are required non-empty strings. `candidates` contains at most ten entries.

Each candidate requires `id`, `os`, `action`, `invoke`, `class`, `impact`, `evidence_path`, and `evidence`. `os` is one of `bos`, `mos`, `cos`, `dos`, `ros`, `los`, `dev`. `class` is one of `opportunity`, `blocker`, `deadline`, `hygiene`. `impact` is an integer 1–5. `evidence_path` must exist; configured absolute authority roots require an absolute evidence path. `urgency_days` is optional numeric and higher means more urgent.

## Goals

An optional `goals` block uses `schema: "next-action-goals/1"`, a `binding_goal_id`, and a `goals` array of objects with an `id`, `statement`, `horizon`, and integer `weight` 1–5. An invalid goals block is advisory: the base card remains usable and the aggregator drops only goals context.

## Validation

All provider tests resolve the single validator in this order: `NAC_VALIDATOR_LIB`, `${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/next-action-contract.sh`, then the DevOS source path only during source-repo development. Providers MUST NOT vendor a private validator.

`nac_validate_card <json-file>` exits nonzero for card/candidate violations and writes one `ERROR <field-path>:` line per violation. It exits zero for a valid base card even when it emits `WARN goals:` for a malformed optional goals block.
