<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/agents/agent-safety-and-guardrails.md and re-run profile-sync. -->
# Agent Safety and Guardrails Standards

## Overview

This document defines standards for security, safety, and human oversight in production agents.
Conforming to these standards prevents the two most critical production failures in agentic
systems: prompt injection attacks that redirect agent behavior, and irreversible actions executed
without human approval. Agents that pass sensitive data through unguarded tool outputs or take
destructive actions without confirmation are production liabilities regardless of functional
correctness.

## Scope

**Covers:** Prompt injection defense, harmlessness screening, reversibility-based human-in-the-loop
controls, guardrail placement and execution modes, and least-privilege tool design.

**Does NOT cover:** Evaluation quality and observability (see `agent-evaluation-and-observability.md`)
or agent loop termination conditions (see `agent-loop-design.md`).

## Principles

1. **Prompt injection is the primary threat.** External data is the attack surface. Any content
   ingested from the web, email, documents, or API responses can contain adversarial instructions.
   The agent's clean initial context is the only safe planning surface; everything that arrives
   via tool calls must be treated as potentially adversarial.

2. **Reversibility-based action permission.** The cost of requiring confirmation scales with
   reversibility. Local, reversible actions are free. Destructive or shared-system actions require
   explicit human confirmation. The question is not "is this action risky?" but "can this action
   be undone without external help?".

3. **Defense in layers.** No single guardrail is sufficient. Model training robustness, classifier
   scanning, and application-level guardrails each catch what the others miss. Each layer is
   necessary; none is individually sufficient.

4. **Least privilege by default.** Read tools must be separate from write tools. Agents start with
   read-only access and escalate to write access only when a specific action has been approved.
   Write tools must not be present in the initial tool context.

## Rules

### R1 — The Threat Landscape

Primary injection vectors in production:

- **Tool output injection**: webpages, emails, documents, and API responses can embed
  `"Ignore previous instructions and..."` text the agent treats as instruction.
- **Hidden white-text instructions**: invisible text in documents that appears in text extraction
  but not in visual reading — invisible to reviewers, visible to the agent.
- **Browser-based agents** have the largest attack surface: every URL visited is a potential
  injection vector.
- **Code execution agents**: injected instructions can exfiltrate environment variables or API
  keys by embedding calls in code the agent is asked to execute.
- **Multi-agent systems**: a compromised sub-agent can pass adversarial instructions upstream to
  the orchestrator. Trust must be explicitly established; never inherit it transitively.

### R2 — Anthropic's 3-Layer Defense Architecture

All three layers are required for production agents that ingest external data.

**Layer 1 — Model training**: Anthropic trains Claude on simulated injected content with RL
robustness. This layer is provided by the model — it does not substitute for application defenses.

**Layer 2 — Classifier scanning**: untrusted content is scanned before it reaches the agent's
decision context. Use a fast, cheap model (Claude Haiku 4.5 or GPT-4o-mini) as the classifier.

**Layer 3 — Application guardrails**: developer responsibility. Harmlessness screens on user
input, input validation at tool boundaries, value-aligned system prompts, chained safeguards, and
monitoring for behavioral drift. This is the only layer the developer fully controls.

### R3 — Plan-then-Execute as Prompt Injection Defense

Generate the full action plan before ingesting any external tool data. The plan is formed from the
clean initial context; later adversarial content cannot redirect it. If the plan must update from
new information: require a new explicit planning step — do not allow inline mutation from
externally-retrieved content.

```typescript
// OFF-STANDARD: planning while ingesting external data
const results = await webSearch(query);
const nextSteps = await agent.planFromResults(results); // adversarial web content in context
await agent.execute(nextSteps);

// ON-STANDARD: Plan-then-Execute
const plan = await agent.plan(userRequest); // no external data in context yet
for (const step of plan.steps) {
  const result = await executeStep(step); // external data enters here, plan already fixed
  await checkpointStep(step.id, result);
}
```

```python
# ON-STANDARD: Plan-then-Execute in Python
plan = agent.plan(user_request)  # no external data in context yet
for step in plan.steps:
    result = execute_step(step)  # external data enters here, plan already fixed
    checkpoint_step(step.id, result)
```

### R4 — Harmlessness Screen Pattern

Pre-screen user inputs with a fast, cheap model before the main agent. Required structured output:
`{ "is_harmful": boolean, "category": string, "reasoning": string }`. Run in parallel for
latency-sensitive read-only paths; run in blocking mode for any write, send, delete, or deploy
path — the agent must not begin until the screen clears.

```typescript
// ON-STANDARD: harmlessness pre-screen
const screen = await anthropic.messages.create({
  model: 'claude-haiku-4-5',
  system: 'You are a safety classifier. Respond with JSON only.',
  messages: [{ role: 'user', content: `Classify: ${userInput}\n\nRespond: {"is_harmful": bool, "category": str, "reasoning": str}` }],
  max_tokens: 256,
});
const result = JSON.parse(screen.content[0].text);
if (result.is_harmful) return { error: 'Request cannot be processed', category: result.category };
const agentResponse = await mainAgent.run(userInput);
```

```python
# ON-STANDARD: harmlessness pre-screen in Python
screen = anthropic.messages.create(
    model="claude-haiku-4-5",
    system="You are a safety classifier. Respond with JSON only.",
    messages=[{"role": "user", "content": f'Classify: {user_input}\n\nRespond: {{"is_harmful": bool, "category": str, "reasoning": str}}'}],
    max_tokens=256,
)
result = json.loads(screen.content[0].text)
if result["is_harmful"]:
    return {"error": "Request cannot be processed", "category": result["category"]}
agent_response = main_agent.run(user_input)
```

### R5 — The Reversibility-Based HITL Rule

Classify every action before the agent has write access.

**Free (no confirmation required):**
- All read-only operations; local, reversible changes; creating new files

**Confirmation required (explicit user approval before execution):**
- **Destructive**: `rm -rf`, `DROP TABLE`, `git reset --hard`, deleting records
- **Hard-to-reverse**: `git push --force`, amending published commits, overwriting files, sending emails
- **Visible to others / shared systems**: pushing code, commenting on PRs, modifying shared
  infrastructure, deploying to staging or production

The agent system prompt MUST include the reversibility guardrails block. The agent MUST stop and
surface the proposed action with a human-readable summary before executing anything in the
confirmation-required category.

```typescript
// ON-STANDARD: reversibility gate before write execution
const CONFIRMATION_REQUIRED = ['rm', 'git push', 'git reset --hard', 'DROP TABLE', 'send', 'deploy'];

function requiresConfirmation(action: AgentAction): boolean {
  return CONFIRMATION_REQUIRED.some(op => action.command.startsWith(op))
    || action.affectsSharedSystem || action.isDestructive;
}

if (requiresConfirmation(proposedAction)) {
  const approved = await hitl.requestApproval({ action: proposedAction, reversible: false });
  if (!approved) return { status: 'cancelled', reason: 'user rejected action' };
}
await execute(proposedAction);
```

### R6 — Guardrail Placement: Input, Output, Tool

**Input guardrails** — before or in parallel with the first agent turn:

```python
from agents import Agent, InputGuardrail, GuardrailFunctionOutput

async def check_harmful_content(ctx, agent, input):
    result = await classify_input(input)
    return GuardrailFunctionOutput(output_info=result, tripwire_triggered=result.is_harmful)

agent = Agent(
    name="main-agent",
    instructions="...",
    input_guardrails=[InputGuardrail(guardrail_function=check_harmful_content)],
)
# Tripwire fires → InputGuardrailTripwireTriggered raised automatically.
```

**Output guardrails** — after final output, before delivery: check for PII leakage, toxic content,
policy violations. Raises `OutputGuardrailTripwireTriggered`.

**Tool guardrails** — wrap individual tool invocations: block writes to sensitive paths, validate
SQL before execution, confirm before side-effecting external API calls.

### R7 — Guardrail Execution Modes

```typescript
// OFF-STANDARD: parallel guardrail on a write operation
const [guardrailResult, agentTurn] = await Promise.all([
  runInputGuardrail(userInput),
  mainAgent.beginTurn(userInput), // agent starts before guardrail completes
]);

// ON-STANDARD: blocking mode for write operations
const guardrailResult = await runInputGuardrail(userInput);
if (guardrailResult.tripwire_triggered) return { error: 'Input rejected' };
const agentResponse = await mainAgent.run(userInput); // starts only after clearance
```

**Parallel mode**: acceptable for read-only operations with low information-disclosure risk.
**Blocking mode**: REQUIRED for any operation with write, send, delete, or deploy capabilities.

### R8 — Least-Privilege Tool Design

```typescript
// OFF-STANDARD: write tools available from the start
const agent = new Agent({ tools: [readFile, writeFile, deleteFile, sendEmail, deployToProduction] });

// ON-STANDARD: read-only initial context; write tools added after approval
const agent = new Agent({ tools: [readFile, listDirectory, searchCode] });
const approved = await hitl.requestApproval(proposedWrite);
if (approved.granted) {
  agent.addTool(writeFile);
  await agent.executeApprovedAction(approved);
  agent.removeTool(writeFile);
}
```

Apply `needs_approval=True` to all write-operation agents-as-tools in the OpenAI Agents SDK.

### R9 — Production Safety Checklist

- **Sandbox adversarial testing**: run against synthetic prompt injection and boundary-case inputs
  before production exposure
- **Automated output gates in CI**: LLM-as-judge screening for policy violations; block deployment
  if violation rate exceeds threshold
- **Staged rollouts**: 1% → 10% → 50% → 100%; monitor anomaly signals at each gate before advancing
- **Anomaly rollback triggers**: auto-rollback if hallucination rate exceeds threshold OR tool
  failure rate exceeds threshold OR cost spikes more than 2x baseline

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Agent ingesting external web/email/document data with no injection defense | Any webpage or document processed can redirect agent goals or exfiltrate credentials | Plan-then-Execute: form the full plan before ingesting external data; classifier-scan all external content |
| Parallel guardrails on write operations | Agent can begin executing a destructive action before the guardrail completes; if the tripwire fires the action is already in flight | Blocking mode required for all write, delete, send, and deploy operations |
| No reversibility classification — all actions treated equally | Agents that confirm every action train users to approve blindly; agents that never confirm cause irreversible damage | Classify actions: free (local, reversible) vs. confirmation-required (destructive, hard-to-reverse, visible to others) |
| No `max_turns` cap on production agents | Adversarial injection can create infinite delegation chains; cost grows without limit | Set `max_turns` on every agent invocation; surface a progress summary to the user when cap is reached |
| Single-layer guardrails with no classifier scanning | Application-level guardrails miss semantic injection patterns; a single layer fails when bypassed | Defense in depth: classifier scanning + application-level guardrails + model training robustness |

## Deviation Guidance

MAY skip the harmlessness pre-screen for internal agents where all users are authenticated
employees and the input surface is tightly controlled (structured form inputs, not free text).
MUST implement pre-screening for any agent that accepts free-text input from unauthenticated or
externally-sourced users.

MAY use parallel guardrail execution for read-only agents where information-disclosure risk is low
and no write tools are present. MUST use blocking mode for any agent with write, send, delete, or
deploy capabilities — the mode is set by the presence of the capability, not the intent of the
current request.

## Compliance Test

Answer each question with Y or N before shipping a production agent:

1. For any agent that ingests external data (web, email, documents): is Plan-then-Execute or
   classifier scanning in place as a prompt injection defense? (Y/N)
2. Are write, delete, send, and deploy operations protected by blocking-mode guardrails — not
   parallel-mode — ensuring the guardrail clears before the agent begins? (Y/N)
3. Is `max_turns` set on every agent invocation with no exceptions? (Y/N)
4. Are agent actions classified into free vs. confirmation-required categories, and does the
   system prompt include the reversibility guardrails block? (Y/N)
5. Are read tools separated from write tools — write tools absent from the agent's initial tool
   context, added only after an explicit approval gate is cleared? (Y/N)

All five must be Y. Any N is a blocker before the agent reaches production.

## References

- Anthropic, "Building Effective Agents" (2024) — prompt injection defense, reversibility-based HITL
- OpenAI Agents SDK, guardrails documentation — InputGuardrail, OutputGuardrailTripwireTriggered,
  needs_approval
- Anthropic CLAUDE.md pattern — reversibility-based action classification (source of R5)
- OWASP Top 10 for LLM Applications — prompt injection (LLM01), insecure output handling (LLM02)
