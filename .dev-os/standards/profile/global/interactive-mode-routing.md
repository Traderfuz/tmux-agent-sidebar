<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/interactive-mode-routing.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/interactive-mode-routing.md and re-run profile-sync. -->
# Interactive Mode Routing Standard

**Status:** Active
**Applies to:** All DevOS skills and runtime surfaces that dispatch specialist agents.
**Authority:** profile/global

## Why This Standard Exists

Dispatch policy must work from every supported host without making portable skills
choose a provider, model, or host-specific role. Provider names in shared routing
instructions couple a skill to one adapter and make the same instruction behave
differently across OMP, Claude Code, Pi, Codex, OpenCode, and Hermes.

This standard separates three decisions: classify work with a portable tier, select
an available runtime through the shared policy, then let that runtime adapter choose
its provider-specific model or role.

## Normative Vocabulary

Portable routing code MUST use only `simple|standard|complex` or an empty tier:

| Tier | Intended work |
|---|---|
| `simple` | Mechanical reads, searches, formatting, and bounded edits |
| `standard` | Normal implementation and analysis |
| `complex` | Architecture, review, security, synthesis, and high-judgment work |
| empty | No routing override; the selected adapter keeps its configured default |

A portable tier describes task complexity. It is not a provider model, runtime ID,
or billing class.

## Normative Dispatch Rule

Every skill that delegates specialist-agent work MUST:

1. Classify the task with `interactive_get_model_for_task`, which returns a portable
   tier despite its compatibility-preserved function name.
2. Select the execution mechanism through `agent_runtime_select`; skills MUST NOT
   implement a second host detector, probe loop, or runtime default.
3. Pass the tier as the optional fourth argument to
   `agent_runtime_dispatch <runtime> <agent> <task-file> [tier]`. The existing
   three-argument form remains valid when no tier is classified.
4. Leave provider model and role translation to the selected adapter.

## Runtime Selection Precedence

`agent_runtime_select` is the only normative runtime-selection API. It evaluates,
in order:

1. operator toggle forcing inline execution;
2. explicit call-site runtime override;
3. explicit runtime phrase in the task;
4. runtime environment override;
5. agent model route, then role-specific or default runtime policy;
6. configured probe precedence;
7. configured concrete fallback, or terminal inline fallback.

Concrete configuration retains precedence. A policy value of `auto` is consumed
before runtime validation: it asks `agent_runtime_host_default` for the active host
candidate. That helper reuses `model_route_detect_client`; no skill may read a
second host-variable cascade.

The host mapping is an internal runtime mapping, not skill vocabulary. A failed host
candidate is recorded once and excluded from the remaining probe scan for that
selection. Exclusion state resets before the next independent selection.

## Provenance and Fallback

Selection output MUST preserve why the runtime won:

- `source=host-default` means an unset or `auto` policy mapped the detected host to
  an available runtime.
- `source=probe-precedence` means configured probing selected the first remaining
  available adapter.
- `source=inline-fallback` means probes were exhausted and fallback was unset or
  `auto`.

`inline` is a terminal resolver outcome. It is not a configured or probeable adapter.
An unrecognized host produces no host candidate; selection continues through probes
and then returns the terminal inline outcome when no adapter is available. Runtime
selection failure remains typed failure and MUST NOT be replaced by a hidden
provider-specific default.

## Complexity Classification

Eco mode starts at score 50, subtracts 15 for each simple keyword, adds 10 for each
complex keyword, clamps the score to 0–100, and maps ≤20 to `simple`, 21–70 to
`standard`, and >70 to `complex`.

Advisor mode maps review, architecture, analysis, audit, design, evaluation, and
critique to `complex`; mechanical read, list, check, find, search, and count work to
`simple`; and other work to `standard`. Complex intent wins when both classes match.

Modes without a routing override return an empty tier.

## Telemetry

New `interactive_dispatch` events MUST write `tier` and MUST NOT write a provider
alias under `model`. Metrics and OTEL readers MAY normalize historical `model`
events so append-only logs remain readable. Unknown or absent historical values
remain unclassified. Runtime decisions expose the selection source, including
`host-default` and `inline-fallback`.

## Authoring Checklist

- [ ] Shared instructions use only `simple|standard|complex` or empty.
- [ ] Runtime selection calls `agent_runtime_select`.
- [ ] Tier-aware dispatch uses the optional fourth dispatcher argument.
- [ ] Provider translation occurs only inside the selected adapter.
- [ ] No second host detector, probe loop, or implicit runtime default exists.
- [ ] Host-default, probe, and inline-fallback outcomes remain observable.

## Validation

- SK33 warns on unlabelled provider-alias routing in `SKILL.md` and local
  `references/`; strict validation blocks it.
- `tests/bats/lib/interactive-mode-router.bats` verifies portable classification.
- `tests/bats/lib/agent-runtime-dispatch.bats` and
  `tests/bats/lib/agent-runtime-hardening.bats` verify selection, translation
  boundaries, and fallback provenance.

## claude-agent Adapter Appendix

This appendix is provider-specific and applies only after `runtime=claude-agent`
wins. The adapter helper `interactive_claude_alias_for_tier` translates `simple` to
`haiku`, `standard` to `sonnet`, and `complex` to `opus`. Empty remains empty.
Invalid tiers fail translation. No portable skill or non-Claude adapter may perform
this mapping.

## References

- Runtime selector: `scripts/lib/agent-runtime-dispatch.sh`
- Runtime policy: `scripts/lib/agent-runtime/route.sh`
- Resolver chain: `scripts/lib/agent-runtime/resolve.sh`
- Tier classifier: `scripts/lib/interactive-mode-router.sh`
- Host detector: `scripts/lib/model-routing.sh`
- Related standard: `.dev-os/standards/profile/global/runtime-standards.md`
