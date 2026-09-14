<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/agents/agent-evaluation-and-observability.md and re-run profile-sync. -->
# Agent Evaluation and Observability Standards

## Overview

This document defines standards for evaluating agent quality and observing agent behavior in
production. Evaluation without observability tells you that something went wrong but not where or
why. Observability without evaluation tells you the agent is running but not whether it is running
correctly. Both are required. Agents deployed without the baseline described here are operating
blind: failures accumulate silently until a user reports them.

## Scope

**Covers:** Distributed tracing setup, the 3-level evaluation framework (response / trajectory /
step), LLM-as-Judge configuration, test dataset structure, production observability requirements,
and third-party observability integrations.

**Does NOT cover:** Prompt injection defense, harmlessness screening, or guardrail placement (see
`agent-safety-and-guardrails.md`). Memory architecture and context window management (see
`memory-and-context.md`).

## Principles

1. **Tracing from day one.** Set up distributed tracing before writing business logic.
   Retrofitting observability into a production multi-agent system requires changing call sites,
   adding correlation IDs, and coordinating rollout across all agents simultaneously. The cost of
   adding it at creation is 10x lower than the cost of adding it after launch.

2. **3-level evaluation.** Evaluate at all three levels: final response, trajectory, and single
   step. A single eval level tells you WHAT went wrong but not WHERE or WHY. Level 1 detects the
   symptom; Level 2 locates the path deviation; Level 3 identifies the root cause of each
   individual decision.

3. **Independent judge model.** Never use the same model to both generate and evaluate its own
   outputs. Self-evaluation bias produces misleadingly high scores — models systematically rate
   their own outputs higher than independent judges. Use a different model family as judge and
   calibrate against human annotations before trusting scores in CI.

4. **Continuous evaluation, not gates.** Pre-deployment evaluation is insufficient for
   probabilistic systems. Agent behavior changes as context accumulates, tools evolve, and user
   patterns shift. Production monitoring is not optional — it is the only mechanism that catches
   post-deployment drift.

## Rules

### R1 — The Observability Baseline

Set up tracing before writing business logic — not as an afterthought. Pre-deployment-only
evaluation is insufficient: agent behavior shifts over time as tool APIs change, model weights
update, and user request distributions evolve.

The minimum observability baseline for any production agent is three things, all present from
day one:

- **Distributed tracing** — every LLM call and tool invocation traced end-to-end with a shared
  trace ID across agents and subagents
- **Token accounting** — input tokens, output tokens, and estimated cost logged per call and
  aggregated per session
- **Automated evals in CI** — trajectory and response evaluations running on every PR; not only
  pre-deployment smoke tests

Deploying without all three is an explicit decision to operate blind. It must be flagged as
technical debt at the time of the decision, not discovered later.

---

### R2 — The 3-Level Evaluation Framework

Evaluate at all three levels on every non-trivial agent. Each level answers a different question.

**Level 1 — Final Response evaluation** (integration-test analogy):
- Question: Did the agent produce the right answer or outcome?
- Method: LLM-as-judge comparing output against a reference answer or rubric; exact match for
  structured outputs.
- When it fails, you know WHAT went wrong but not WHERE.

**Level 2 — Trajectory evaluation** (system-test analogy):
- Question: Did the agent take the right path?
- Method: compare the agent's actual tool call sequence against the expected sequence using the
  `agentevals` package.
- Three match modes:
  - `strict` — exact message sequence match. Use for regression tests.
  - `subset` — agent called at least the required tools. Use for required-tool testing.
  - `superset` — agent called only the required tools (no forbidden ones). Use for
    forbidden-tool testing.
- When it fails, you know WHERE in the path the agent deviated.

**Level 3 — Single Step evaluation** (unit-test analogy):
- Question: Did each individual decision make sense?
- Method: step-level LLM judge or deterministic assertion on individual tool calls and their
  parameters.
- When it fails, you know WHY a specific decision was wrong.

Using all three: Level 1 tells you WHAT, Level 2 tells you WHERE, Level 3 tells you WHY.

```python
# OFF-STANDARD: Only evaluating the final response
score = judge.evaluate(final_answer, reference_answer)
# Tells you WHAT went wrong — cannot tell you WHERE or WHY

# ON-STANDARD: Trajectory evaluation with agentevals (Level 2)
from agentevals import create_trajectory_match_evaluator

evaluator = create_trajectory_match_evaluator(match_mode="subset")

result = await evaluator({
    "inputs": {"query": "What is the current stock price of AAPL?"},
    "outputs": actual_agent_trajectory,
    "reference_outputs": {
        "trajectory": [
            {
                "role": "assistant",
                "tool_calls": [
                    {"name": "get_stock_price", "args": {"ticker": "AAPL"}}
                ],
            },
        ]
    },
})
# result.score: 1.0 if agent called get_stock_price with correct args; 0.0 otherwise
```

```typescript
// ON-STANDARD: Single-step evaluation (Level 3) in TypeScript
import { createStepEvaluator } from "agentevals";

const stepEvaluator = createStepEvaluator({
  rubric: "Did the tool call use the correct parameters for the given user intent?",
  scoringModel: "gpt-4.1",  // different model from agent
});

for (const step of agentTrajectory.steps) {
  const stepScore = await stepEvaluator.evaluate({
    step,
    userIntent: testCase.user_input,
  });
  expect(stepScore.score).toBeGreaterThanOrEqual(4); // rubric: 1-5 scale
}
```

---

### R3 — LLM-as-Judge Best Practices

- Use a **different model** from the agent to reduce self-evaluation bias. If the agent is
  Claude Sonnet 4.6, judge with GPT-4.1 (or vice versa). Never use the same model as both
  generator and judge.
- One judge prompt per evaluation level. A single multi-purpose judge conflates the three
  levels and produces uninterpretable scores.
- Include an explicit scoring rubric with score anchors in every judge prompt:
  - 1 = fails to address the requirement
  - 3 = partially meets the requirement with notable gaps
  - 5 = fully meets the requirement with no gaps
- Calibrate against human annotations before deploying a judge as a CI gate. Target correlation
  > 0.8 between judge scores and human scores across your test dataset before trusting the judge
  to block merges.
- **Agent-as-Judge (2025 pattern):** Use an autonomous agent as judge for full trajectory
  evaluation including intermediate tool calls — the judge agent can call the same tools the
  tested agent used and verify correctness end-to-end.

```python
# ON-STANDARD: LLM-as-judge with explicit rubric and a different model
from anthropic import Anthropic

JUDGE_PROMPT = """You are evaluating an AI agent's response. Score it 1-5:
1 = fails to address the requirement
3 = partially meets the requirement with notable gaps
5 = fully meets the requirement with no gaps

User request: {user_input}
Agent response: {agent_response}
Expected key facts: {expected_facts}

Respond with JSON: {{"score": int, "reasoning": str}}"""

# Agent uses Claude Sonnet 4.6 — judge uses a different provider
import openai

judge_client = openai.AsyncOpenAI()  # different model family

async def evaluate_response(test_case, agent_response):
    completion = await judge_client.chat.completions.create(
        model="gpt-4.1",            # different model from agent
        messages=[{
            "role": "user",
            "content": JUDGE_PROMPT.format(
                user_input=test_case["user_input"],
                agent_response=agent_response,
                expected_facts=test_case["expected_key_facts"],
            ),
        }],
        response_format={"type": "json_object"},
    )
    return json.loads(completion.choices[0].message.content)
```

---

### R4 — Test Dataset Minimum Structure

Each test case MUST contain all five fields. Omitting any field makes the test case valid only
for Level 1 evaluation — trajectory and step tests are impossible without the tool sequence
fields.

Required fields:

- `user_input` — the exact user message or task
- `expected_key_facts` — 2–5 facts that MUST appear in the final response (Level 1)
- `expected_tool_sequence` — ordered list of tools the agent should call (Level 2)
- `expected_critical_parameters` — key parameter values for critical tool calls (Level 2)
- `forbidden_tool_calls` — tools the agent MUST NOT call (Level 2 superset check)

```typescript
// OFF-STANDARD: Incomplete test case — only Level 1 is testable
const testCase = {
  user_input: "Schedule a meeting with Alice for next Tuesday at 2pm",
  expected_output: "Meeting scheduled",  // no trajectory fields — cannot test path
};

// ON-STANDARD: Complete test case structure
const testCase = {
  user_input: "Schedule a meeting with Alice for next Tuesday at 2pm",
  expected_key_facts: ["Alice", "Tuesday", "2:00 PM", "calendar invite sent"],
  expected_tool_sequence: [
    "calendar_check_availability",
    "calendar_create_event",
    "email_send_invite",
  ],
  expected_critical_parameters: {
    calendar_create_event: {
      attendees: ["alice@example.com"],
      time: "14:00",
    },
  },
  forbidden_tool_calls: ["delete_event", "send_bulk_email"],
};
```

Test datasets MUST include multi-tool, multi-step cases. Top models drop 20–30% on complex
multi-tool orchestration vs. simple single-tool tasks (benchmark finding, 2025). Test suites
composed only of single-step cases miss the primary production failure mode entirely.

---

### R5 — Production Observability Requirements

All six requirements are MUST for any production agent. Satisfying five of six is not
compliant.

1. **Distributed tracing** — every tool call, LLM invocation, and decision point traced
   end-to-end with a shared trace ID across all agents and subagents in the system.

2. **Token accounting** — input tokens, output tokens, and estimated cost logged per call;
   aggregate cost tracked per session and surfaced in dashboards.

3. **Prompt-completion linkage** — each completion is linked to the exact prompt version that
   generated it. Required for debugging regressions caused by prompt changes and for audit
   trails.

4. **Automated evaluations in CI** — trajectory and response evals run on every PR. Not only
   as pre-deployment smoke tests. The CI gate must block merges that cause evaluation score
   regressions.

5. **Human feedback loops** — an annotation mechanism that feeds directly into evaluation
   datasets. Production mistakes improve future test coverage. Without this, the test dataset
   drifts away from actual user behavior over time.

6. **Anomaly alerting** — automated alerts on hallucination rate spikes, tool failure rate
   spikes, cost spikes (>2x rolling baseline), and latency spikes (p99 exceeding configured
   threshold).

---

### R6 — OpenAI Agents SDK Tracing Structure

When using the OpenAI Agents SDK, follow the `Trace` → `Span` hierarchy:

- One `Trace` per user-facing request.
- `group_id` links traces across a multi-turn conversation (spans multiple `Trace` objects for
  the same session).
- `metadata` enrichment is required: include `user_id`, `session_id`, `environment`
  (dev/staging/prod), and `agent_version` on every trace.
- ZDR policy: set `trace_include_sensitive_data=False` for any trace that may contain PII.

```python
# OFF-STANDARD: Tracing without metadata enrichment
with trace("customer-support-agent"):
    result = await runner.run(agent, user_message)
# No group_id: traces for this session are unlinked
# No metadata: impossible to filter by user, environment, or version

# ON-STANDARD: OpenAI tracing with metadata enrichment
from agents import trace
import os

with trace(
    "customer-support-agent",
    group_id=session_id,           # links all traces in this conversation
    metadata={
        "user_id": user.id,
        "session_id": session_id,
        "environment": os.environ["APP_ENV"],
        "agent_version": "1.2.0",
    },
    trace_include_sensitive_data=False,  # ZDR: no PII in trace payloads
):
    result = await runner.run(agent, user_message)
```

---

### R7 — Third-Party Observability Integrations

Choose one primary observability platform before going to production. Switching platforms after
production launch requires migrating trace history and recalibrating dashboards.

| Platform | Primary strength | Best fit for |
|---|---|---|
| **Langfuse** | Open-source; strong eval + prompt management | Teams that need self-hosted data residency |
| **Weights & Biases Weave** | Cost tracking; integrates with existing W&B workflows | ML teams with existing W&B investment |
| **Arize Phoenix** | LLM-specific drift detection; hallucination monitoring | Teams prioritizing post-deployment drift |
| **LangSmith** | Tightest LangChain/LangGraph integration; trajectory eval native | LangGraph-based agent architectures |

**OpenTelemetry note (2025):** OTel is the emerging standard for GenAI distributed tracing.
New instrumentation SHOULD target OTel semantic conventions for portability. Platforms listed
above all support OTel ingestion; using OTel conventions avoids lock-in to any one platform.

---

### R8 — Benchmark Calibration

Calibrate eval pass thresholds against benchmark findings, not intuition.

Key findings for 2025 production agents:

- Top models drop **20–30% on complex multi-tool orchestration** vs. simple single-tool tasks.
  Long-horizon dependency chains remain the primary frontier failure mode.
- **AGENTREWARDBENCH** (COLM 2025): benchmark for reward model alignment in agent tasks.
  Use it to verify that your LLM judge's reward signal aligns with human judgment on agentic
  trajectories before deploying the judge as a CI gate.
- **Agent-as-a-Judge** (arXiv:2508.02994): autonomous agent judges outperform static LLM judges
  on full trajectory evaluation because they can execute the same tools and verify intermediate
  results independently.

Implication: your eval suite MUST include multi-tool, multi-step test cases. Single-step tests
alone do not surface the primary failure mode.

## Anti-Patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Single pre-deployment smoke test as the entire eval strategy | Agent behavior changes over time as tools evolve, context accumulates, and user patterns shift; a pre-deployment gate catches nothing post-deployment | 3-level eval in CI (response + trajectory + step) plus production anomaly monitoring |
| LLM judges its own outputs — same model as agent and judge | Self-evaluation bias: models systematically rate their own outputs higher than independent judges; scores are misleadingly optimistic | Use a different model family as judge (e.g., agent=Claude Sonnet 4.6, judge=GPT-4.1) and calibrate against human annotations |
| Evaluating only final response and ignoring trajectory | Final response eval tells you WHAT went wrong but not WHERE or WHY; a correct final answer via a wrong path is a fragile agent that will fail differently on slight input variations | Add trajectory evaluation (Level 2) to identify path deviations; add step-level evals (Level 3) to pinpoint root causes |
| Adding tracing after the agent is in production | Retrofitting distributed tracing into an existing multi-agent system requires changing call sites, adding correlation IDs, and coordinating rollout across all agents simultaneously | Set up tracing on day one before writing business logic; the cost of adding it early is 10x lower than retrofitting it |
| Test datasets with only single-tool, single-step cases | Top models drop 20–30% on multi-tool orchestration vs. simple tasks; single-step test suites miss the primary production failure mode entirely | Include multi-tool, multi-step test cases; specifically test long-horizon dependency chains and parallel tool orchestration |

## Deviation Guidance

**Trajectory evaluation (R2, Level 2):** MAY skip trajectory evaluation for single-tool agents
where the only valid execution path is always the same single tool call. MUST use trajectory
evaluation for any agent that can take more than one valid path to the correct answer or that
uses more than two tools.

**Third-party observability (R7):** MAY defer third-party platform integration (Langfuse,
LangSmith, etc.) during prototyping in favor of local structured logging. MUST upgrade to a
system that supports trace correlation and cost accounting before exposing the agent to
production traffic.

**LLM-as-Judge calibration (R3):** MAY skip human annotation calibration for low-stakes
internal tools. MUST calibrate (correlation > 0.8 against human scores) before deploying a
judge as a gate that blocks production deploys or CI merges.

## Compliance Test

Answer YES or NO for each item. A single NO is a gap that must be tracked as technical debt
before production deployment.

1. Is evaluation implemented at all three levels: final response (what), trajectory (where), and single step (why)? (Y/N)
2. Is the judge model a different model from the agent — not the same model evaluating its own output? (Y/N)
3. Are trajectory evaluations included in CI and run on every PR — not only as pre-deployment gates? (Y/N)
4. Is distributed tracing in place with a shared trace ID across all agents and subagents in the system? (Y/N)
5. Do test datasets include multi-tool, multi-step cases — not only single-step tests? (Y/N)

## References

- LangChain/LangSmith trajectory evaluation documentation — 3-level evaluation framework,
  `agentevals` package, `create_trajectory_match_evaluator`, match modes (`strict`, `subset`,
  `superset`)
- Gu et al. (2025), "AGENTREWARDBENCH: Evaluating Reward Models for Language Agent Feedback"
  (COLM 2025) — benchmark for reward model alignment in agentic tasks
- Zhou et al. (2023), "Agent-as-a-Judge: Evaluate Agents with Agents" — arXiv:2508.02994 —
  autonomous agent trajectory evaluation using agent judges
- OpenAI Agents SDK tracing documentation — `Trace`/`Span` hierarchy, `group_id` for
  multi-turn sessions, `metadata` enrichment, ZDR policy
- OpenTelemetry GenAI semantic conventions — emerging standard for LLM distributed tracing;
  portability across observability platforms
